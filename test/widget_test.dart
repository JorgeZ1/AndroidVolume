import 'package:flutter_test/flutter_test.dart';
import 'package:floating_volume/src/widget_settings.dart';
import 'package:floating_volume/src/services/ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('audio streams expose stable user-facing labels', () {
    expect(AudioStream.media.label, 'Multimedia');
    expect(AudioStream.notification.label, 'Notificaciones');
    expect(AudioStream.values, hasLength(6));
  });

  test('reward countdown communicates 24 hours and accumulated time', () {
    expect(AdService.formatTimeLeft(const Duration(hours: 24)), '24 h');
    expect(AdService.formatTimeLeft(const Duration(hours: 48)), '2 d');
    expect(AdService.formatTimeLeft(const Duration(hours: 18)), '18 h');
    expect(AdService.formatTimeLeft(const Duration(minutes: 35)), '35 min');
  });

  test('special-style unlocks are independent', () async {
    final future = DateTime.now().add(const Duration(hours: 24));
    SharedPreferences.setMockInitialValues({
      'special_unlock_rgbAurora_expiry': future.millisecondsSinceEpoch,
    });

    expect(await AdService.isUnlocked('rgbAurora'), isTrue);
    expect(await AdService.isUnlocked('rgbNeon'), isFalse);
  });

  test('legacy global reward remains valid during migration', () async {
    final future = DateTime.now().add(const Duration(hours: 2));
    SharedPreferences.setMockInitialValues({
      'special_unlock_expiry': future.millisecondsSinceEpoch,
    });

    expect(await AdService.isUnlocked('rgbAurora'), isTrue);
    expect(await AdService.isUnlocked('retrowave'), isTrue);
  });
}
