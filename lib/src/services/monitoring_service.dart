import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'diagnostic_journal.dart';
export 'diagnostic_journal.dart' show DiagnosticOperation;

/// Technical monitoring only: never log report text, images, IDs or ad payloads.
class MonitoringService {
  static bool _ready = false;
  static Trace? _startup;
  static final _journal = DiagnosticJournal();
  static final _lifecycleObserver = _MonitoringLifecycleObserver();
  static const _events = {
    'first_frame',
    'rewarded_requested',
    'rewarded_closed_earned',
    'rewarded_closed_unearned',
    'rewarded_show_failed',
    'rewarded_earned',
    'app_resumed',
    'app_inactive',
    'app_hidden',
    'app_paused',
    'app_detached',
    'permission_settings_opened',
    'permission_request_dropped',
  };
  static const _debugEnabled = bool.fromEnvironment('MONITORING_DEBUG');
  static const _selfTest = bool.fromEnvironment('MONITORING_SELF_TEST');
  static bool get enabled => _ready;
  @visibleForTesting
  static String technicalErrorType(Object error) =>
      'TechnicalError:${error.runtimeType}';

  /// Fixed categories only; never send plugin messages, details or raw codes.
  static String permissionErrorCategory(Object error) {
    if (error is MissingPluginException) return 'plugin_unavailable';
    if (error is PlatformException) {
      final message = error.message ?? '';
      if (message.startsWith('A request for permissions is already running')) {
        return 'request_in_progress';
      }
      if (message.contains('Unable to detect current Android Activity')) {
        return 'activity_unavailable';
      }
      return 'platform_error';
    }
    return 'unexpected_error';
  }

  static String technicalErrorCategory(Object error) {
    if (error is MissingPluginException) return 'plugin_unavailable';
    if (error is TimeoutException) return 'timeout';
    if (error is PlatformException) {
      final permission = permissionErrorCategory(error);
      if (permission != 'platform_error') return permission;
      return switch (error.code) {
        'PermissionHandler.PermissionManager' => 'permission_manager',
        'channel-error' => 'channel_unavailable',
        'SecurityException' => 'security',
        'IllegalArgumentException' => 'invalid_argument',
        'IllegalStateException' => 'invalid_state',
        'TimeoutCancellationException' => 'timeout',
        _ => 'platform_error',
      };
    }
    return 'unexpected_error';
  }

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(); // Android resources select the build's app.
      final collect = kReleaseMode || _debugEnabled;
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        collect,
      );
      try {
        await FirebasePerformance.instance.setPerformanceCollectionEnabled(
          collect,
        );
      } catch (_) {}
      try {
        await const MethodChannel(
          'floating_volume/monitoring',
        ).invokeMethod<void>('setEnabled', collect);
      } catch (_) {}
      _ready = collect;
      if (!collect) return;
      WidgetsBinding.instance.addObserver(_lifecycleObserver);
      try {
        await FirebaseCrashlytics.instance.setCustomKey('diagnostic_schema', 1);
        await FirebaseCrashlytics.instance.setCustomKey(
          'build_mode',
          kReleaseMode ? 'release' : 'debug',
        );
      } catch (_) {}
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        previous?.call(details);
        // Framework errors are not necessarily fatal: the app may still run.
        unawaited(
          record(
            details.exception,
            details.stack ?? StackTrace.current,
            source: 'flutter_framework',
          ),
        );
      };
      final previousAsync = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(record(error, stack, source: 'dart_unhandled', fatal: true));
        previousAsync?.call(error, stack);
        return true;
      };
      try {
        _startup = FirebasePerformance.instance.newTrace('flutter_first_frame');
        await _startup!.start();
      } catch (_) {
        _startup = null;
      }
    } catch (_) {
      // Monitoring must never prevent startup, including offline/config failures.
      _ready = false;
      debugPrint('Technical monitoring initialization unavailable');
    }
  }

  static Future<void> record(
    Object error,
    StackTrace stack, {
    required String source,
    bool fatal = false,
    List<String> context = const [],
  }) async {
    if (!_ready) return;
    final safeSource = DiagnosticJournal.source(source);
    if (!_journal.allowError(
      '$safeSource:${error.runtimeType}',
      fatal: fatal,
    )) {
      return;
    }
    try {
      // Error messages can contain form contents or URLs; retain type and stack.
      try {
        await FirebaseCrashlytics.instance.setCustomKey(
          'flutter_error_category',
          technicalErrorCategory(error),
        );
      } catch (_) {}
      await FirebaseCrashlytics.instance.recordError(
        technicalErrorType(error),
        stack,
        reason: safeSource,
        fatal: fatal,
        information: [
          'error_category=${technicalErrorCategory(error)}',
          'lifecycle=${DiagnosticJournal.lifecycle(WidgetsBinding.instance.lifecycleState?.name)}',
          ..._journal.snapshot,
          ...context.where(DiagnosticJournal.safeContext),
        ],
      );
    } catch (_) {
      /* Diagnostics never affect the app's own workflow. */
    }
  }

  static Future<void> event(String name) async {
    if (!_ready || !_events.contains(name)) return;
    try {
      await FirebaseCrashlytics.instance.log(name);
    } catch (_) {}
  }

  /// Recoverable callers catch the rethrown exception and update their UI.
  /// Traces and records capture fixed context, never arguments/results/messages.
  static Future<T> operation<T>(
    DiagnosticOperation operation,
    Future<T> Function() action, {
    bool recordFailure = true,
  }) async {
    if (!_ready) return action();
    final id = _journal.begin(operation);
    unawaited(_logOperationStart(operation, id));
    final watch = Stopwatch()..start();
    try {
      final result = await _measure('diag_${operation.name}', action);
      _journal.add(operation, DiagnosticPhase.success, id);
      return result;
    } catch (error, stack) {
      _journal.add(operation, DiagnosticPhase.failure, id);
      if (recordFailure) {
        await record(
          error,
          stack,
          source: switch (operation) {
            DiagnosticOperation.serviceStart => 'service_start',
            DiagnosticOperation.serviceStop => 'service_stop',
            DiagnosticOperation.settingsUpdate => 'settings_update',
            DiagnosticOperation.reportSubmit => 'report_submit',
            _ => 'native_channel',
          },
          context: [
            'operation=${operation.name}',
            'operation_id=$id',
            'duration_ms=${watch.elapsedMilliseconds}',
            'lifecycle=${DiagnosticJournal.lifecycle(WidgetsBinding.instance.lifecycleState?.name)}',
          ],
        );
      }
      rethrow;
    } finally {
      try {
        await FirebaseCrashlytics.instance.log(_journal.snapshot.last);
        await FirebaseCrashlytics.instance.setCustomKey(
          'last_operation',
          operation.name,
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'last_operation_ms',
          watch.elapsedMilliseconds,
        );
      } catch (_) {}
    }
  }

  static Future<void> _logOperationStart(
    DiagnosticOperation operation,
    int id,
  ) async {
    try {
      await FirebaseCrashlytics.instance.log(
        'op=${operation.name} phase=start id=$id',
      );
    } catch (_) {}
  }

  static Future<void> permissionState(String name, String status) async {
    if (!_ready ||
        !const {'overlay', 'notification', 'battery'}.contains(name) ||
        !const {
          'denied',
          'granted',
          'restricted',
          'limited',
          'permanentlyDenied',
          'provisional',
        }.contains(status)) {
      return;
    }
    try {
      await FirebaseCrashlytics.instance.setCustomKey(
        'permission_$name',
        status,
      );
    } catch (_) {}
  }

  /// Measures an operation without exposing arguments, return values or errors.
  static Future<T> measure<T>(String name, Future<T> Function() operation) =>
      name == 'support_report_submit'
          ? MonitoringService.operation(
            DiagnosticOperation.reportSubmit,
            operation,
          )
          : _measure(name, operation);

  static Future<T> _measure<T>(
    String name,
    Future<T> Function() operation,
  ) async {
    if (!_ready) return operation();
    Trace? trace;
    try {
      trace = FirebasePerformance.instance.newTrace(name);
      await trace.start();
    } catch (_) {
      trace = null;
    }
    try {
      final result = await operation();
      try {
        trace?.putAttribute('result', 'success');
      } catch (_) {}
      return result;
    } catch (_) {
      try {
        trace?.putAttribute('result', 'failure');
      } catch (_) {}
      rethrow;
    } finally {
      try {
        await trace?.stop();
      } catch (_) {}
    }
  }

  static Future<void> firstFrame() async {
    try {
      await _startup?.stop();
    } catch (_) {}
    _startup = null;
    await event('first_frame');
    // Synthetic events only in an explicitly enabled debug build. No fatal crash.
    if (!kDebugMode || !_debugEnabled || !_selfTest || !_ready) return;
    await record(
      StateError('synthetic'),
      StackTrace.current,
      source: 'monitoring_self_test',
    );
    try {
      await operation(DiagnosticOperation.permissionOverlay, () async {
        throw PlatformException(
          code: 'PermissionHandler.PermissionManager',
          message: 'Unable to detect current Android Activity.',
        );
      }, recordFailure: false);
    } catch (error, stack) {
      await record(
        error,
        stack,
        source: 'monitoring_self_test',
        context: [
          'operation=permissionOverlay',
          'lifecycle=${DiagnosticJournal.lifecycle(WidgetsBinding.instance.lifecycleState?.name)}',
        ],
      );
    }
    try {
      await const MethodChannel(
        'floating_volume/monitoring',
      ).invokeMethod<void>('selfTest');
    } catch (error, stack) {
      await record(error, stack, source: 'native_self_test_channel');
    }
  }
}

class _MonitoringLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(MonitoringService.event('app_${state.name}'));
  }
}
