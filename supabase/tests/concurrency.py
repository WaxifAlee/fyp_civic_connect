#!/usr/bin/env python3
"""Local-only concurrency regressions; disposable DB required, no cloud access.

Uses an existing Unix-socket PostgreSQL with all migrations applied. Fixtures
commit to exercise snapshots across transactions; finally removes synthetic rows.
The caller must discard the disposable database after use.
"""
import argparse
import json
from pathlib import Path
import select
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--socket', required=True)
parser.add_argument('--port', default='55439')
parser.add_argument('--database', required=True)
args = parser.parse_args()
if not Path(args.socket).is_absolute() or not Path(args.socket).is_dir():
    parser.error('--socket must be an existing absolute local Unix-socket directory')
cmd = ['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-h', args.socket,
       '-p', args.port, '-d', args.database]
uid = 'a2000000-0000-4000-8000-000000000001'
image = f'{uid}/c2000000-0000-4000-8000-000000000001.jpg'
avatar = f'{uid}/c2000000-0000-4000-8000-000000000002.png'
request = 'b2000000-0000-4000-8000-000000000001'
claims = json.dumps({'sub': uid, 'role': 'authenticated'})
auth = f"SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claims','{claims}',true);"
create = ("SELECT public.create_report('Concurrent report','A long description for concurrent database tests.',"
          f"'Police Department',33.55,72.63,ARRAY['{image}'],'{request}');")
processes = []


def query(sql, allowed_failure=False):
    result = subprocess.run(cmd, input=sql, text=True, capture_output=True, timeout=20)
    if result.returncode and not allowed_failure:
        raise AssertionError(result.stderr)
    return result


def start(sql):
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True, bufsize=1)
    processes.append(proc)
    proc.stdin.write(sql+'\n')
    proc.stdin.flush()
    return proc


def until(proc, marker):
    # Use binary reads to avoid TextIO buffering swallowing a ready marker.
    import os
    deadline = time.monotonic()+10
    data = b''
    while time.monotonic()<deadline:
        if marker.encode() in data:
            return data.decode()
        if select.select([proc.stdout], [], [], 0.1)[0]:
            part = os.read(proc.stdout.fileno(), 8192)
            if not part:
                break
            data += part
    raise AssertionError(f'No marker {marker}: {data!r}')


def waiting(name):
    deadline = time.monotonic()+10
    while time.monotonic()<deadline:
        sql = f"SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='{name}' AND wait_event_type='Lock');"
        if query(sql).stdout.strip() == 't':
            return
        time.sleep(0.05)
    raise AssertionError(f'{name} did not block on the expected transaction lock')


def release(proc):
    proc.stdin.write("COMMIT; SELECT 'RELEASED';\n")
    proc.stdin.flush()
    until(proc, 'RELEASED')
    proc.stdin.close()
    proc.wait(timeout=10)
    assert proc.returncode == 0, proc.stderr.read()


def finish(proc, expected_error=None):
    proc.stdin.close()
    proc.stdin = None
    out, err = proc.communicate(timeout=15)
    if expected_error:
        assert proc.returncode != 0 and expected_error in err, (out, err)
    else:
        assert proc.returncode == 0, err
    return out


def insert_object(bucket, path):
    query(f"INSERT INTO storage.objects(bucket_id,name,owner_id,metadata) VALUES ('{bucket}','{path}','{uid}'," +
          "'{\"mimetype\":\"image/jpeg\",\"size\":100}');")


try:
    query(f"""INSERT INTO auth.users(id, email, email_confirmed_at,raw_user_meta_data)
      VALUES ('{uid}','sql-race@example.invalid',now(),
      '{{"full_name":"Race Citizen","phone":"+923002220001","cnic":"12345-2220001-1","locations":"Fateh Jang","gender":"Other"}}');""")
    insert_object('reports-images', image)
    insert_object('profile-pictures', avatar)

    # A simultaneous identical create waits BEFORE lookup and reuses the code.
    first = start('BEGIN;'+auth+create+"SELECT 'HELD';")
    until(first, 'HELD')
    second = start("SET application_name='civic_race_retry'; BEGIN;"+auth+create+'COMMIT;')
    waiting('civic_race_retry')
    release(first)
    finish(second)
    assert query(f"SELECT count(*)||','||(SELECT counter FROM public.report_counters WHERE prefix='PD') FROM public.reports WHERE id='{request}';").stdout.strip() == '1,1'
    print('PASS: duplicate create serializes and allocates one counter')

    # A report is uncommitted and invisible when DELETE starts. The common
    # advisory lock must force reference lookup AFTER that report commits.
    query(f"DELETE FROM public.reports WHERE id='{request}';")
    first = start('BEGIN;'+auth+create+"SELECT 'HELD';")
    until(first, 'HELD')
    second = start("SET application_name='civic_race_media'; BEGIN;"+auth+
                   f"WITH d AS (DELETE FROM storage.objects WHERE bucket_id='reports-images' AND name='{image}' RETURNING 1) SELECT 'removed='||count(*) FROM d; COMMIT;")
    waiting('civic_race_media')
    release(first)
    assert 'removed=0' in finish(second)
    print('PASS: report attachment blocks client deletion after commit')

    # The trigger protects privileged deletes that bypass Storage RLS, too.
    query(f"DELETE FROM public.reports WHERE id='{request}';")
    first = start('BEGIN;'+auth+create+"SELECT 'HELD';")
    until(first, 'HELD')
    second = start("SET application_name='civic_race_admin'; BEGIN;"+
                   f"DELETE FROM storage.objects WHERE bucket_id='reports-images' AND name='{image}'; COMMIT;")
    waiting('civic_race_admin')
    release(first)
    finish(second, 'Photo is still referenced')
    print('PASS: trigger blocks privileged deletion after reference commit')

    # Reversing commit order rejects a report whose file was just deleted.
    query(f"DELETE FROM public.reports WHERE id='{request}';")
    first = start('BEGIN;'+auth+f"DELETE FROM storage.objects WHERE bucket_id='reports-images' AND name='{image}'; SELECT 'HELD';")
    until(first, 'HELD')
    second = start("SET application_name='civic_race_attach'; BEGIN;"+auth+create+'COMMIT;')
    waiting('civic_race_attach')
    release(first)
    finish(second, 'Invalid photo paths')
    assert query(f"SELECT count(*) FROM public.reports WHERE id='{request}';").stdout.strip() == '0'
    print('PASS: deletion commits first, attachment rejects missing object')
    insert_object('reports-images', image)
    query('BEGIN;'+auth+create+'COMMIT;')

    # Avatar attachment uses exactly the same lock protocol.
    first = start('BEGIN;'+auth+f"SELECT public.update_profile('Race Citizen','+923002220001','Fateh Jang','{avatar}'); SELECT 'HELD';")
    until(first, 'HELD')
    second = start("SET application_name='civic_race_avatar'; BEGIN;"+auth+
                   f"WITH d AS (DELETE FROM storage.objects WHERE bucket_id='profile-pictures' AND name='{avatar}' RETURNING 1) SELECT 'removed='||count(*) FROM d; COMMIT;")
    waiting('civic_race_avatar')
    release(first)
    assert 'removed=0' in finish(second)
    print('PASS: profile attachment blocks concurrent avatar deletion')

    # Two same-user toggles serialize to support then unsupport.
    first = start('BEGIN;'+auth+f"SELECT public.toggle_report_support('{request}'); SELECT 'HELD';")
    until(first, 'HELD')
    second = start("SET application_name='civic_race_support'; BEGIN;"+auth+
                   f"SELECT public.toggle_report_support('{request}'); COMMIT;")
    waiting('civic_race_support')
    release(first)
    finish(second)
    assert query(f"SELECT support_count||','||(SELECT count(*) FROM public.report_supports WHERE report_id='{request}') FROM public.reports WHERE id='{request}';").stdout.strip() == '0,0'
    print('PASS: concurrent same-user toggles preserve zero count and no membership')
finally:
    for proc in processes:
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=10)
    # Only this harness's synthetic account and object names are touched.
    query(f"DELETE FROM auth.users WHERE id='{uid}'; DELETE FROM storage.objects WHERE owner_id='{uid}';", allowed_failure=True)
