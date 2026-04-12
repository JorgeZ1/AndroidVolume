import 'package:flutter/services.dart';

enum WidgetColorMode { auto, blue, dark }

class WidgetSettings {
  WidgetSettings._();

  static const _ch = MethodChannel('floating_volume/settings');

  static double opacity = 1.0;
  static WidgetColorMode colorMode = WidgetColorMode.auto;

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
}
