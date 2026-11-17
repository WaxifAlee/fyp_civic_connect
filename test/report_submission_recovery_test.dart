import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/features/reports/data/report_submission_service.dart';
import 'package:fyp_civic_connect/services/report_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryReportBackend extends ReportBackend {
  String? uid = '11111111-1111-4111-8111-111111111111';
  final uploads = <String>[];
  final storedPhotos = <String>{};
  final removals = <String>[];
  final creates = <Map<String, dynamic>>[];
  Map<String, dynamic>? committed;
  bool loseCreateResponse = false;
  bool commitBeforeFailure = true;
  bool hideLookup = false;
  bool deleted = false;
  bool serverCleanedPhotos = false;
  String? createErrorCode;
  int lookups = 0;
  int? failUpload;
  void Function()? afterUpload;
  Completer<void>? createGate;

  @override
  bool get isConfigured => true;
  @override
  String? get verifiedUserId => uid;
  @override
  Future<void> upload(String path, Uint8List bytes, String contentType) async {
    uploads.add(path);
    storedPhotos.add(path);
    afterUpload?.call();
    if (uploads.length == failUpload) throw StateError('upload response lost');
  }

  @override
  Future<void> remove(List<String> paths) async => removals.addAll(paths);
  @override
  String publicUrl(String bucket, String path) =>
      'https://example.test/$bucket/$path';
  @override
  Future<dynamic> rpc(String name, Map<String, dynamic> params) async {
    if (name == 'get_report_submission') {
      lookups++;
      if (hideLookup) return null;
      if (deleted && committed != null) {
        if (serverCleanedPhotos) storedPhotos.clear();
        return {'id': committed!['id'], 'deleted': true, 'images': <String>[]};
      }
      return committed;
    }
    if (name != 'create_report') throw StateError(name);
    creates.add(Map.of(params));
    await createGate?.future;
    if (createErrorCode != null) {
      throw PostgrestException(
          message: 'request rejected', code: createErrorCode);
    }
    final result = {
      'id': params['p_request_id'],
      'reportCode': 'MC00001',
      'images': params['p_media_paths'],
    };
    if (!loseCreateResponse || commitBeforeFailure) committed = result;
    if (loseCreateResponse) throw StateError('response lost');
    return result;
  }
}

Future<ReportSubmissionResult> submit(
  ReportSubmissionService service, {
  String title = 'Broken streetlight',
  List<XFile>? images,
}) =>
    service.submit(
      title: title,
      description: 'The streetlight near the market is broken.',
      category: 'Municipal Corportaion',
      location: FatehJangArea.center,
      images: images ??
          [
            XFile.fromData(Uint8List.fromList([255, 216, 255, 1])),
          ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.leavePreview();
  });

  test('confirmation keeps another tab request added during its await',
      () async {
    final backend = MemoryReportBackend()..createGate = Completer<void>();
    final future = submit(ReportSubmissionService(backend: backend));
    while (backend.creates.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final prefs = await SharedPreferences.getInstance();
    final firstKey = prefs.getKeys().single;
    final first =
        jsonDecode(prefs.getString(firstKey)!) as Map<String, dynamic>;
    const otherId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    final other = Map<String, dynamic>.from(first)
      ..['requestId'] = otherId
      ..['payload'] = {...first['payload'] as Map, 'p_request_id': otherId};
    final otherKey = 'reports.pending_submission.v2.${backend.uid}.$otherId';
    await prefs.setString(otherKey, jsonEncode(other));
    backend.createGate!.complete();
    await future;
    expect(prefs.getString(otherKey), jsonEncode(other));
    expect(prefs.getString(firstKey), isNull);
    expect(firstKey,
        'reports.pending_submission.v2.${backend.uid}.${first['requestId']}');
  });

  for (final photosAlreadyCleaned in [false, true]) {
    test(
        'unknown create then deleted lookup is terminal, photos cleaned: '
        '$photosAlreadyCleaned', () async {
      final backend = MemoryReportBackend()
        ..loseCreateResponse = true
        ..hideLookup = true;
      final service = ReportSubmissionService(backend: backend);
      await expectLater(
          submit(service), throwsA(isA<ReportSubmissionException>()));
      final original = Map.of(backend.creates.single);
      // Server cleanup may already have removed the blobs. Neither case
      // authorizes this client to upload, create or clean anything again.
      if (photosAlreadyCleaned) backend.storedPhotos.clear();
      final uploadCount = backend.uploads.length;
      backend
        ..hideLookup = false
        ..deleted = true;
      await expectLater(
          submit(ReportSubmissionService(backend: backend)),
          throwsA(isA<ReportSubmissionException>().having(
              (e) => e.message,
              'terminal message',
              'Earlier report was removed; submit your current draft when ready.')));
      expect(backend.creates, [original]);
      expect(backend.uploads, hasLength(uploadCount));
      expect(backend.removals, isEmpty);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    });
  }

  test('retired UUID P0002 is terminal even when lookup is unavailable',
      () async {
    final backend = MemoryReportBackend()
      ..loseCreateResponse = true
      ..hideLookup = true;
    final service = ReportSubmissionService(backend: backend);
    await expectLater(
        submit(service), throwsA(isA<ReportSubmissionException>()));
    backend.createErrorCode = 'P0002';
    await expectLater(
        submit(service),
        throwsA(isA<ReportSubmissionException>().having(
            (e) => e.message,
            'terminal message',
            'Earlier report was removed; submit your current draft when ready.')));
    expect(backend.creates.last, backend.creates.first);
    expect(backend.uploads, hasLength(1));
    expect(backend.removals, isEmpty);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('enumeration reloads a stale tab cache before discovering requests',
      () async {
    final backend = MemoryReportBackend()
      ..loseCreateResponse = true
      ..hideLookup = true;
    final service = ReportSubmissionService(backend: backend);
    await expectLater(
        submit(service), throwsA(isA<ReportSubmissionException>()));
    final writerTab = await SharedPreferences.getInstance();
    final key = writerTab.getKeys().single;
    final raw = writerTab.getString(key)!;
    await writerTab.remove(key);
    SharedPreferences.resetStatic();
    final readerTab = await SharedPreferences.getInstance();
    await writerTab.setString(key, raw);
    expect(readerTab.getKeys(), isEmpty);
    expect(await service.pendingSubmissionCount(), 1);
    expect(readerTab.getString(key), raw);
    backend.hideLookup = false;
    expect((await service.recoverPending())!.reportCode, 'MC00001');
    await writerTab.reload();
    expect(writerTab.getKeys(), isEmpty);
    expect(backend.creates, hasLength(1));
  });

  for (final cleaned in [false, true]) {
    test(
        'lost create immediately reconciles terminal deletion, cleaned: $cleaned',
        () async {
      final backend = MemoryReportBackend()
        ..loseCreateResponse = true
        ..deleted = true
        ..serverCleanedPhotos = cleaned;
      await expectLater(submit(ReportSubmissionService(backend: backend)),
          throwsA(isA<DeletedReportSubmissionException>()));
      expect(backend.creates, hasLength(1));
      expect(backend.uploads, hasLength(1));
      expect(backend.storedPhotos, hasLength(cleaned ? 0 : 1));
      expect(backend.removals, isEmpty);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    });
  }

  test('direct recovery needs no current draft or local photos', () async {
    final backend = MemoryReportBackend()
      ..loseCreateResponse = true
      ..hideLookup = true;
    await expectLater(submit(ReportSubmissionService(backend: backend)),
        throwsA(isA<ReportSubmissionException>()));
    backend.hideLookup = false;
    final restarted = ReportSubmissionService(backend: backend);
    expect(await restarted.pendingSubmissionCount(), 1);
    expect((await restarted.recoverPending())!.reportCode, 'MC00001');
    expect(await restarted.pendingSubmissionCount(), 0);
    expect(await restarted.recoverPending(), isNull);
    expect(backend.creates, hasLength(1));
    expect(backend.uploads, hasLength(1));
  });

  test('legacy UID entry migrates and recovers without changing request',
      () async {
    final backend = MemoryReportBackend()
      ..loseCreateResponse = true
      ..hideLookup = true;
    final service = ReportSubmissionService(backend: backend);
    await expectLater(
        submit(service), throwsA(isA<ReportSubmissionException>()));
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().single;
    final raw = prefs.getString(key)!;
    final legacyKey = 'reports.pending_submission.v1.${backend.uid}';
    await prefs.setString(legacyKey, raw);
    await prefs.remove(key);
    expect(await service.pendingSubmissionCount(), 1);
    expect(prefs.getString(legacyKey), isNull);
    expect(prefs.getString(key), raw);
    backend.hideLookup = false;
    expect((await service.recoverPending())!.reportCode, 'MC00001');
    expect(prefs.getKeys(), isEmpty);
    expect(backend.creates, hasLength(1));
  });

  test('recovery confirms one request while another tab persists a request',
      () async {
    final backend = MemoryReportBackend()
      ..loseCreateResponse = true
      ..hideLookup = true;
    final service = ReportSubmissionService(backend: backend);
    await expectLater(
        submit(service), throwsA(isA<ReportSubmissionException>()));
    final writerTab = await SharedPreferences.getInstance();
    SharedPreferences.resetStatic();
    final readerTab = await SharedPreferences.getInstance();
    backend
      ..loseCreateResponse = false
      ..createGate = Completer<void>();
    final recovering = service.recoverPending();
    while (backend.creates.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    final prefs = await SharedPreferences.getInstance();
    final original =
        jsonDecode(prefs.getString(prefs.getKeys().single)!) as Map;
    const otherId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    final other = Map<String, dynamic>.from(original)
      ..['requestId'] = otherId
      ..['payload'] = {...original['payload'] as Map, 'p_request_id': otherId};
    final otherKey = 'reports.pending_submission.v2.${backend.uid}.$otherId';
    await writerTab.setString(otherKey, jsonEncode(other));
    expect(readerTab.getString(otherKey), isNull);
    backend.createGate!.complete();
    expect((await recovering)!.reportCode, 'MC00001');
    expect(await service.pendingSubmissionCount(), 1);
    expect(prefs.getString(otherKey), jsonEncode(other));
    expect((await service.recoverPending())!.reportCode, 'MC00001');
    expect(await service.pendingSubmissionCount(), 0);
    expect(backend.creates.last['p_request_id'], otherId);
    expect(backend.uploads, hasLength(1));
    expect(backend.removals, isEmpty);
  });

  test('deleted recovery removes only its own request entry', () async {
    final backend = MemoryReportBackend()
      ..loseCreateResponse = true
      ..hideLookup = true;
    final service = ReportSubmissionService(backend: backend);
    await expectLater(
        submit(service), throwsA(isA<ReportSubmissionException>()));
    final prefs = await SharedPreferences.getInstance();
    final originalKey = prefs.getKeys().single;
    final original = jsonDecode(prefs.getString(originalKey)!) as Map;
    const otherId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    final other = Map<String, dynamic>.from(original)
      ..['requestId'] = otherId
      ..['payload'] = {...original['payload'] as Map, 'p_request_id': otherId};
    final otherKey = 'reports.pending_submission.v2.${backend.uid}.$otherId';
    // Add the second entry during confirmation so the chosen request is fixed.
    backend.createGate = Completer<void>();
    final recovering = service.recoverPending();
    while (backend.creates.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    await prefs.setString(otherKey, jsonEncode(other));
    backend.createErrorCode = 'P0002';
    backend.createGate!.complete();
    await expectLater(
        recovering, throwsA(isA<DeletedReportSubmissionException>()));
    expect(prefs.getString(originalKey), isNull);
    expect(prefs.getString(otherKey), jsonEncode(other));
    expect(await service.pendingSubmissionCount(), 1);
    expect(backend.removals, isEmpty);
  });

  test('generic 23514 does not retire a request after null lookup', () async {
    final backend = MemoryReportBackend()
      ..loseCreateResponse = true
      ..hideLookup = true;
    final service = ReportSubmissionService(backend: backend);
    await expectLater(
        submit(service), throwsA(isA<ReportSubmissionException>()));
    backend.createErrorCode = '23514';
    await expectLater(
        service.recoverPending(),
        throwsA(isA<ReportSubmissionException>().having(
            (e) => e is DeletedReportSubmissionException, 'terminal', false)));
    expect(await service.pendingSubmissionCount(), 1);
    expect(backend.uploads, hasLength(1));
    expect(backend.removals, isEmpty);
  });

  test('recovery never calls RPC without the original verified account',
      () async {
    final backend = MemoryReportBackend()
      ..loseCreateResponse = true
      ..hideLookup = true;
    final service = ReportSubmissionService(backend: backend);
    await expectLater(
        submit(service), throwsA(isA<ReportSubmissionException>()));
    final lookups = backend.lookups;
    backend.uid = null;
    expect(await service.pendingSubmissionCount(), 0);
    await expectLater(
        service.recoverPending(), throwsA(isA<ReportSubmissionException>()));
    backend.uid = '22222222-2222-4222-8222-222222222222';
    expect(await service.pendingSubmissionCount(), 0);
    expect(await service.recoverPending(), isNull);
    AppSession.instance.enterPreview();
    expect(await service.pendingSubmissionCount(), 0);
    await expectLater(
        service.recoverPending(), throwsA(isA<ReportSubmissionException>()));
    AppSession.instance.leavePreview();
    expect(backend.lookups, lookups);
    expect(backend.creates, hasLength(1));
    expect((await SharedPreferences.getInstance()).getKeys(), hasLength(1));
  });

  test(
    'lost create response reconciles committed success without cleanup',
    () async {
      final backend = MemoryReportBackend()..loseCreateResponse = true;
      final result = await submit(ReportSubmissionService(backend: backend));
      expect(result.reportCode, 'MC00001');
      expect(backend.removals, isEmpty);
      expect(backend.uploads.single, startsWith('${backend.uid}/'));
      expect(
        backend.creates.single['p_request_id'],
        matches(RegExp(r'^[0-9a-f-]{36}$')),
      );
    },
  );

  test(
    'restart retries identical request after null lookup without reupload',
    () async {
      final backend = MemoryReportBackend()
        ..loseCreateResponse = true
        ..commitBeforeFailure = false
        ..hideLookup = true;
      await expectLater(
        submit(ReportSubmissionService(backend: backend)),
        throwsA(isA<ReportSubmissionException>()),
      );
      final original = Map.of(backend.creates.single);
      expect(backend.removals, isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), isNotEmpty);
      backend.loseCreateResponse = false;
      final result = await submit(ReportSubmissionService(backend: backend));
      expect(result.reportCode, 'MC00001');
      expect(backend.creates.last, original);
      expect(backend.uploads, hasLength(1));
      expect(preferences.getKeys(), isEmpty);
    },
  );

  test('two accounts keep and recover independent pending request UUIDs',
      () async {
    final backend = MemoryReportBackend()
      ..loseCreateResponse = true
      ..hideLookup = true;
    final firstUid = backend.uid!;
    final service = ReportSubmissionService(backend: backend);
    await expectLater(
        submit(service), throwsA(isA<ReportSubmissionException>()));
    final firstRequest = Map.of(backend.creates.single);
    final prefs = await SharedPreferences.getInstance();
    final firstKey =
        'reports.pending_submission.v2.$firstUid.${firstRequest['p_request_id']}';
    final firstRecord = prefs.getString(firstKey);
    expect(firstRecord, isNotNull);

    backend.uid = '22222222-2222-4222-8222-222222222222';
    await expectLater(submit(ReportSubmissionService(backend: backend)),
        throwsA(isA<ReportSubmissionException>()));
    expect(backend.creates, hasLength(2));
    final secondRequest = Map.of(backend.creates.last);
    final secondKey =
        'reports.pending_submission.v2.${backend.uid}.${secondRequest['p_request_id']}';
    final secondRecord = prefs.getString(secondKey);
    expect(secondRecord, isNotNull);
    expect(secondRequest['p_request_id'], isNot(firstRequest['p_request_id']));
    expect(backend.uploads.last, startsWith('${backend.uid}/'));
    expect(prefs.getString(firstKey), firstRecord);

    backend.uid = firstUid;
    backend.loseCreateResponse = false;
    await submit(ReportSubmissionService(backend: backend));
    expect(backend.creates.last, firstRequest);
    expect(prefs.getString(firstKey), isNull);
    expect(prefs.getString(secondKey), secondRecord);

    backend.uid = '22222222-2222-4222-8222-222222222222';
    await submit(ReportSubmissionService(backend: backend));
    expect(backend.creates.last, secondRequest);
    expect(prefs.getKeys(), isEmpty);
    expect(backend.uploads, hasLength(2));
    expect(backend.removals, isEmpty);
  });

  test(
    'changed draft recovers prior report distinctly and keeps the draft',
    () async {
      final backend = MemoryReportBackend()
        ..loseCreateResponse = true
        ..hideLookup = true;
      await expectLater(
        submit(ReportSubmissionService(backend: backend)),
        throwsA(isA<ReportSubmissionException>()),
      );
      backend.loseCreateResponse = false;
      await expectLater(
        submit(
          ReportSubmissionService(backend: backend),
          title: 'A different issue',
        ),
        throwsA(
          isA<PreviousReportSubmissionException>().having(
            (e) => e.reportCode,
            'prior reference',
            'MC00001',
          ),
        ),
      );
      expect(backend.creates.last['p_title'], 'Broken streetlight');
      expect(backend.uploads, hasLength(1));
    },
  );

  test('changed photo bytes also distinguish a new draft', () async {
    final backend = MemoryReportBackend()
      ..loseCreateResponse = true
      ..hideLookup = true;
    await expectLater(
      submit(ReportSubmissionService(backend: backend)),
      throwsA(isA<ReportSubmissionException>()),
    );
    backend.loseCreateResponse = false;
    await expectLater(
      submit(
        ReportSubmissionService(backend: backend),
        images: [
          XFile.fromData(Uint8List.fromList([255, 216, 255, 2])),
        ],
      ),
      throwsA(isA<PreviousReportSubmissionException>()),
    );
  });

  test('all photos validate before the first upload', () async {
    final backend = MemoryReportBackend();
    await expectLater(
      submit(
        ReportSubmissionService(backend: backend),
        images: [
          XFile.fromData(Uint8List.fromList([255, 216, 255])),
          XFile.fromData(Uint8List.fromList([0])),
        ],
      ),
      throwsA(isA<ReportSubmissionException>()),
    );
    expect(backend.uploads, isEmpty);
    expect(backend.creates, isEmpty);
  });

  test(
    'pre-dispatch upload failure cleans attempted paths only for same UID',
    () async {
      final backend = MemoryReportBackend()..failUpload = 1;
      await expectLater(
        submit(ReportSubmissionService(backend: backend)),
        throwsA(isA<ReportSubmissionException>()),
      );
      expect(backend.removals, backend.uploads);
      expect(backend.creates, isEmpty);
    },
  );

  test('session change during upload prevents create and cleanup', () async {
    final backend = MemoryReportBackend();
    backend.afterUpload = () => backend.uid = null;
    await expectLater(
      submit(ReportSubmissionService(backend: backend)),
      throwsA(isA<ReportSubmissionException>()),
    );
    expect(backend.creates, isEmpty);
    expect(backend.removals, isEmpty);
  });

  test(
    'concurrent service instances cannot allocate two pending requests',
    () async {
      final backend = MemoryReportBackend()..createGate = Completer<void>();
      final first = submit(ReportSubmissionService(backend: backend));
      while (backend.creates.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await expectLater(
        submit(ReportSubmissionService(backend: backend)),
        throwsA(isA<ReportSubmissionException>()),
      );
      backend.createGate!.complete();
      await first;
      expect(backend.creates, hasLength(1));
    },
  );
  test(
      'restart finds an already committed request without sending create again',
      () async {
    final backend = MemoryReportBackend()
      ..loseCreateResponse = true
      ..hideLookup = true;
    await expectLater(submit(ReportSubmissionService(backend: backend)),
        throwsA(isA<ReportSubmissionException>()));
    backend.hideLookup = false;
    final result = await submit(ReportSubmissionService(backend: backend));
    expect(result.reportCode, 'MC00001');
    expect(backend.creates, hasLength(1));
    expect(backend.uploads, hasLength(1));
    expect(backend.removals, isEmpty);
  });

  test(
      'session change during create keeps durable state and never cleans photos',
      () async {
    final backend = MemoryReportBackend()..createGate = Completer<void>();
    final future = submit(ReportSubmissionService(backend: backend));
    while (backend.creates.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final originalUid = backend.uid;
    backend.uid = null;
    backend.createGate!.complete();
    await expectLater(future, throwsA(isA<ReportSubmissionException>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isNotEmpty);
    expect(backend.removals, isEmpty);
    backend.uid = originalUid;
    final result = await submit(ReportSubmissionService(backend: backend));
    expect(result.reportCode, 'MC00001');
    expect(backend.creates, hasLength(1));
  });

  test('corrupt pending state blocks replacement requests and all uploads',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final backend = MemoryReportBackend();
    final key = 'reports.pending_submission.v1.${backend.uid}';
    await prefs.setString(key, '{broken');
    await expectLater(submit(ReportSubmissionService(backend: backend)),
        throwsA(isA<ReportSubmissionException>()));
    expect(backend.uploads, isEmpty);
    expect(backend.creates, isEmpty);
    expect(prefs.getString(key), '{broken');
  });

  test('changed unreadable photo still recovers earlier report distinctly',
      () async {
    final backend = MemoryReportBackend()
      ..loseCreateResponse = true
      ..hideLookup = true;
    await expectLater(submit(ReportSubmissionService(backend: backend)),
        throwsA(isA<ReportSubmissionException>()));
    backend.loseCreateResponse = false;
    await expectLater(
        submit(ReportSubmissionService(backend: backend),
            images: [XFile.fromData(Uint8List(0))]),
        throwsA(isA<PreviousReportSubmissionException>()));
    expect(backend.uploads, hasLength(1));
    expect(backend.creates.last, backend.creates.first);
  });
}
