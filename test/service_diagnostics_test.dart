import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floating_volume/src/bloc/status/bloc.dart' as b;
import 'package:floating_volume/src/bloc/status/event.dart' as e;
import 'package:floating_volume/src/bloc/status/state.dart' as s;

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('native start failure is recoverable and retry can succeed', () async {
    var attempts = 0;
    final bloc = b.Bloc(
      const s.State(),
      start: () async {
        if (attempts++ == 0) {
          throw PlatformException(code: 'unavailable', message: 'private');
        }
      },
      show: () async {},
    );
    bloc.add(e.Event.enable);
    await settle();
    expect(bloc.state.operation, s.Operation.failed);
    expect(bloc.state.isEnabled, isFalse);
    bloc.add(e.Event.enable);
    await settle();
    expect(bloc.state.isEnabled, isTrue);
    expect(bloc.state.isVisible, isTrue);
    expect(bloc.state.operation, s.Operation.none);
    await bloc.close();
  });
  test('show failure preserves confirmed service state', () async {
    final bloc = b.Bloc(
      const s.State(),
      start: () async {},
      show: () async => throw PlatformException(code: 'detached'),
    );
    bloc.add(e.Event.enable);
    await settle();
    expect(bloc.state.isEnabled, isTrue);
    expect(bloc.state.isVisible, isFalse);
    expect(bloc.state.operation, s.Operation.failed);
    await bloc.close();
  });
  test('stop failure does not claim service was stopped', () async {
    final bloc = b.Bloc(
      const s.State(isEnabled: true, isVisible: true),
      hide: () async {},
      stop: () async => throw PlatformException(code: 'unavailable'),
    );
    bloc.add(e.Event.disable);
    await settle();
    expect(bloc.state.isEnabled, isTrue);
    expect(bloc.state.isVisible, isFalse);
    expect(bloc.state.operation, s.Operation.failed);
    await bloc.close();
  });
  test('repeated toggles cannot overlap native transitions', () async {
    final pending = Completer<void>();
    var calls = 0;
    final bloc = b.Bloc(
      const s.State(),
      start: () {
        calls++;
        return pending.future;
      },
      show: () async {},
    );
    bloc.add(e.Event.enable);
    bloc.add(e.Event.enable);
    await settle();
    expect(calls, 1);
    pending.complete();
    await settle();
    expect(bloc.state.isEnabled, isTrue);
    await bloc.close();
  });
}
