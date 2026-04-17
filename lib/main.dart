import 'package:flutter/material.dart';
import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // AdService.initialize() — disabled until real AdMob IDs are configured.
  // Re-enable after replacing test IDs in AndroidManifest.xml and ad_service.dart.
  runApp(const FloatingVolumeApp());
}
