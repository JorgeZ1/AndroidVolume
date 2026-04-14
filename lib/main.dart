import 'dart:async';
import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(AdService.initialize());
  runApp(const FloatingVolumeApp());
}
