import 'dart:async';
import 'package:bloc/bloc.dart' as a;
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/monitoring_service.dart';
import 'event.dart' as e;
import 'state.dart' as s;

typedef PermissionReader = Future<PermissionStatus> Function(Permission);
typedef PermissionReporter = Future<void> Function(Object, StackTrace, String);

class Bloc extends a.Bloc<e.Event, s.State> with WidgetsBindingObserver {
  final PermissionReader _read;
  final PermissionReader _request;
  final Future<bool> Function() _settings;
  final PermissionReporter _report;
  Timer? _timer;
  bool _pending = false;
  bool _refreshing = false;
  bool _closing = false;
  final Duration pollingInterval;

  Bloc(
    super.initialState, {
    PermissionReader? read,
    PermissionReader? request,
    Future<bool> Function()? settings,
    PermissionReporter? report,
    this.pollingInterval = const Duration(seconds: 5),
  }) : _read = read ?? ((permission) => permission.status),
       _request = request ?? ((permission) => permission.request()),
       _settings = settings ?? openAppSettings,
       _report =
           report ??
           ((error, stack, context) =>
               MonitoringService.record(error, stack, source: context)) {
    WidgetsBinding.instance.addObserver(this);
    on<e.Event>((event, emit) async {
      if (_closing) return;
      if (event == e.Event.initialize) {
        if (_refreshing || _pending) return;
        _refreshing = true;
        try {
          for (final permission in _permissions) {
            if (_closing) return;
            try {
              final status = await _read(permission);
              if (_closing || emit.isDone) return;
              emit(
                _replace(
                  permission,
                  _value(permission).copyWith(
                    isInitialized: true,
                    status: status,
                    operation:
                        status.isGranted
                            ? s.PermissionOperation.none
                            : _value(permission).operation,
                  ),
                ),
              );
            } catch (error, stack) {
              await _diagnose(error, stack, permission, 'status');
              if (!emit.isDone) {
                // A failed status read must not strand startup on a spinner.
                // Retain the last known status, never invent a permission grant.
                emit(
                  _replace(
                    permission,
                    _value(permission).copyWith(
                      isInitialized: true,
                      operation: s.PermissionOperation.failed,
                    ),
                  ),
                );
              }
            }
          }
        } finally {
          _refreshing = false;
          if (!_closing && !isClosed) {
            _timer ??= Timer.periodic(pollingInterval, (_) {
              if (!isClosed) add(e.Event.initialize);
            });
          }
        }
        return;
      }
      // Claim the global gate before any await. Bloc events are concurrent.
      if (_pending || _refreshing) return;
      final permission = switch (event) {
        e.Event.requestOverlayPermission => Permission.systemAlertWindow,
        e.Event.requestNotificationPermission => Permission.notification,
        e.Event.requestBatteryOptimizationPermission =>
          Permission.ignoreBatteryOptimizations,
        e.Event.initialize => throw StateError('Unreachable'),
      };
      _pending = true;
      emit(
        _replace(
          permission,
          _value(
            permission,
          ).copyWith(operation: s.PermissionOperation.requestingPermission),
        ),
      );
      var failed = false;
      try {
        final status = await _read(permission);
        final permissionName =
            permission == Permission.systemAlertWindow
                ? 'overlay'
                : permission == Permission.notification
                ? 'notification'
                : 'battery';
        await MonitoringService.permissionState(permissionName, status.name);
        PermissionStatus result = status;
        if (status.isPermanentlyDenied) {
          await MonitoringService.event('permission_settings_opened');
          if (!await _settings()) throw StateError('settings_unavailable');
          // Opening Settings is not a grant. Resume/poll reads the actual status.
        } else if (!status.isGranted) {
          result = await MonitoringService.operation(
            permission == Permission.systemAlertWindow
                ? DiagnosticOperation.permissionOverlay
                : permission == Permission.notification
                ? DiagnosticOperation.permissionNotification
                : DiagnosticOperation.permissionBattery,
            () => _request(permission),
            recordFailure: false,
          );
        }
        await MonitoringService.permissionState(permissionName, result.name);
        if (!emit.isDone) {
          emit(
            _replace(permission, _value(permission).copyWith(status: result)),
          );
        }
      } catch (error, stack) {
        failed = true;
        await _diagnose(error, stack, permission, 'request');
      } finally {
        _pending = false;
        if (!emit.isDone) {
          emit(
            _replace(
              permission,
              _value(permission).copyWith(
                operation:
                    failed
                        ? s.PermissionOperation.failed
                        : s.PermissionOperation.none,
              ),
            ),
          );
        }
      }
    });
  }

  static const _permissions = [
    Permission.systemAlertWindow,
    Permission.notification,
    Permission.ignoreBatteryOptimizations,
  ];

  s.PermissionState _value(Permission permission) =>
      permission == Permission.systemAlertWindow
          ? state.overlayPermission
          : permission == Permission.notification
          ? state.notificationPermission
          : state.batteryOptimizationPermission;

  s.State _replace(Permission permission, s.PermissionState value) =>
      permission == Permission.systemAlertWindow
          ? state.copyWith(overlayPermission: value)
          : permission == Permission.notification
          ? state.copyWith(notificationPermission: value)
          : state.copyWith(batteryOptimizationPermission: value);

  Future<void> _diagnose(
    Object error,
    StackTrace stack,
    Permission permission,
    String stage,
  ) async {
    final name =
        permission == Permission.systemAlertWindow
            ? 'overlay'
            : permission == Permission.notification
            ? 'notification'
            : 'battery';
    final lifecycle = WidgetsBinding.instance.lifecycleState?.name ?? 'unknown';
    final category = MonitoringService.permissionErrorCategory(error);
    try {
      await _report(
        error,
        stack,
        'permission_${name}_${stage}_${category}_$lifecycle',
      );
    } catch (_) {
      /* Monitoring cannot break permission recovery. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !isClosed) {
      add(e.Event.initialize);
    }
  }

  @override
  Future<void> close() {
    _closing = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    return super.close();
  }
}
