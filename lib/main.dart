import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/app_language.dart';
import 'src/services/monitoring_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MonitoringService.initialize();
  await LanguageSettings.load();
  runApp(const FloatingVolumeApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    MonitoringService.firstFrame();
  });
}
