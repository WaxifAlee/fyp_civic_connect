#!/usr/bin/env python3
"""Check comment/account lock ordering through independent Supabase SQL sessions.

Requires migrations 001..008 and an authenticated Supabase CLI. Creates only
random synthetic Auth/report fixtures, then removes them in finally. All racing
comment transactions roll back; the final account-deletion transaction commits.
No project keys or account passwords are read or printed.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import secrets
import subprocess
import tempfile
import time
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--remote', required=True, help='Explicit target project reference')
parser.add_argument('--cli', default='supabase')
args = parser.parse_args()


def main():
    uid, rid = str(uuid.uuid4()), str(uuid.uuid4())
    nonce = uuid.uuid4().hex[:10]
    phone = '+923' + ''.join(secrets.choice('0123456789') for _ in range(9))
    cnic = '99999-' + ''.join(secrets.choice('0123456789') for _ in range(7)) + '-1'
    claims = json.dumps({'sub': uid, 'role': 'authenticated'})
    auth = f"SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claims','{claims}',true);"
    add = f"SELECT public.add_report_comment('{rid}','Concurrent account-deletion test','{uuid.uuid4()}');"
    limits = "SET LOCAL lock_timeout='22s'; SET LOCAL statement_timeout='28s';"
    with tempfile.TemporaryDirectory(prefix='civic-comment-races-') as tmp:
        def query(sql, expected_error=None):
            file = Path(tmp) / (uuid.uuid4().hex + '.sql')
            file.write_text(sql)
            result = subprocess.run([args.cli, 'db', 'query', '--remote='+args.remote,
                '--file', str(file), '--yes'], text=True, capture_output=True, timeout=40)
            output = result.stdout + result.stderr
            if expected_error:
                assert expected_error in output and '40P01' not in output, output
                return None
            assert result.returncode == 0 and '"_tag":"Error"' not in output, output
            return json.JSONDecoder().raw_decode(result.stdout[result.stdout.index('{'):])[0]

        def waiting(name, event):
            deadline = time.monotonic() + 13
            while time.monotonic() < deadline:
                result = query("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE "
                    f"application_name='{name}' AND wait_event='{event}') AS waiting;")
                if result['rows'][0]['waiting']:
                    return
                time.sleep(.1)
            raise AssertionError(f'{name} did not reach {event}')

        try:
            query(f"""BEGIN;
INSERT INTO auth.users(id,email,email_confirmed_at,raw_user_meta_data) VALUES
 ('{uid}','comment-lock-{nonce}@example.invalid',now(),
 '{{"full_name":"Comment Lock Test","phone":"{phone}","cnic":"{cnic}","locations":"Fateh Jang","gender":"Other"}}');
INSERT INTO public.reports(id,reporter_id,title,description,category,latitude,longitude,media_paths,report_code)
 VALUES('{rid}','{uid}','Synthetic comment lock test','Temporary fixture for concurrent account deletion.',
 'Municipal Corportaion',33.55,72.63,ARRAY['{uid}/synthetic.jpg'],'COMMENTLOCK{nonce}');
COMMIT;""")
            with ThreadPoolExecutor(max_workers=2) as pool:
                # Hold the first lock used by add while account deletion queues.
                # Add then acquires the report in the same order as the cascade.
                first_name, second_name = 'comment-add-'+nonce, 'comment-delete-'+nonce
                first = pool.submit(query, f"BEGIN; {limits} SET LOCAL application_name='{first_name}'; "
                    f"SELECT 1 FROM public.profiles WHERE id='{uid}' FOR KEY SHARE; "
                    f"SELECT pg_sleep(15); {auth} {add} RESET ROLE; ROLLBACK;")
                waiting(first_name, 'PgSleep')
                second = pool.submit(query, f"BEGIN; {limits} SET LOCAL application_name='{second_name}'; "
                    f"DELETE FROM auth.users WHERE id='{uid}'; ROLLBACK;")
                # tuple/transaction locks report their type as transactionid.
                waiting(second_name, 'transactionid')
                first.result(); second.result()
                print('PASS add-first: account cascade waits; comment completes without deadlock', flush=True)

                # Account deletion owns its cascade first. A pending post must
                # reject after commit rather than recreate the report/comment.
                first = pool.submit(query, f"BEGIN; {limits} SET LOCAL application_name='{first_name}'; "
                    f"DELETE FROM auth.users WHERE id='{uid}'; SELECT pg_sleep(15); COMMIT;")
                waiting(first_name, 'PgSleep')
                second = pool.submit(query, f"BEGIN; {limits} SET LOCAL application_name='{second_name}'; "
                    f"{auth} {add} RESET ROLE; ROLLBACK;", '42501')
                waiting(second_name, 'transactionid')
                first.result(); second.result()
                print('PASS delete-first: pending comment rejects after account deletion; no resurrection', flush=True)
            result = query(f"SELECT NOT EXISTS(SELECT 1 FROM public.reports WHERE id='{rid}') "
                f"AND NOT EXISTS(SELECT 1 FROM civic_private.report_comments WHERE report_id='{rid}') AS cleaned;")
            assert result['rows'][0]['cleaned']
        finally:
            query(f"DELETE FROM auth.users WHERE id='{uid}';")


if __name__ == '__main__':
    main()
