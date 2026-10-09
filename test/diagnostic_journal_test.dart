import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:floating_volume/src/services/diagnostic_journal.dart';
import 'package:floating_volume/src/services/monitoring_service.dart';

void main() {
  test('native error codes are mapped without exposing arbitrary codes', () {
    expect(
      MonitoringService.technicalErrorCategory(
        PlatformException(code: 'SecurityException'),
      ),
      'security',
    );
    expect(
      MonitoringService.technicalErrorCategory(
        PlatformException(code: 'email@example.com', message: 'private text'),
      ),
      'platform_error',
    );
  });
  test('journal is bounded and operation IDs are process-local counters', () {
    var now = 0;
    final journal = DiagnosticJournal(clock: () => now++);
    for (var i = 1; i <= 100; i++) {
      expect(journal.begin(DiagnosticOperation.serviceStart), i);
    }
    expect(journal.snapshot.length, 30);
    expect(journal.snapshot.first, contains('id=71'));
    expect(() => journal.snapshot.add('private'), throwsUnsupportedError);
  });
  test(
    'nonfatal repeats are limited but fatal events are never suppressed',
    () {
      var now = 0;
      final journal = DiagnosticJournal(clock: () => now);
      expect(journal.allowError('permission'), isTrue);
      expect(journal.allowError('permission'), isFalse);
      expect(journal.allowError('permission', fatal: true), isTrue);
      now = 59999;
      expect(journal.allowError('permission'), isFalse);
      now = 60000;
      expect(journal.allowError('permission'), isTrue);
    },
  );
  test('deduplication map has a fixed capacity', () {
    final journal = DiagnosticJournal(clock: () => 0);
    for (var i = 0; i < 65; i++) {
      journal.allowError('category_$i');
    }
    expect(journal.allowError('category_0'), isTrue);
    expect(journal.allowError('category_64'), isFalse);
  });
  test(
    'sources cannot contain arbitrary plugin messages or report content',
    () {
      for (final value in [
        'email@example.com',
        'private_report',
        'https://example.com',
        'permission_overlay_request_private_resumed',
      ]) {
        expect(DiagnosticJournal.source(value), 'technical_error');
      }
      expect(
        DiagnosticJournal.source(
          'permission_overlay_request_activity_unavailable_paused',
        ),
        'permission_overlay_request_activity_unavailable_paused',
      );
    },
  );
  test('only fixed context values and bounded numbers are permitted', () {
    for (final value in [
      'operation=permissionOverlay',
      'duration_ms=123',
      'operation_id=2',
      'lifecycle=paused',
      'permission_status=denied',
    ]) {
      expect(DiagnosticJournal.safeContext(value), isTrue);
    }
    for (final value in [
      'operation=private_report',
      'lifecycle=user_name',
      'duration_ms=-1',
      'duration_ms=999999999',
      'email=email@example.com',
      'operation=nativeChannel=private',
    ]) {
      expect(DiagnosticJournal.safeContext(value), isFalse);
    }
  });
  test(
    'disabled diagnostics preserve operation result and original failure',
    () async {
      var calls = 0;
      final result = await MonitoringService.operation(
        DiagnosticOperation.serviceStart,
        () async {
          calls++;
          return 9;
        },
      );
      expect(result, 9);
      expect(calls, 1);
      final error = StateError('private report');
      await expectLater(
        MonitoringService.operation(
          DiagnosticOperation.nativeChannel,
          () async => throw error,
        ),
        throwsA(same(error)),
      );
    },
  );
}
