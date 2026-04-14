import 'package:flutter/services.dart';

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
}
