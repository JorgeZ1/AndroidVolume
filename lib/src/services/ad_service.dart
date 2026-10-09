import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'monitoring_service.dart';

/// Manages consent, AdMob initialization, ads, and the temporary unlock state.
class AdService {
  AdService._();

  static const bool bannerAdsEnabled = true;
  static const bool _rewardedAdsEnabled = true;

  static const String _bannerAdId = 'ca-app-pub-2031775178741332/7918737592';
  static const String _bannerTestAdId =
      'ca-app-pub-3940256099942544/9214589741';

  /// Debug builds must never generate impressions on the production unit.
  static String get bannerAdUnitId =>
      kDebugMode ? _bannerTestAdId : _bannerAdId;

  static const String _rewardedAdId = 'ca-app-pub-2031775178741332/6475250253';
  static const String _rewardedTestAdId =
      'ca-app-pub-3940256099942544/5224354917';

  static String get _rewardedAdUnitId =>
      kDebugMode ? _rewardedTestAdId : _rewardedAdId;

  static const String _legacyPrefKey = 'special_unlock_expiry';
  static const String _stylePrefPrefix = 'special_unlock_';
  static const String featuredStylePrefKey = 'special_featured_style';
  static const String featuredExpiryPrefKey = 'special_featured_expiry';
  static const Duration rewardDuration = Duration(hours: 72);

  static RewardedAd? _ad;
  static bool _loading = false;
  static Future<bool>? _initialization;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Initializes consent and ads. Failed attempts are not cached so ads can
  /// recover after the device reconnects without restarting the app.
  static Future<bool> initialize() {
    final current = _initialization;
    if (current != null) return current;

    late final Future<bool> attempt;
    attempt = _initialize().then(
      (initialized) {
        if (!initialized && identical(_initialization, attempt)) {
          _initialization = null;
        }
        return initialized;
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_initialization, attempt)) _initialization = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    _initialization = attempt;
    return attempt;
  }

  static Future<bool> _initialize() async {
    await _initConsent();
    if (!await ConsentInformation.instance.canRequestAds()) return false;
    await MobileAds.instance.initialize();
    if (_rewardedAdsEnabled) _preload();
    return true;
  }

  static Future<bool> privacyOptionsRequired() async {
    await initialize();
    return await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  static Future<FormError?> showPrivacyOptions() async {
    FormError? result;
    await ConsentForm.showPrivacyOptionsForm((error) => result = error);
    return result;
  }

  // ── Unlock state ──────────────────────────────────────────────────────────

  static String _stylePrefKey(String styleKey) =>
      '$_stylePrefPrefix${styleKey}_expiry';

  static DateTime _expiryFrom(SharedPreferences prefs, String key) =>
      DateTime.fromMillisecondsSinceEpoch(prefs.getInt(key) ?? 0);

  /// A still-active legacy 72-hour reward continues to unlock every style.
  /// New rewards are stored independently per style.
  static Future<bool> isUnlocked(String styleKey) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    return _effectiveExpiry(prefs, styleKey).isAfter(now);
  }

  static DateTime _effectiveExpiry(SharedPreferences prefs, String styleKey) {
    final legacy = _expiryFrom(prefs, _legacyPrefKey);
    final individual = _expiryFrom(prefs, _stylePrefKey(styleKey));
    final featured =
        prefs.getString(featuredStylePrefKey) == styleKey
            ? _expiryFrom(prefs, featuredExpiryPrefKey)
            : DateTime.fromMillisecondsSinceEpoch(0);
    return [
      legacy,
      individual,
      featured,
    ].reduce((latest, expiry) => expiry.isAfter(latest) ? expiry : latest);
  }

  /// Returns the persisted free style for the current 72-hour cycle, creating
  /// a new random one when the previous cycle has expired.
  static Future<FeaturedSpecialStyle> getFeaturedSpecialStyle(
    List<String> availableStyleKeys, {
    DateTime? now,
    Random? random,
  }) async {
    if (availableStyleKeys.isEmpty) {
      throw ArgumentError.value(
        availableStyleKeys,
        'availableStyleKeys',
        'At least one special style is required.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final currentTime = now ?? DateTime.now();
    final currentKey = prefs.getString(featuredStylePrefKey);
    final currentExpiry = _expiryFrom(prefs, featuredExpiryPrefKey);
    if (currentKey != null &&
        availableStyleKeys.contains(currentKey) &&
        currentExpiry.isAfter(currentTime)) {
      return FeaturedSpecialStyle(currentKey, currentExpiry);
    }

    final previousKey = currentKey;
    final candidates =
        availableStyleKeys.length > 1
            ? availableStyleKeys.where((key) => key != previousKey).toList()
            : availableStyleKeys;
    final chooser = random ?? Random.secure();
    final selected = candidates[chooser.nextInt(candidates.length)];
    final expiresAt = currentTime.add(rewardDuration);
    await prefs.setString(featuredStylePrefKey, selected);
    await prefs.setInt(featuredExpiryPrefKey, expiresAt.millisecondsSinceEpoch);
    return FeaturedSpecialStyle(selected, expiresAt);
  }

  static Future<String?> timeLeftLabel(String styleKey) async {
    final expiry = await unlockExpiry(styleKey);
    if (expiry == null) return null;
    return formatTimeLeft(expiry.difference(DateTime.now()));
  }

  /// Effective access expiry, including the current free featured cycle.
  static Future<DateTime?> unlockExpiry(String styleKey) async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = _effectiveExpiry(prefs, styleKey);
    return expiry.isAfter(DateTime.now()) ? expiry : null;
  }

  static String formatTimeLeft(Duration diff) {
    final remainingMinutes = (diff.inSeconds / 60).ceil();

    if (remainingMinutes == rewardDuration.inMinutes) {
      return '3 d';
    }

    if (remainingMinutes >= Duration.minutesPerDay) {
      final days = remainingMinutes ~/ Duration.minutesPerDay;
      final hours =
          (remainingMinutes % Duration.minutesPerDay) ~/
          Duration.minutesPerHour;
      if (hours == 0) return '$days d';
      return '$days d $hours h';
    }

    if (remainingMinutes >= Duration.minutesPerHour) {
      final hours = (remainingMinutes / Duration.minutesPerHour).ceil();
      return '$hours h';
    }

    return '$remainingMinutes min';
  }

  /// Compact countdown for small badges. Keep [formatTimeLeft] for accessible
  /// labels and places where the full day/hour breakdown is useful.
  static String formatCompactTimeLeft(Duration diff) {
    final remainingMinutes = (diff.inSeconds / 60).ceil();
    if (remainingMinutes <= 0) return '0m';
    if (remainingMinutes >= Duration.minutesPerDay) {
      final days = (remainingMinutes / Duration.minutesPerDay).ceil();
      return '${days}d';
    }
    if (remainingMinutes >= Duration.minutesPerHour) {
      final hours = remainingMinutes ~/ Duration.minutesPerHour;
      return '${hours}h';
    }
    return '${remainingMinutes}m';
  }

  @visibleForTesting
  static DateTime nextRewardExpiry(
    DateTime currentExpiry,
    DateTime now, {
    DateTime? featuredExpiry,
  }) {
    var start = currentExpiry.isAfter(now) ? currentExpiry : now;
    if (featuredExpiry != null && featuredExpiry.isAfter(start)) {
      start = featuredExpiry;
    }
    return start.add(rewardDuration);
  }

  static Future<void> _grantUnlock(String styleKey) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final effectiveExpiry = _effectiveExpiry(prefs, styleKey);
    await prefs.setInt(
      _stylePrefKey(styleKey),
      nextRewardExpiry(effectiveExpiry, now).millisecondsSinceEpoch,
    );
  }

  // ── Ad display ────────────────────────────────────────────────────────────

  /// Shows the rewarded ad. Calls [onRewarded] after the user earns the reward.
  /// Returns false if no ad could be loaded/shown.
  static Future<bool> showAd({
    required String styleKey,
    required VoidCallback onRewarded,
    VoidCallback? onClosedWithoutReward,
  }) async {
    if (!_rewardedAdsEnabled || !await initialize()) return false;
    if (_ad == null) {
      await _preload();
      // Give the load a moment
      for (var i = 0; i < 5 && _ad == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    if (_ad == null) return false;

    var rewardEarned = false;
    unawaited(MonitoringService.event('rewarded_requested'));
    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(
          MonitoringService.event(
            rewardEarned
                ? 'rewarded_closed_earned'
                : 'rewarded_closed_unearned',
          ),
        );
        ad.dispose();
        _ad = null;
        _preload();
        if (!rewardEarned) onClosedWithoutReward?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        unawaited(MonitoringService.event('rewarded_show_failed'));
        ad.dispose();
        _ad = null;
        _preload();
        onClosedWithoutReward?.call();
      },
    );

    _ad!.show(
      onUserEarnedReward: (_, __) async {
        rewardEarned = true;
        unawaited(MonitoringService.event('rewarded_earned'));
        await _grantUnlock(styleKey);
        onRewarded();
      },
    );
    _ad = null;
    return true;
  }

  // ── Private ───────────────────────────────────────────────────────────────

  static Future<void> _preload() async {
    if (!_rewardedAdsEnabled || _ad != null || _loading) return;
    _loading = true;
    try {
      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            _loading = false;
          },
          onAdFailedToLoad: (_) {
            _ad = null;
            _loading = false;
          },
        ),
      );
    } catch (_) {
      _loading = false;
    }
  }

  /// Regional privacy choices and consent through Google UMP SDK.
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
        (_) {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    } catch (_) {}
  }
}

class FeaturedSpecialStyle {
  const FeaturedSpecialStyle(this.styleKey, this.expiresAt);

  final String styleKey;
  final DateTime expiresAt;
}
