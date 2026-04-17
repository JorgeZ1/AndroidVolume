import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WidgetColorMode { auto, blue, dark }

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
}

class WidgetSettings {
  WidgetSettings._();

  static const _ch = MethodChannel('floating_volume/settings');

  static double opacity = 1.0;
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

  static int buttonSize = 52;
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

  static double indicatorOpacity = 1.0;
  static Future<void> setIndicatorOpacity(double value) async {
    indicatorOpacity = value;
    await _ch.invokeMethod('setIndicatorOpacity', {'value': value});
  }

  static int indicatorHeight = 160;
  static Future<void> setIndicatorHeight(int value) async {
    indicatorHeight = value;
    await _ch.invokeMethod('setIndicatorHeight', {'value': value});
  }

  static int indicatorWidth = 48;
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

  // Helper method for factory reset matching a given style.
  static Future<void> restoreDefaultsForStyle(WidgetStyle s) async {
    int _w = 48, _h = 160, _bg = 10, _bs = 52, _delay = 1800;
    double _r = 0.5;

    // Adjust specific constants based on styles.
    switch (s) {
      case WidgetStyle.miui:
        _r = 0.2; // rounded square
        break;
      case WidgetStyle.samsungOneUi:
        _r = 0.3;
        break;
      case WidgetStyle.android12:
      case WidgetStyle.ios:
      case WidgetStyle.android:
      case WidgetStyle.rgbAurora:
      case WidgetStyle.rgbNeon:
      case WidgetStyle.cosmic:
      case WidgetStyle.lava:
      default:
        _r = 0.5; // perfect circle
        break;
    }

    await setOpacity(1.0);
    await setIndicatorOpacity(1.0);
    await setButtonSize(_bs);
    await setButtonCornerRadius(_r);
    await setButtonGap(_bg);
    await setIndicatorHeight(_h);
    await setIndicatorWidth(_w);
    await setIndicatorGap(10);
    await setIndicatorHideDelay(_delay);
    await setIndicatorAnimation("fade");
  }
}
