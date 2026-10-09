import 'dart:async';
import 'package:bloc/bloc.dart' as a;
import 'package:floating_volume/generated/native_events.g.dart';
import 'package:floating_volume/src/single.dart';
import 'package:floating_volume/src/services/monitoring_service.dart';

import 'event.dart' as e;
import 'state.dart' as s;

class Bloc extends a.Bloc<e.Event, s.State> {
  bool _changing = false;
  bool _closing = false;
  bool? _enabled;
  bool? _visible;
  StreamSubscription<bool>? _serviceSubscription;
  StreamSubscription<bool>? _visibilitySubscription;
  final Future<void> Function() _start, _show, _hide, _stop;
  Bloc(
    super.initialState, {
    Future<void> Function()? start,
    Future<void> Function()? show,
    Future<void> Function()? hide,
    Future<void> Function()? stop,
  }) : _start = start ?? nativeApi.startService,
       _show = show ?? nativeApi.showFloatingVolume,
       _hide = hide ?? nativeApi.hideFloatingVolume,
       _stop = stop ?? nativeApi.stopService {
    on<e.Event>((event, emit) async {
      if (_closing) return;
      switch (event) {
        case e.Event.initialize:
          _serviceSubscription ??= serviceStatus().listen((value) {
            _enabled = value;
            if (!_closing) add(e.Event.nativeStatusChanged);
          }, onError: _streamError);
          _visibilitySubscription ??= floatingVolumeVisibility().listen((
            value,
          ) {
            _visible = value;
            if (!_closing) add(e.Event.nativeStatusChanged);
          }, onError: _streamError);
          break;
        case e.Event.nativeStatusChanged:
          emit(
            state.copyWith(
              isEnabled: _enabled ?? state.isEnabled,
              isVisible: _visible ?? state.isVisible,
            ),
          );
          break;

        case e.Event.enable:
          if (_changing) return;
          _changing = true;
          emit(state.copyWith(operation: s.Operation.enabling));
          try {
            await MonitoringService.operation(
              DiagnosticOperation.serviceStart,
              _start,
            );
            if (emit.isDone) return;
            emit(state.copyWith(isEnabled: true));

            await MonitoringService.operation(
              DiagnosticOperation.nativeChannel,
              _show,
            );
            if (emit.isDone) return;
            emit(state.copyWith(isVisible: true, operation: s.Operation.none));
          } catch (_) {
            if (!emit.isDone) {
              emit(state.copyWith(operation: s.Operation.failed));
            }
          } finally {
            _changing = false;
          }
          break;

        case e.Event.disable:
          if (_changing) return;
          _changing = true;
          emit(state.copyWith(operation: s.Operation.disabling));
          try {
            await MonitoringService.operation(
              DiagnosticOperation.nativeChannel,
              _hide,
            );
            if (emit.isDone) return;
            emit(state.copyWith(isVisible: false));

            await MonitoringService.operation(
              DiagnosticOperation.serviceStop,
              _stop,
            );
            if (emit.isDone) return;
            emit(state.copyWith(isEnabled: false, operation: s.Operation.none));
          } catch (_) {
            if (!emit.isDone) {
              emit(state.copyWith(operation: s.Operation.failed));
            }
          } finally {
            _changing = false;
          }
          break;

        case e.Event.toggle:
          if (state.isEnabled) {
            add(e.Event.disable);
          } else {
            add(e.Event.enable);
          }
          break;
      }
    });
  }

  void _streamError(Object error, StackTrace stack) {
    unawaited(MonitoringService.record(error, stack, source: 'native_channel'));
  }

  @override
  Future<void> close() async {
    _closing = true;
    await _serviceSubscription?.cancel();
    await _visibilitySubscription?.cancel();
    await super.close();
  }
}
