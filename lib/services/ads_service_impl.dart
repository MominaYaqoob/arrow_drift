import 'package:flutter/material.dart';

import 'package:arrow_drift/services/ad_slot.dart';
import 'package:arrow_drift/services/ads_service.dart';

/// Placeholder ads implementation — reserves layout, no network calls.
class AdsServiceImpl implements AdsService {
  AdsServiceImpl._();
  static final AdsServiceImpl instance = AdsServiceImpl._();

  int _clearsSinceInterstitial = 0;

  @override
  Future<void> initialize() async {
    // Wire AdMob / Unity Ads here later when [kAdsEnabled] is true.
  }

  @override
  Widget bannerPlaceholder({required double height}) {
    return AdSlot(height: height);
  }

  @override
  Widget nativeAdPlaceholder({required double height}) {
    return AdSlot(height: height, label: 'Ad space');
  }

  @override
  Future<void> showInterstitial() async {
    if (!kAdsEnabled) return;
    // TODO: show real interstitial
  }

  @override
  Future<bool> showRewardedForHint() async {
    if (!kAdsEnabled) return true;
    // TODO: show rewarded; return whether reward was earned
    return true;
  }

  @override
  Future<void> onLevelCleared() async {
    _clearsSinceInterstitial++;
    if (_clearsSinceInterstitial >= 2) {
      _clearsSinceInterstitial = 0;
      await showInterstitial();
    }
  }

  @override
  Future<void> onReturnToMapAfterFail() async {
    await showInterstitial();
  }
}
