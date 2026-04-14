import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages AdMob rewarded ads and the 3-day unlock state for special styles.
///
/// ⚠️  Before publishing, replace the test IDs:
///   • AdMob App ID   → android/app/src/main/AndroidManifest.xml
///   • _rewardedAdId  → replace the string below
class AdService {
  AdService._();

  // TODO: Replace with your real rewarded ad unit ID from AdMob console
  static const String _rewardedAdId =
      'ca-app-pub-3940256099942544/5224354917'; // Google test ID

  static const String _prefKey = 'special_unlock_expiry';
  static const Duration _unlockDuration = Duration(days: 3);

  static RewardedAd? _ad;
  static bool _loading = false;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Call once at app start. Requests GDPR/CCPA consent then inits AdMob.
  static Future<void> initialize() async {
    await _initConsent();
    await MobileAds.instance.initialize();
    _preload(); // fire-and-forget preload
  }

  // ── Unlock state ──────────────────────────────────────────────────────────

  static Future<bool> isUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryMs = prefs.getInt(_prefKey) ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(expiryMs).isAfter(DateTime.now());
  }

  /// Returns human-readable time left, e.g. "2 días" or "14 horas". Null if expired.
  static Future<String?> timeLeftLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryMs = prefs.getInt(_prefKey) ?? 0;
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
    if (!expiry.isAfter(DateTime.now())) return null;
    final diff = expiry.difference(DateTime.now());
    if (diff.inHours >= 48) return '${diff.inDays} días';
    if (diff.inHours >= 1) return '${diff.inHours} horas';
    return '${diff.inMinutes} min';
  }

  static Future<void> _grantUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _prefKey,
      DateTime.now().add(_unlockDuration).millisecondsSinceEpoch,
    );
  }

  // ── Ad display ────────────────────────────────────────────────────────────

  /// Shows the rewarded ad. Calls [onRewarded] after the user earns the reward.
  /// Returns false if no ad could be loaded/shown.
  static Future<bool> showAd({required VoidCallback onRewarded}) async {
    if (_ad == null) {
      await _preload();
      // Give the load a moment
      for (var i = 0; i < 5 && _ad == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    if (_ad == null) return false;

    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        _preload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _ad = null;
      },
    );

    _ad!.show(
      onUserEarnedReward: (_, __) async {
        await _grantUnlock();
        onRewarded();
      },
    );
    _ad = null;
    return true;
  }

  // ── Private ───────────────────────────────────────────────────────────────

  static Future<void> _preload() async {
    if (_ad != null || _loading) return;
    _loading = true;
    try {
      await RewardedAd.load(
        adUnitId: _rewardedAdId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) { _ad = ad; _loading = false; },
          onAdFailedToLoad: (_) { _ad = null; _loading = false; },
        ),
      );
    } catch (_) {
      _loading = false;
    }
  }

  /// GDPR/CCPA consent via Google UMP SDK.
  static Future<void> _initConsent() async {
    try {
      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            if (await ConsentInformation.instance.isConsentFormAvailable()) {
              await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
            }
          } catch (_) {}
          if (!done.isCompleted) done.complete();
        },
        (_) { if (!done.isCompleted) done.complete(); },
      );
      await done.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    } catch (_) {}
  }
}
