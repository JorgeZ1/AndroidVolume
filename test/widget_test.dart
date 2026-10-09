import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floating_volume/src/screens/privacy_policy_screen.dart';
import 'package:floating_volume/src/app_language.dart';
import 'package:floating_volume/src/widget_settings.dart';
import 'package:floating_volume/src/services/ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => LanguageSettings.selection.value = AppLanguage.english);

  test('audio streams expose stable user-facing labels', () {
    expect(AudioStream.media.label, 'Media');
    expect(AudioStream.ring.label, 'Ringtone');
    expect(AudioStream.notification.label, 'Notifications');
    expect(AudioStream.alarm.label, 'Alarm');
    expect(AudioStream.system.label, 'System');
    expect(AudioStream.voiceCall.label, 'Voice call');
    expect(AudioStream.values, hasLength(6));
  });

  test('every style has a usable corner default', () {
    for (final style in WidgetStyle.values) {
      final radius = WidgetSettings.defaultCornerRadius(style);
      expect(radius, inInclusiveRange(0.0, 0.5));
      if (style == WidgetStyle.miui || style == WidgetStyle.samsungOneUi) {
        expect(radius, lessThan(0.5));
      } else {
        expect(radius, 0.5);
      }
    }
  });

  test('corner slider runs from round to square and converts both ways', () {
    expect(WidgetSettings.cornerSliderPosition(0.5), 0.0);
    expect(WidgetSettings.cornerSliderPosition(0.0), 0.5);
    expect(WidgetSettings.cornerSliderPosition(0.2), closeTo(0.3, 0.0001));
    expect(
      WidgetSettings.cornerSliderPosition(
        WidgetSettings.cornerSliderPosition(0.2),
      ),
      closeTo(0.2, 0.0001),
    );
  });

  testWidgets('in-app privacy policy is presented in English', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('1. Overview'), findsOneWidget);
    expect(
      find.textContaining('Last updated: October 9, 2026'),
      findsOneWidget,
    );
  });

  testWidgets('Spanish privacy policy is presented when selected', (
    tester,
  ) async {
    LanguageSettings.selection.value = AppLanguage.spanish;
    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));
    expect(find.text('Política de Privacidad'), findsOneWidget);
    expect(find.text('1. Información general'), findsOneWidget);
  });

  test('manual language selection persists across reloads', () async {
    SharedPreferences.setMockInitialValues({});
    await LanguageSettings.set(AppLanguage.spanish);
    LanguageSettings.selection.value = AppLanguage.system;
    await LanguageSettings.load();
    expect(LanguageSettings.selection.value, AppLanguage.spanish);
    expect(AudioStream.media.label, 'Multimedia');
  });

  testWidgets('system default follows the device language', (tester) async {
    LanguageSettings.selection.value = AppLanguage.system;
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('es', 'MX'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    expect(LanguageSettings.isSpanish, isTrue);
    expect(AudioStream.ring.label, 'Tono de llamada');
  });

  test('reward countdown communicates 72 hours and accumulated time', () {
    expect(AdService.rewardDuration, const Duration(hours: 72));
    expect(AdService.formatTimeLeft(const Duration(hours: 72)), '3 d');
    expect(AdService.formatTimeLeft(const Duration(hours: 144)), '6 d');
    expect(AdService.formatTimeLeft(const Duration(hours: 18)), '18 h');
    expect(AdService.formatTimeLeft(const Duration(minutes: 35)), '35 min');
    expect(
      AdService.formatCompactTimeLeft(const Duration(hours: 71, minutes: 30)),
      '3d',
    );
    expect(
      AdService.formatCompactTimeLeft(const Duration(hours: 23, minutes: 20)),
      '23h',
    );
    expect(AdService.formatCompactTimeLeft(const Duration(minutes: 35)), '35m');
  });

  test('each rewarded ad adds 72 hours after the active expiry', () {
    final now = DateTime(2026, 9, 23, 12);
    final existingExpiry = now.add(const Duration(hours: 18));

    expect(
      AdService.nextRewardExpiry(existingExpiry, now),
      now.add(const Duration(hours: 90)),
    );
    expect(
      AdService.nextRewardExpiry(now.subtract(const Duration(hours: 1)), now),
      now.add(const Duration(hours: 72)),
    );
    final featuredExpiry = now.add(const Duration(hours: 72));
    expect(
      AdService.nextRewardExpiry(now, now, featuredExpiry: featuredExpiry),
      featuredExpiry.add(const Duration(hours: 72)),
    );
  });

  test(
    'current featured free access counts as an active style unlock',
    () async {
      final now = DateTime.now();
      final expiry = now.add(const Duration(hours: 72));
      SharedPreferences.setMockInitialValues({
        AdService.featuredStylePrefKey: 'rgbNeon',
        AdService.featuredExpiryPrefKey: expiry.millisecondsSinceEpoch,
      });

      expect(await AdService.isUnlocked('rgbNeon'), isTrue);
      expect(
        await AdService.unlockExpiry('rgbNeon'),
        DateTime.fromMillisecondsSinceEpoch(expiry.millisecondsSinceEpoch),
      );
      expect(await AdService.isUnlocked('rgbAurora'), isFalse);
    },
  );

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

  test('featured special style persists for its 72-hour cycle', () async {
    SharedPreferences.setMockInitialValues({});
    final start = DateTime(2026, 9, 23, 12);
    const styles = ['rgbAurora', 'rgbNeon', 'cosmic'];

    final featured = await AdService.getFeaturedSpecialStyle(
      styles,
      now: start,
      random: Random(4),
    );
    final sameCycle = await AdService.getFeaturedSpecialStyle(
      styles,
      now: start.add(const Duration(hours: 48)),
      random: Random(8),
    );

    expect(styles, contains(featured.styleKey));
    expect(featured.expiresAt, start.add(const Duration(hours: 72)));
    expect(sameCycle.styleKey, featured.styleKey);
    expect(sameCycle.expiresAt, featured.expiresAt);
  });

  test(
    'featured style rotates after expiry and avoids immediate repeat',
    () async {
      SharedPreferences.setMockInitialValues({});
      final start = DateTime(2026, 9, 23, 12);
      const styles = ['rgbAurora', 'rgbNeon', 'cosmic'];
      final first = await AdService.getFeaturedSpecialStyle(
        styles,
        now: start,
        random: Random(4),
      );
      final nextCycleStart = first.expiresAt.add(const Duration(seconds: 1));

      final next = await AdService.getFeaturedSpecialStyle(
        styles,
        now: nextCycleStart,
        random: Random(2),
      );

      expect(next.styleKey, isNot(first.styleKey));
      expect(styles, contains(next.styleKey));
      expect(next.expiresAt, nextCycleStart.add(const Duration(hours: 72)));
    },
  );
}
