import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:floating_volume/src/app_language.dart';
import 'services/monitoring_service.dart';

enum WidgetColorMode { auto, blue, dark }

enum AudioStream { media, ring, notification, alarm, system, voiceCall }

extension AudioStreamUi on AudioStream {
  String get label => switch (this) {
    AudioStream.media => tr('Media', 'Multimedia'),
    AudioStream.ring => tr('Ringtone', 'Tono de llamada'),
    AudioStream.notification => tr('Notifications', 'Notificaciones'),
    AudioStream.alarm => tr('Alarm', 'Alarma'),
    AudioStream.system => tr('System', 'Sistema'),
    AudioStream.voiceCall => tr('Voice call', 'Llamada'),
  };
}

enum WidgetStyle {
  android,
  android12,
  ios,
  miui,
  samsungOneUi,
  rgbAurora,
  rgbNeon,
  cosmic,
  lava,
  glacier,
  matrix,
  retrowave,
}

class WidgetSettings {
  WidgetSettings._();

  static const _ch = MethodChannel('floating_volume/settings');
  static const _events = EventChannel('floating_volume/settings_changes');
  static final changes = ValueNotifier<int>(0);
  static final lastError = ValueNotifier<String?>(null);
  static StreamSubscription<dynamic>? _subscription;
  static Future<void> _tail = Future<void>.value();
  static int _lastRevision = -1;

  static double opacity = 0.70;
  static WidgetColorMode colorMode = WidgetColorMode.auto;
  static WidgetStyle style = WidgetStyle.android;
  static bool isPinned = false;
  static bool useSystemVolume = false;
  static AudioStream selectedAudioStream = AudioStream.media;
  static bool showAudioMixer = true;
  static bool autoPeekEnabled = true;
  static int autoPeekDelay = 1800;
  static int peekSize = 20;
  static double creativeAnimSpeed = 1.0;
  static double creativeGlowIntensity = 1.0;
  static int volumeStep = 1;
  static bool hapticFeedback = false;
  static bool showIndicatorNumber = true;
  static bool showIndicatorIcon = true;
  static int buttonSize = 44;
  static double buttonCornerRadius = 0.5;
  static int buttonGap = 10;
  static double indicatorOpacity = 0.85;
  static int indicatorHeight = 135;
  static int indicatorWidth = 36;
  static int indicatorGap = 10;
  static int indicatorHideDelay = 1800;
  static String indicatorAnimation = 'fade';

  static Future<bool> initialize() async {
    _subscription ??= _events.receiveBroadcastStream().listen((event) {
      try {
        _apply(Map<Object?, Object?>.from(event as Map));
      } catch (_) {
        // A failed/malformed event does not replace the last confirmed state.
      }
    }, onError: (Object error) {});
    return load();
  }

  // Reads and writes share a queue so resume cannot race a pending slider write.
  static Future<bool> load() => _request('getSettings');

  static Future<bool> _request(String method, [Map<String, Object?>? args]) {
    final operation = _tail.then((_) async {
      try {
        final result = await MonitoringService.operation(
          DiagnosticOperation.settingsUpdate,
          () => _ch.invokeMapMethod<Object?, Object?>(method, args),
        );
        if (result == null) throw StateError('Missing settings snapshot');
        _apply(result);
        lastError.value = null;
        return true;
      } catch (_) {
        lastError.value = tr(
          'Could not load or save settings. Please try again.',
          'No se pudieron cargar o guardar los ajustes. Inténtalo de nuevo.',
        );
        changes.value++;
        return false;
      }
    });
    _tail = operation.then((_) {});
    return operation;
  }

  static void _apply(Map<Object?, Object?> data) {
    const integers = [
      'buttonSize',
      'buttonGap',
      'indicatorHeight',
      'indicatorWidth',
      'indicatorGap',
      'indicatorHideDelay',
      'autoPeekDelay',
      'peekSize',
      'volumeStep',
    ];
    const decimals = [
      'opacity',
      'buttonCornerRadius',
      'indicatorOpacity',
      'creativeAnimSpeed',
      'creativeGlowIntensity',
    ];
    const booleans = [
      'isPinned',
      'useSystemVolume',
      'showAudioMixer',
      'autoPeekEnabled',
      'hapticFeedback',
      'showIndicatorNumber',
      'showIndicatorIcon',
    ];
    for (final name in [...integers, ...decimals]) {
      if (data[name] is! num || !(data[name] as num).isFinite) {
        throw StateError('Invalid numeric setting');
      }
    }
    for (final name in booleans) {
      if (data[name] is! bool) throw StateError('Invalid boolean setting');
    }
    final nextStyle = WidgetStyle.values.firstWhere(
      (s) => s.name == data['style'],
    );
    final nextColor = WidgetColorMode.values.firstWhere(
      (c) => c.name == data['colorMode'],
    );
    final nextStream = AudioStream.values.firstWhere(
      (s) => _streamName(s) == data['selectedAudioStream'],
    );
    if (data['indicatorAnimation'] is! String) {
      throw StateError('Invalid animation');
    }
    final revision = (data['revision'] as num).toInt();
    if (revision < _lastRevision) return;
    _lastRevision = revision;
    opacity = (data['opacity'] as num).toDouble();
    colorMode = nextColor;
    style = nextStyle;
    isPinned = data['isPinned'] as bool;
    useSystemVolume = data['useSystemVolume'] as bool;
    selectedAudioStream = nextStream;
    showAudioMixer = data['showAudioMixer'] as bool;
    autoPeekEnabled = data['autoPeekEnabled'] as bool;
    autoPeekDelay = (data['autoPeekDelay'] as num).toInt();
    peekSize = (data['peekSize'] as num).toInt();
    creativeAnimSpeed = (data['creativeAnimSpeed'] as num).toDouble();
    creativeGlowIntensity = (data['creativeGlowIntensity'] as num).toDouble();
    volumeStep = (data['volumeStep'] as num).toInt();
    hapticFeedback = data['hapticFeedback'] as bool;
    showIndicatorNumber = data['showIndicatorNumber'] as bool;
    showIndicatorIcon = data['showIndicatorIcon'] as bool;
    buttonSize = (data['buttonSize'] as num).toInt();
    buttonCornerRadius = (data['buttonCornerRadius'] as num).toDouble();
    buttonGap = (data['buttonGap'] as num).toInt();
    indicatorOpacity = (data['indicatorOpacity'] as num).toDouble();
    indicatorHeight = (data['indicatorHeight'] as num).toInt();
    indicatorWidth = (data['indicatorWidth'] as num).toInt();
    indicatorGap = (data['indicatorGap'] as num).toInt();
    indicatorHideDelay = (data['indicatorHideDelay'] as num).toInt();
    indicatorAnimation = data['indicatorAnimation'] as String;
    lastError.value = null;
    changes.value++;
  }

  static String _streamName(AudioStream stream) =>
      stream == AudioStream.voiceCall
          ? 'VOICE_CALL'
          : stream.name.toUpperCase();

  static Future<void> _update(String name, Object value) async {
    await _request('updateSettings', {name: value});
  }

  static Future<void> setOpacity(double v) => _update('opacity', v);
  static Future<void> setColorMode(WidgetColorMode v) =>
      _update('colorMode', v.name);
  static Future<void> setWidgetStyle(WidgetStyle v) => _update('style', v.name);
  static Future<void> setPinned(bool v) => _update('isPinned', v);
  static Future<void> setUseSystemVolume(bool v) =>
      _update('useSystemVolume', v);
  static Future<void> setAudioStream(AudioStream v) =>
      _update('selectedAudioStream', _streamName(v));
  static Future<void> setShowAudioMixer(bool v) => _update('showAudioMixer', v);
  static Future<void> setAutoPeekEnabled(bool v) =>
      _update('autoPeekEnabled', v);
  static Future<void> setAutoPeekDelay(int v) => _update('autoPeekDelay', v);
  static Future<void> setPeekSize(int v) => _update('peekSize', v);
  static Future<void> setCreativeAnimSpeed(double v) =>
      _update('creativeAnimSpeed', v);
  static Future<void> setCreativeGlowIntensity(double v) =>
      _update('creativeGlowIntensity', v);
  static Future<void> setVolumeStep(int v) => _update('volumeStep', v);
  static Future<void> setHapticFeedback(bool v) => _update('hapticFeedback', v);
  static Future<void> setShowIndicatorNumber(bool v) =>
      _update('showIndicatorNumber', v);
  static Future<void> setShowIndicatorIcon(bool v) =>
      _update('showIndicatorIcon', v);
  static Future<void> setButtonSize(int v) => _update('buttonSize', v);
  static Future<void> setButtonCornerRadius(double v) =>
      _update('buttonCornerRadius', v);
  static Future<void> setButtonGap(int v) => _update('buttonGap', v);
  static Future<void> setIndicatorOpacity(double v) =>
      _update('indicatorOpacity', v);
  static Future<void> setIndicatorHeight(int v) =>
      _update('indicatorHeight', v);
  static Future<void> setIndicatorWidth(int v) => _update('indicatorWidth', v);
  static Future<void> setIndicatorGap(int v) => _update('indicatorGap', v);
  static Future<void> setIndicatorHideDelay(int v) =>
      _update('indicatorHideDelay', v);
  static Future<void> setIndicatorAnimation(String v) =>
      _update('indicatorAnimation', v);
  static Future<void> loadButtonCornerRadius() async {
    await load();
  }

  static double cornerSliderPosition(double radius) =>
      0.5 - radius.clamp(0.0, 0.5);
  static double defaultCornerRadius(WidgetStyle style) => switch (style) {
    WidgetStyle.miui => 0.2,
    WidgetStyle.samsungOneUi => 0.3,
    _ => 0.5,
  };

  static String formatDelay(int milliseconds) {
    var seconds = (milliseconds / 1000)
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    if (LanguageSettings.isSpanish) seconds = seconds.replaceAll('.', ',');
    return '$seconds s';
  }

  static Future<bool> restoreButtonsDefaults() =>
      _request('restoreSection', {'section': 'buttons'});
  static Future<bool> restoreAudioDefaults() =>
      _request('restoreSection', {'section': 'audio'});
  static Future<bool> restoreIndicatorDefaults() =>
      _request('restoreSection', {'section': 'indicator'});
  static Future<bool> restoreCreativeDefaults() =>
      _request('restoreSection', {'section': 'creative'});
  static Future<bool> restoreDefaultsForStyle(WidgetStyle style) =>
      _request('restoreSection', {'section': 'all'});

  @visibleForTesting
  static Future<void> resetConnectionForTesting() async {
    await _subscription?.cancel();
    _subscription = null;
    await _tail;
    _tail = Future<void>.value();
    _lastRevision = -1;
    lastError.value = null;
  }
}
