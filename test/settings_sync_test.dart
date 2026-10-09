import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floating_volume/src/widget_settings.dart';
import 'package:floating_volume/src/app_language.dart';

Map<String, Object> snapshot([Map<String, Object> overrides = const {}]) => {
  'colorMode': 'auto',
  'opacity': 0.7,
  'style': 'android',
  'isPinned': false,
  'buttonSize': 44,
  'buttonCornerRadius': 0.5,
  'buttonGap': 10,
  'indicatorOpacity': 0.85,
  'indicatorHeight': 135,
  'indicatorWidth': 36,
  'indicatorGap': 10,
  'indicatorHideDelay': 1800,
  'indicatorAnimation': 'fade',
  'useSystemVolume': false,
  'selectedAudioStream': 'MEDIA',
  'showAudioMixer': true,
  'autoPeekEnabled': true,
  'autoPeekDelay': 1800,
  'peekSize': 20,
  'creativeAnimSpeed': 1.0,
  'creativeGlowIntensity': 1.0,
  'volumeStep': 1,
  'hapticFeedback': false,
  'showIndicatorNumber': true,
  'showIndicatorIcon': true,
  'revision': 0,
  ...overrides,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('floating_volume/settings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    await WidgetSettings.resetConnectionForTesting();
    messenger.setMockMethodCallHandler(channel, (_) async => snapshot());
    await WidgetSettings.load();
    LanguageSettings.selection.value = AppLanguage.english;
  });
  tearDown(() async {
    await WidgetSettings.resetConnectionForTesting();
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('floating_volume/settings_changes'),
      null,
    );
  });

  test(
    'cold load restores nondefault controls without replaying setters',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return snapshot({
          'volumeStep': 3,
          'buttonSize': 64,
          'opacity': 0.4,
          'hapticFeedback': true,
          'selectedAudioStream': 'ALARM',
          'showAudioMixer': false,
          'autoPeekDelay': 12000,
          'peekSize': 26,
          'indicatorWidth': 62,
          'showIndicatorNumber': false,
          'creativeAnimSpeed': 1.5,
          'revision': 2,
        });
      });
      expect(await WidgetSettings.load(), isTrue);
      expect(calls, ['getSettings']);
      expect(WidgetSettings.volumeStep, 3);
      expect(WidgetSettings.buttonSize, 64);
      expect(WidgetSettings.opacity, 0.4);
      expect(WidgetSettings.hapticFeedback, isTrue);
      expect(WidgetSettings.selectedAudioStream, AudioStream.alarm);
      expect(WidgetSettings.showAudioMixer, isFalse);
      expect(WidgetSettings.autoPeekDelay, 12000);
      expect(WidgetSettings.peekSize, 26);
      expect(WidgetSettings.indicatorWidth, 62);
      expect(WidgetSettings.showIndicatorNumber, isFalse);
      expect(WidgetSettings.creativeAnimSpeed, 1.5);
    },
  );

  test(
    'native accepted value is displayed instead of requested value',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'updateSettings');
        expect(call.arguments, {'volumeStep': 20});
        return snapshot({'volumeStep': 5, 'revision': 1});
      });
      await WidgetSettings.setVolumeStep(20);
      expect(WidgetSettings.volumeStep, 5);
    },
  );

  test(
    'failed write preserves last confirmed value and permits retry',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      await WidgetSettings.setVolumeStep(3);
      expect(WidgetSettings.volumeStep, 1);
      expect(WidgetSettings.lastError.value, isNotNull);
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => snapshot({'volumeStep': 3, 'revision': 1}),
      );
      await WidgetSettings.setVolumeStep(3);
      expect(WidgetSettings.volumeStep, 3);
      expect(WidgetSettings.lastError.value, isNull);
    },
  );

  test(
    'resume read waits for queued writes and cannot undo slider selection',
    () async {
      final releaseWrite = Completer<void>();
      final started = Completer<void>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'updateSettings') {
          started.complete();
          await releaseWrite.future;
        }
        return snapshot({'volumeStep': 3, 'revision': 1});
      });
      final write = WidgetSettings.setVolumeStep(3);
      await started.future;
      final read = WidgetSettings.load();
      expect(calls, ['updateSettings']);
      releaseWrite.complete();
      await write;
      await read;
      expect(calls, ['updateSettings', 'getSettings']);
      expect(WidgetSettings.volumeStep, 3);
    },
  );

  test(
    'native mixer events update channel and stale reads cannot replace it',
    () async {
      messenger.setMockMethodCallHandler(
        const MethodChannel('floating_volume/settings_changes'),
        (_) async => null,
      );
      await WidgetSettings.initialize();
      final handled = Completer<void>();
      messenger.handlePlatformMessage(
        'floating_volume/settings_changes',
        const StandardMethodCodec().encodeSuccessEnvelope(
          snapshot({'selectedAudioStream': 'ALARM', 'revision': 2}),
        ),
        (_) => handled.complete(),
      );
      await handled.future;
      await Future<void>.delayed(Duration.zero);
      expect(WidgetSettings.selectedAudioStream, AudioStream.alarm);
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => snapshot({'revision': 1}),
      );
      await WidgetSettings.load();
      expect(WidgetSettings.selectedAudioStream, AudioStream.alarm);
    },
  );

  test(
    'section reset applies one full confirmation and retains other categories',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'restoreSection');
        expect(call.arguments, {'section': 'buttons'});
        return snapshot({
          'selectedAudioStream': 'ALARM',
          'indicatorWidth': 62,
          'revision': 1,
        });
      });
      expect(await WidgetSettings.restoreButtonsDefaults(), isTrue);
      expect(WidgetSettings.autoPeekEnabled, isTrue);
      expect(WidgetSettings.volumeStep, 1);
      expect(WidgetSettings.selectedAudioStream, AudioStream.alarm);
      expect(WidgetSettings.indicatorWidth, 62);
    },
  );

  test(
    'malformed snapshots cannot partially replace confirmed state',
    () async {
      final invalid = snapshot({'volumeStep': 4})..remove('showAudioMixer');
      messenger.setMockMethodCallHandler(channel, (_) async => invalid);
      expect(await WidgetSettings.load(), isFalse);
      expect(WidgetSettings.volumeStep, 1);
    },
  );

  test('time labels retain precision in both languages', () {
    expect(WidgetSettings.formatDelay(1800), '1.8 s');
    expect(WidgetSettings.formatDelay(5000), '5 s');
    expect(WidgetSettings.formatDelay(1830), '1.83 s');
    LanguageSettings.selection.value = AppLanguage.spanish;
    expect(WidgetSettings.formatDelay(1800), '1,8 s');
  });
}
