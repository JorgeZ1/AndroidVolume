import 'package:flutter_test/flutter_test.dart';
import 'package:floating_volume/src/services/monitoring_service.dart';

void main() {
  test('disabled measurement executes once and preserves result', () async {
    var calls = 0;
    final result = await MonitoringService.measure('test', () async {
      calls++;
      return 7;
    });
    expect(result, 7);
    expect(calls, 1);
  });
  test('disabled measurement preserves operation failures', () async {
    final error = StateError('original');
    await expectLater(
      MonitoringService.measure('test', () async => throw error),
      throwsA(same(error)),
    );
  });
  test('error telemetry excludes arbitrary messages and personal text', () {
    final safe = MonitoringService.technicalErrorType(
      StateError('email@example.com private report text'),
    );
    expect(safe, 'TechnicalError:StateError');
    expect(safe, isNot(contains('email@example.com')));
    expect(safe, isNot(contains('private report')));
  });
  test(
    'disabled monitoring never calls Firebase for events or errors',
    () async {
      expect(MonitoringService.enabled, isFalse);
      await MonitoringService.event('test_event');
      await MonitoringService.record(
        StateError('private text'),
        StackTrace.current,
        source: 'test',
      );
      await MonitoringService.firstFrame();
      expect(MonitoringService.enabled, isFalse);
    },
  );
}
