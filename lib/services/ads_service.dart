import 'package:flutter/material.dart';

import 'package:arrow_drift/services/ads_service_impl.dart';

/// Native template size: small strip vs standard (medium) card.
enum NativeAdFormat { small, medium }

/// App-wide ads façade — native slots + fullscreen ad spaces.
abstract class AdsService {
  static AdsService get instance => AdsServiceImpl.instance;

  Future<void> initialize();

  /// Banner / strip ad slot (kept for callers that still need a strip).
  Widget bannerPlaceholder({required double height});

  /// Native ad slot — [NativeAdFormat.small] on Home, medium on Me.
  Widget nativeAdPlaceholder({
    required double height,
    NativeAdFormat format = NativeAdFormat.small,
  });

  /// One App Open ad after splash (skips quietly if none is ready).
  Future<void> showAppOpenIfReady();

  /// Full-screen interstitial ad space.
  Future<void> showInterstitial(
    BuildContext context, {
    Duration duration = const Duration(seconds: 12),
  });

  /// Rewarded ad space for extra hint when hints are 0 (~15–20s).
  Future<bool> showRewardedForHint(BuildContext context);

  /// Rewarded ad space for +1 life (~15–20s).
  Future<bool> showRewardedForLives(BuildContext context);

  /// After campaign clear — interstitial every 5 clears.
  Future<void> onLevelCleared(BuildContext context);

  /// After daily challenge clear — no ads on Daily.
  Future<void> onDailyChallengeCleared(BuildContext context);

  /// Leaving gameplay after a fail.
  Future<void> onReturnToMapAfterFail(BuildContext context);
}
