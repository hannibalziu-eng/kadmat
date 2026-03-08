import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kadmat/src/core/services/active_job_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ActiveJobSessionService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('active_job_session_test');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>('app_cache');
    service = ActiveJobSessionService();
  });

  tearDown(() async {
    if (Hive.isBoxOpen('app_cache')) {
      await Hive.box<dynamic>('app_cache').clear();
    }
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('sync stores active job session', () async {
    await service.sync(jobId: 'job-1', status: 'in_progress', userId: 'user-1');

    final session = await service.read(userId: 'user-1');
    expect(session, isNotNull);
    expect(session?.jobId, 'job-1');
    expect(session?.status, 'in_progress');
  });

  test('sync clears session when status becomes terminal', () async {
    await service.sync(jobId: 'job-2', status: 'on_the_way', userId: 'user-1');
    expect(await service.read(userId: 'user-1'), isNotNull);

    await service.sync(jobId: 'job-2', status: 'completed', userId: 'user-1');
    expect(await service.read(userId: 'user-1'), isNull);
  });

  test('read drops stale sessions older than ttl window', () async {
    await service.save(
      ActiveJobSession(
        jobId: 'job-3',
        status: 'on_the_way',
        updatedAt: DateTime.now().subtract(const Duration(hours: 60)),
      ),
      userId: 'user-1',
    );

    final session = await service.read(userId: 'user-1');
    expect(session, isNull);
  });
}
