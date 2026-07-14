import 'package:flutter/material.dart';

import 'package:arrow_drift/services/ads_service_impl.dart';

/// App-wide ads façade. Dummy timed ads for demo; swap impl for real AdMob later.
abstract class AdsService {
  static AdsService get instance => AdsServiceImpl.instance;

  Future<void> initialize();

  /// Banner / strip dummy slot (layout reserved).
  Widget bannerPlaceholder({required double height});

  /// Native / feed dummy slot.
  Widget nativeAdPlaceholder({required double height});

  /// Full-screen interstitial (dummy timed).
  Future<void> showInterstitial(
    BuildContext context, {
    Duration duration = const Duration(seconds: 10),
  });

  /// Rewarded for extra hint when hints are 0 (15s dummy).
  Future<bool> showRewardedForHint(BuildContext context);

  /// Rewarded for +1 life (15s dummy).
  Future<bool> showRewardedForLives(BuildContext context);

  /// After campaign clear — interstitial every 4 clears (10s).
  Future<void> onLevelCleared(BuildContext context);

  /// After daily challenge clear — interstitial every time (15s).
  Future<void> onDailyChallengeCleared(BuildContext context);

  /// Leaving gameplay after a fail.
  Future<void> onReturnToMapAfterFail(BuildContext context);
}
