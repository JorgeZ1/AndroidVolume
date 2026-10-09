import 'dart:collection';

enum DiagnosticOperation {
  permissionOverlay,
  permissionNotification,
  permissionBattery,
  serviceStart,
  serviceStop,
  settingsUpdate,
  reportSubmit,
  nativeChannel,
}

enum DiagnosticPhase { start, success, failure, cancelled }

/// In-memory, process-local context. No user/installation/session identifier.
class DiagnosticJournal {
  DiagnosticJournal({int Function()? clock})
    : _clock = clock ?? (() => _watch.elapsedMilliseconds);
  static final _watch = Stopwatch()..start();
  final int Function() _clock;
  final _events = Queue<String>();
  final _errors = <String, int>{};
  int _sequence = 0;
  static const capacity = 30;

  int begin(DiagnosticOperation operation) {
    final id = ++_sequence;
    add(operation, DiagnosticPhase.start, id);
    return id;
  }

  void add(DiagnosticOperation operation, DiagnosticPhase phase, int id) {
    _events.add(
      't=${_clock()} op=${operation.name} phase=${phase.name} id=$id',
    );
    while (_events.length > capacity) {
      _events.removeFirst();
    }
  }

  List<String> get snapshot => List.unmodifiable(_events);
  bool allowError(String fingerprint, {bool fatal = false}) {
    if (fatal) return true;
    final now = _clock();
    final previous = _errors[fingerprint];
    if (previous != null && now - previous < 60000) return false;
    if (_errors.length >= 64 && !_errors.containsKey(fingerprint)) {
      _errors.remove(_errors.keys.first);
    }
    _errors[fingerprint] = now;
    return true;
  }

  static String lifecycle(String? value) =>
      const {
            'resumed',
            'inactive',
            'hidden',
            'paused',
            'detached',
          }.contains(value)
          ? value!
          : 'unknown';
  static String source(String value) {
    if (const {
      'flutter_framework',
      'dart_unhandled',
      'monitoring_self_test',
      'native_self_test_channel',
      'service_start',
      'service_stop',
      'native_channel',
      'settings_update',
      'report_submit',
      'test',
    }.contains(value)) {
      return value;
    }
    if (RegExp(
      r'^permission_(overlay|notification|battery)_(status|request)_(request_in_progress|activity_unavailable|platform_error|plugin_unavailable|unexpected_error)_(resumed|inactive|hidden|paused|detached|unknown)$',
    ).hasMatch(value)) {
      return value;
    }
    return 'technical_error';
  }

  static bool safeContext(String line) {
    final parts = line.split('=');
    if (parts.length != 2) return false;
    final value = parts[1];
    return switch (parts[0]) {
      'operation' => DiagnosticOperation.values.any((op) => op.name == value),
      'operation_id' ||
      'duration_ms' => int.tryParse(value)?.letSafeNumber() ?? false,
      'lifecycle' => lifecycle(value) == value,
      'permission_status' => const {
        'denied',
        'granted',
        'restricted',
        'limited',
        'permanentlyDenied',
        'provisional',
      }.contains(value),
      _ => false,
    };
  }
}

extension on int {
  bool letSafeNumber() => this >= 0 && this <= 86400000;
}
