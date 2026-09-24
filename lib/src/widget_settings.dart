import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WidgetColorMode { auto, blue, dark }

enum AudioStream { media, ring, notification, alarm, system, voiceCall }

extension AudioStreamUi on AudioStream {
  String get label => switch (this) {
    AudioStream.media => 'Multimedia',
    AudioStream.ring => 'Tono de llamada',
    AudioStream.notification => 'Notificaciones',
    AudioStream.alarm => 'Alarma',
    AudioStream.system => 'Sistema',
    AudioStream.voiceCall => 'Llamada',
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

  static double opacity = 0.70;
  static WidgetColorMode colorMode = WidgetColorMode.auto;
  static WidgetStyle style = WidgetStyle.android;
  static bool isPinned = false;

  static Future<void> setOpacity(double value) async {
    opacity = value;
    await _ch.invokeMethod('setOpacity', {'value': value});
  }

  static Future<void> setColorMode(WidgetColorMode mode) async {
    colorMode = mode;
    await _ch.invokeMethod('setColorMode', {
      'mode': switch (mode) {
        WidgetColorMode.blue => 'blue',
        WidgetColorMode.dark => 'dark',
        WidgetColorMode.auto => 'auto',
      },
    });
  }

  static Future<void> setWidgetStyle(WidgetStyle s) async {
    style = s;
    await _ch.invokeMethod('setStyle', {'style': s.name});
  }

  static Future<void> setPinned(bool value) async {
    isPinned = value;
    await _ch.invokeMethod('setPinned', {'pinned': value});
  }

  static bool useSystemVolume = false;
  static Future<void> setUseSystemVolume(bool value) async {
    useSystemVolume = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('widget_use_sys_vol', value);
    await _ch.invokeMethod('setUseSystemVolume', {'value': value});
  }

  static AudioStream selectedAudioStream = AudioStream.media;
  static Future<void> setAudioStream(AudioStream value) async {
    selectedAudioStream = value;
    await _ch.invokeMethod('setAudioStream', {
      'value': switch (value) {
        AudioStream.media => 'MEDIA',
        AudioStream.ring => 'RING',
        AudioStream.notification => 'NOTIFICATION',
        AudioStream.alarm => 'ALARM',
        AudioStream.system => 'SYSTEM',
        AudioStream.voiceCall => 'VOICE_CALL',
      },
    });
  }

  static bool showAudioMixer = true;
  static Future<void> setShowAudioMixer(bool value) async {
    showAudioMixer = value;
    await _ch.invokeMethod('setShowAudioMixer', {'value': value});
  }

  static bool autoPeekEnabled = true;
  static Future<void> setAutoPeekEnabled(bool value) async {
    autoPeekEnabled = value;
    await _ch.invokeMethod('setAutoPeekEnabled', {'value': value});
  }

  static int autoPeekDelay = 1800;
  static Future<void> setAutoPeekDelay(int value) async {
    autoPeekDelay = value;
    await _ch.invokeMethod('setAutoPeekDelay', {'value': value});
  }

  static int peekSize = 16;
  static Future<void> setPeekSize(int value) async {
    peekSize = value;
    await _ch.invokeMethod('setPeekSize', {'value': value});
  }

  static double creativeAnimSpeed = 1.0;
  static double creativeGlowIntensity = 1.0;

  static Future<void> setCreativeAnimSpeed(double value) async {
    creativeAnimSpeed = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('widget_crt_speed', value);
    await _ch.invokeMethod('setCreativeAnimSpeed', {'value': value});
  }

  static Future<void> setCreativeGlowIntensity(double value) async {
    creativeGlowIntensity = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('widget_crt_glow', value);
    await _ch.invokeMethod('setCreativeGlowIntensity', {'value': value});
  }

  /// Niveles de volumen que mueve cada tap de +/-
  static int volumeStep = 1;
  static Future<void> setVolumeStep(int value) async {
    volumeStep = value;
    await _ch.invokeMethod('setVolumeStep', {'value': value});
  }

  /// Vibración al tocar +/-
  static bool hapticFeedback = false;
  static Future<void> setHapticFeedback(bool value) async {
    hapticFeedback = value;
    await _ch.invokeMethod('setHapticFeedback', {'value': value});
  }

  /// Mostrar el número de volumen en la barra
  static bool showIndicatorNumber = true;
  static Future<void> setShowIndicatorNumber(bool value) async {
    showIndicatorNumber = value;
    await _ch.invokeMethod('setShowIndicatorNumber', {'value': value});
  }

  /// Mostrar la etiqueta/ícono inferior (VOL / 🔊) en la barra
  static bool showIndicatorIcon = true;
  static Future<void> setShowIndicatorIcon(bool value) async {
    showIndicatorIcon = value;
    await _ch.invokeMethod('setShowIndicatorIcon', {'value': value});
  }

  static int buttonSize = 44;
  static Future<void> setButtonSize(int value) async {
    buttonSize = value;
    await _ch.invokeMethod('setButtonSize', {'value': value});
  }

  static double buttonCornerRadius = 0.5;
  static Future<void> setButtonCornerRadius(double value) async {
    buttonCornerRadius = value;
    await _ch.invokeMethod('setButtonCornerRadius', {'value': value});
  }

  static int buttonGap = 10;
  static Future<void> setButtonGap(int value) async {
    buttonGap = value;
    await _ch.invokeMethod('setButtonGap', {'value': value});
  }

  static double indicatorOpacity = 0.85;
  static Future<void> setIndicatorOpacity(double value) async {
    indicatorOpacity = value;
    await _ch.invokeMethod('setIndicatorOpacity', {'value': value});
  }

  static int indicatorHeight = 135;
  static Future<void> setIndicatorHeight(int value) async {
    indicatorHeight = value;
    await _ch.invokeMethod('setIndicatorHeight', {'value': value});
  }

  static int indicatorWidth = 36;
  static Future<void> setIndicatorWidth(int value) async {
    indicatorWidth = value;
    await _ch.invokeMethod('setIndicatorWidth', {'value': value});
  }

  static int indicatorGap = 10;
  static Future<void> setIndicatorGap(int value) async {
    indicatorGap = value;
    await _ch.invokeMethod('setIndicatorGap', {'value': value});
  }

  static int indicatorHideDelay = 1800;
  static Future<void> setIndicatorHideDelay(int value) async {
    indicatorHideDelay = value;
    await _ch.invokeMethod('setIndicatorHideDelay', {'value': value});
  }

  static String indicatorAnimation = "fade";
  static Future<void> setIndicatorAnimation(String value) async {
    indicatorAnimation = value;
    await _ch.invokeMethod('setIndicatorAnimation', {'value': value});
  }

  static Future<void> restoreButtonsDefaults() async {
    final radius = switch (style) {
      WidgetStyle.miui => 0.2,
      WidgetStyle.samsungOneUi => 0.3,
      _ => 0.5,
    };
    await setOpacity(0.70);
    await setButtonSize(44);
    await setButtonCornerRadius(radius);
    await setButtonGap(10);
    await setVolumeStep(1);
    await setHapticFeedback(false);
  }

  static Future<void> restoreAudioDefaults() async {
    await setAudioStream(AudioStream.media);
    await setShowAudioMixer(true);
    await setAutoPeekEnabled(true);
    await setAutoPeekDelay(1800);
    await setPeekSize(16);
  }

  static Future<void> restoreIndicatorDefaults() async {
    await setShowIndicatorNumber(true);
    await setShowIndicatorIcon(true);
    await setIndicatorOpacity(0.85);
    await setIndicatorHeight(135);
    await setIndicatorWidth(36);
    await setIndicatorGap(10);
    await setIndicatorHideDelay(1800);
    await setIndicatorAnimation('fade');
  }

  static Future<void> restoreCreativeDefaults() async {
    await setCreativeAnimSpeed(1.0);
    await setCreativeGlowIntensity(1.0);
  }

  // Helper method for factory reset matching a given style.
  static Future<void> restoreDefaultsForStyle(WidgetStyle s) async {
    int _w = 36, _h = 135, _bg = 10, _bs = 44, _delay = 1800;
    double _r = 0.5;

    // Adjust specific constants based on styles.
    switch (s) {
      case WidgetStyle.miui:
        _r = 0.2; // rounded square
        break;
      case WidgetStyle.samsungOneUi:
        _r = 0.3;
        break;
      default:
        _r = 0.5; // perfect circle
        break;
    }

    await setOpacity(0.70);
    await restoreButtonsDefaults();
    await setButtonSize(_bs);
    await setButtonCornerRadius(_r);
    await setButtonGap(_bg);
    await restoreAudioDefaults();
    await restoreIndicatorDefaults();
    await setIndicatorHeight(_h);
    await setIndicatorWidth(_w);
    await setIndicatorGap(10);
    await setIndicatorHideDelay(_delay);
    await restoreCreativeDefaults();
  }
}
