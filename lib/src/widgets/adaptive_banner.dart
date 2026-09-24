import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:floating_volume/src/services/ad_service.dart';

/// An anchored adaptive banner shown only while the main app screen is open.
class AdaptiveBanner extends StatefulWidget {
  const AdaptiveBanner({super.key});

  @override
  State<AdaptiveBanner> createState() => _AdaptiveBannerState();
}

class _AdaptiveBannerState extends State<AdaptiveBanner>
    with WidgetsBindingObserver {
  BannerAd? _banner;
  Orientation? _orientation;
  int? _width;
  bool _loaded = false;
  bool _isForeground = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    final width = media.size.width.truncate();
    if (_width != width || _orientation != media.orientation) {
      _width = width;
      _orientation = media.orientation;
      _load(width);
    }
  }

  Future<void> _load(int width) async {
    if (!Platform.isAndroid || !AdService.bannerAdsEnabled || !_isForeground) {
      return;
    }
    final generation = ++_loadGeneration;

    final previous = _banner;
    _banner = null;
    _loaded = false;
    await previous?.dispose();
    if (!_isCurrent(generation)) return;

    final canRequestAds = await AdService.initialize();
    if (!_isCurrent(generation) || !canRequestAds) {
      return;
    }

    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!_isCurrent(generation) || size == null) {
      return;
    }

    late final BannerAd banner;
    banner = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!_isCurrent(generation) || !identical(_banner, ad)) {
            ad.dispose();
            return;
          }
          setState(() {
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Adaptive banner failed to load: $error');
          ad.dispose();
          if (_isCurrent(generation) && identical(_banner, ad)) {
            setState(() {
              _banner = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    _banner = banner;
    await banner.load();
  }

  bool _isCurrent(int generation) =>
      mounted && _isForeground && generation == _loadGeneration;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      final width = _width;
      if (width != null) _load(width);
      return;
    }

    _isForeground = false;
    _loadGeneration++;
    _loaded = false;
    final banner = _banner;
    _banner = null;
    banner?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (!_loaded || banner == null) return const SizedBox.shrink();

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: banner.size.height.toDouble(),
          child: Center(
            child: SizedBox(
              width: banner.size.width.toDouble(),
              height: banner.size.height.toDouble(),
              child: AdWidget(ad: banner),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadGeneration++;
    _banner?.dispose();
    super.dispose();
  }
}
