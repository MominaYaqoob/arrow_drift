import 'package:flutter/material.dart';

import 'package:arrow_drift/services/ads_service_impl.dart';

/// Flip to `true` after plugging in a real ad SDK (AdMob / Unity Ads).
/// While `false`, placeholders reserve layout space and ad calls stay no-op.
const bool kAdsEnabled = false;

/// App-wide ads façade. Swap [AdsServiceImpl] internals later — call sites stay.
abstract class AdsService {
  static AdsService get instance => AdsServiceImpl.instance;

  /// SDK init. No-op until a real network is wired.
  Future<void> initialize();

  /// Reserved banner slot (fixed [height]) — layout stays stable when ads go live.
  Widget bannerPlaceholder({required double height});

  /// Full-screen interstitial. No-op while [kAdsEnabled] is false.
  Future<void> showInterstitial();

  /// Rewarded ad for an extra hint when the player is out of hints.
  /// Returns `true` when the player earned the reward.
  /// While [kAdsEnabled] is false, returns `true` so the UX path can be tested.
  Future<bool> showRewardedForHint();

  /// In-feed / native slot (fixed [height]) for level-map lists.
  Widget nativeAdPlaceholder({required double height});

  /// Call after a campaign level clear. Shows interstitial every 2nd clear.
  Future<void> onLevelCleared();

  /// Call when leaving gameplay for the map after a fail (out of lives).
  Future<void> onReturnToMapAfterFail();
}
