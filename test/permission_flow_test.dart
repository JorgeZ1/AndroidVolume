import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:floating_volume/src/bloc/permissions/bloc.dart' as b;
import 'package:floating_volume/src/bloc/permissions/event.dart' as e;
import 'package:floating_volume/src/bloc/permissions/state.dart' as s;
import 'package:floating_volume/src/services/monitoring_service.dart';
import 'package:floating_volume/src/screens/permissions.dart';

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('double tap and different permissions share one request gate', () async {
    final pending = Completer<PermissionStatus>();
    var calls = 0;
    final bloc = b.Bloc(
      const s.State(),
      read: (_) async => PermissionStatus.denied,
      request: (_) {
        calls++;
        return pending.future;
      },
    );
    bloc.add(e.Event.requestOverlayPermission);
    bloc.add(e.Event.requestOverlayPermission);
    bloc.add(e.Event.requestNotificationPermission);
    await settle();
    expect(calls, 1);
    expect(bloc.state.isRequesting, isTrue);
    pending.complete(PermissionStatus.denied);
    await settle();
    expect(bloc.state.isRequesting, isFalse);
    expect(bloc.state.overlayPermission.status, PermissionStatus.denied);
    await bloc.close();
  });
  test('platform failures are handled, categorized, and allow retry', () async {
    for (final message in [
      'A request for permissions is already running, please wait',
      'Unable to detect current Android Activity.',
    ]) {
      var calls = 0;
      final reports = <String>[];
      final bloc = b.Bloc(
        const s.State(),
        read: (_) async => PermissionStatus.denied,
        request: (_) async {
          if (calls++ == 0) {
            throw PlatformException(
              code: 'PermissionHandler.PermissionManager',
              message: message,
            );
          }
          return PermissionStatus.granted;
        },
        report: (_, _, context) async {
          reports.add(context);
        },
      );
      bloc.add(e.Event.requestOverlayPermission);
      await settle();
      expect(bloc.state.isRequesting, isFalse);
      expect(
        bloc.state.overlayPermission.operation,
        s.PermissionOperation.failed,
      );
      expect(
        reports.single,
        contains(
          message.startsWith('A request')
              ? 'request_in_progress'
              : 'activity_unavailable',
        ),
      );
      bloc.add(e.Event.requestOverlayPermission);
      await settle();
      expect(bloc.state.overlayPermission.status, PermissionStatus.granted);
      await bloc.close();
    }
  });
  test(
    'Settings resume refreshes permission without claiming an early grant',
    () async {
      var status = PermissionStatus.permanentlyDenied;
      var settingsCalls = 0;
      final bloc = b.Bloc(
        const s.State(),
        read: (_) async => status,
        settings: () async {
          settingsCalls++;
          return true;
        },
        request:
            (_) async =>
                throw StateError('must not request permanently denied'),
      );
      bloc.add(e.Event.requestOverlayPermission);
      await settle();
      expect(settingsCalls, 1);
      expect(
        bloc.state.overlayPermission.status,
        PermissionStatus.permanentlyDenied,
      );
      status = PermissionStatus.granted;
      bloc.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();
      expect(bloc.state.overlayPermission.status, PermissionStatus.granted);
      await bloc.close();
    },
  );
  test(
    'closing while a request is pending does not emit after close',
    () async {
      final pending = Completer<PermissionStatus>();
      final bloc = b.Bloc(
        const s.State(),
        read: (_) async => PermissionStatus.denied,
        request: (_) => pending.future,
      );
      bloc.add(e.Event.requestOverlayPermission);
      await settle();
      final closed = bloc.close();
      pending.complete(PermissionStatus.granted);
      await closed;
      expect(bloc.isClosed, isTrue);
    },
  );
  test(
    'status failures and monitoring failures cannot escape initialization',
    () async {
      var fail = true;
      final bloc = b.Bloc(
        const s.State(),
        read: (_) async {
          if (fail) throw PlatformException(code: 'unavailable');
          return PermissionStatus.granted;
        },
        report: (_, _, _) async => throw StateError('offline'),
      );
      bloc.add(e.Event.initialize);
      await settle();
      expect(bloc.state.isInitialized, isTrue);
      expect(bloc.state.isGranted, isFalse);
      fail = false;
      bloc.add(e.Event.initialize);
      await settle();
      expect(bloc.state.isInitialized, isTrue);
      expect(bloc.state.isGranted, isTrue);
      await bloc.close();
    },
  );
  test('permission telemetry never includes arbitrary messages or details', () {
    final category = MonitoringService.permissionErrorCategory(
      PlatformException(
        code: 'email@example.com',
        message: 'private report',
        details: 'private image',
      ),
    );
    expect(category, 'platform_error');
  });

  test('closing during initialization cannot restart polling', () async {
    final pending = Completer<PermissionStatus>();
    var reads = 0;
    final bloc = b.Bloc(
      const s.State(),
      pollingInterval: const Duration(milliseconds: 1),
      read: (_) {
        reads++;
        return pending.future;
      },
    );
    bloc.add(e.Event.initialize);
    await settle();
    final closed = bloc.close();
    pending.complete(PermissionStatus.denied);
    await closed;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(reads, 1);
  });

  testWidgets('permission UI disables every grant button during a request', (
    tester,
  ) async {
    final pending = Completer<PermissionStatus>();
    final bloc = b.Bloc(
      const s.State(),
      read: (_) async => PermissionStatus.denied,
      request: (_) => pending.future,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: bloc, child: const PermissionsScreen()),
      ),
    );
    final buttons = find.byType(FilledButton);
    expect(buttons, findsNWidgets(3));
    await tester.tap(buttons.first);
    await tester.pump();
    await tester.pump();
    for (final button in tester.widgetList<FilledButton>(buttons)) {
      expect(button.onPressed, isNull);
    }
    pending.complete(PermissionStatus.denied);
    await tester.pump();
    await tester.pump();
    for (final button in tester.widgetList<FilledButton>(buttons)) {
      expect(button.onPressed, isNotNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => bloc.close());
  });
}
