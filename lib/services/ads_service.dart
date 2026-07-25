import 'package:flutter/material.dart';

import 'package:arrow_drift/services/ads_service_impl.dart';

/// App-wide ads façade — banner slots + fullscreen ad spaces.
abstract class AdsService {
  static AdsService get instance => AdsServiceImpl.instance;

  Future<void> initialize();

  /// Banner / strip ad slot.
  Widget bannerPlaceholder({required double height});

  /// Secondary banner/native slot.
  Widget nativeAdPlaceholder({required double height});

  /// Full-screen interstitial ad space.
  Future<void> showInterstitial(
    BuildContext context, {
    Duration duration = const Duration(seconds: 12),
  });

  /// Rewarded ad space for extra hint when hints are 0 (~15–20s).
  Future<bool> showRewardedForHint(BuildContext context);

  /// Rewarded ad space for +1 life (~15–20s).
  Future<bool> showRewardedForLives(BuildContext context);

  /// After campaign clear — interstitial every 4 clears.
  Future<void> onLevelCleared(BuildContext context);

  /// After daily challenge clear — interstitial.
  Future<void> onDailyChallengeCleared(BuildContext context);

  /// Leaving gameplay after a fail.
  Future<void> onReturnToMapAfterFail(BuildContext context);
}
