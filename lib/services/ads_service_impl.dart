import 'package:flutter/material.dart';

import 'package:arrow_drift/services/ad_slot.dart';
import 'package:arrow_drift/services/ads_service.dart';
import 'package:arrow_drift/services/fullscreen_ad_space.dart';

/// Banner placeholders + fullscreen ad spaces (hint / lives / every 5 levels).
class AdsServiceImpl implements AdsService {
  AdsServiceImpl._();
  static final AdsServiceImpl instance = AdsServiceImpl._();

  int _clearsSinceInterstitial = 0;

  static const Duration _rewardedDuration = Duration(seconds: 18);
  static const Duration _interstitialDuration = Duration(seconds: 12);

  @override
  Future<void> initialize() async {}

  @override
  Widget bannerPlaceholder({required double height}) {
    return AdSlot(
      height: height,
      label: 'Sponsored · Arrow Drift',
    );
  }

  @override
  Widget nativeAdPlaceholder({required double height}) {
    return AdSlot(
      height: height,
      label: 'Sponsored · Arrow Drift',
    );
  }

  @override
  Future<void> showInterstitial(
    BuildContext context, {
    Duration duration = _interstitialDuration,
  }) async {
    if (!context.mounted) return;
    await showFullscreenAdSpace(
      context,
      duration: duration,
      title: 'Quick break',
      subtitle: 'Ad space · continue after the timer',
    );
  }

  @override
  Future<bool> showRewardedForHint(BuildContext context) async {
    if (!context.mounted) return false;
    return showFullscreenAdSpace(
      context,
      duration: _rewardedDuration,
      title: 'Watch to unlock hints',
      subtitle: 'Ad space · earn +2 hints after this',
    );
  }

  @override
  Future<bool> showRewardedForLives(BuildContext context) async {
    if (!context.mounted) return false;
    return showFullscreenAdSpace(
      context,
      duration: _rewardedDuration,
      title: 'Watch to get +1 life',
      subtitle: 'Ad space · keep playing after this',
    );
  }

  @override
  Future<void> onLevelCleared(BuildContext context) async {
    _clearsSinceInterstitial++;
    if (_clearsSinceInterstitial < 5) return;
    _clearsSinceInterstitial = 0;
    if (!context.mounted) return;
    await showInterstitial(context);
  }

  @override
  Future<void> onDailyChallengeCleared(BuildContext context) async {
    if (!context.mounted) return;
    await showInterstitial(context);
  }

  @override
  Future<void> onReturnToMapAfterFail(BuildContext context) async {}
}
