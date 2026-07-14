import 'package:flutter/material.dart';

import 'package:arrow_drift/services/ad_slot.dart';
import 'package:arrow_drift/services/ads_service.dart';
import 'package:arrow_drift/services/dummy_fullscreen_ad.dart';

/// Dummy ads — banners + timed fullscreen overlays for demo builds.
class AdsServiceImpl implements AdsService {
  AdsServiceImpl._();
  static final AdsServiceImpl instance = AdsServiceImpl._();

  int _clearsSinceInterstitial = 0;

  static const _interstitialDuration = Duration(seconds: 10);
  static const _dailyInterstitialDuration = Duration(seconds: 15);
  static const _rewardedDuration = Duration(seconds: 15);

  @override
  Future<void> initialize() async {}

  @override
  Widget bannerPlaceholder({required double height}) {
    return AdSlot(height: height, label: 'Sponsored · Arrow Drift');
  }

  @override
  Widget nativeAdPlaceholder({required double height}) {
    return AdSlot(height: height, label: 'Sponsored · Demo ad');
  }

  @override
  Future<void> showInterstitial(
    BuildContext context, {
    Duration duration = const Duration(seconds: 10),
  }) async {
    if (!context.mounted) return;
    await showDummyFullscreenAd(
      context,
      duration: duration,
      title: 'Advertisement',
      subtitle: 'Full-screen demo ad',
    );
  }

  @override
  Future<bool> showRewardedForHint(BuildContext context) async {
    if (!context.mounted) return false;
    return showDummyFullscreenAd(
      context,
      duration: _rewardedDuration,
      title: 'Watch to unlock a hint',
      subtitle: 'Demo rewarded ad · +1 hint',
    );
  }

  @override
  Future<bool> showRewardedForLives(BuildContext context) async {
    if (!context.mounted) return false;
    return showDummyFullscreenAd(
      context,
      duration: _rewardedDuration,
      title: 'Watch to get +1 life',
      subtitle: 'Demo rewarded ad · continue playing',
    );
  }

  @override
  Future<void> onLevelCleared(BuildContext context) async {
    _clearsSinceInterstitial++;
    if (_clearsSinceInterstitial < 4) return;
    _clearsSinceInterstitial = 0;
    if (!context.mounted) return;
    await showInterstitial(context, duration: _interstitialDuration);
  }

  @override
  Future<void> onDailyChallengeCleared(BuildContext context) async {
    if (!context.mounted) return;
    await showDummyFullscreenAd(
      context,
      duration: _dailyInterstitialDuration,
      title: 'Advertisement',
      subtitle: 'Daily challenge · 15s demo ad',
    );
  }

  @override
  Future<void> onReturnToMapAfterFail(BuildContext context) async {
    // Keep quit path light — no forced long ad on fail.
  }
}
