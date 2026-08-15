import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:arrow_drift/services/ads_service.dart';
import 'package:arrow_drift/services/banner_ad_widget.dart';
import 'package:arrow_drift/services/native_ad_widget.dart';
import 'package:arrow_drift/services/network_status.dart';

/// Real AdMob integration, wired through Google's official **test** ad unit
/// IDs (see https://developers.google.com/admob/flutter/test-ads). These
/// IDs are Google's own sample units — not tied to any AdMob account — so
/// they're always safe to ship during development and the Play Store
/// review / test window. **Swap every `_...AdUnitId` getter below for your
/// own AdMob ad unit ID before a real production release** (and swap the
/// app ID in AndroidManifest.xml too).
///
/// Android-only by design — this app does not ship on iOS, so there's no
/// `Platform.isIOS` branching or iOS ad unit IDs anywhere in here.
///
/// **Connectivity-gated for stability** (this is the part added after the
/// last crash): the SDK is only ever initialized if a network is present
/// at launch (checked by the caller — see splash_loading_screen.dart —
/// before calling [initialize]), and a live [NetworkStatus] subscription
/// keeps `_hasConnectivity` current for the rest of the session. Every
/// ad-triggering path below checks both `_initialized` and
/// `_hasConnectivity` before touching the SDK, so a connection dropping
/// mid-session (airplane mode, tunnel, etc.) makes ads quietly stop
/// showing — banners keep an empty reserved slot, interstitial/
/// rewarded calls just no-op — instead of throwing.
class AdsServiceImpl implements AdsService {
  AdsServiceImpl._();
  static final AdsServiceImpl instance = AdsServiceImpl._();

  bool _initialized = false;
  Future<void>? _initializing;
  bool _hasConnectivity = true;
  StreamSubscription<bool>? _connectivitySub;
  int _clearsSinceInterstitial = 0;

  InterstitialAd? _interstitialAd;
  bool _interstitialLoading = false;
  RewardedAd? _rewardedAd;
  bool _rewardedLoading = false;
  AppOpenAd? _appOpenAd;
  bool _appOpenLoading = false;
  Completer<void>? _appOpenLoadGate;
  bool _didShowAppOpen = false;

  static const Duration _interstitialDuration = Duration(seconds: 12);
  static const int _interstitialEveryNClears = 5;

  // --- Google's official Android test ad unit IDs ------------------------
  // https://developers.google.com/admob/flutter/test-ads
  static const String _bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _nativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _rewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _appOpenAdUnitId =
      'ca-app-pub-3940256099942544/9257395921';

  // Android-only app: gate strictly on Platform.isAndroid rather than
  // "any mobile platform" so nothing here ever attempts an iOS ad request.
  bool get _adsSupported => !kIsWeb && Platform.isAndroid;

  /// True once the SDK has initialized AND a network is currently present.
  /// This is what every ad-triggering method below actually checks.
  bool get _canServeAds => _initialized && _hasConnectivity;

  @override
  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    if (!_adsSupported) {
      debugPrint(
        'AdsService: skipped — AdMob only runs on Android '
        '(not Chrome / Windows / iOS). Use an Android emulator or phone.',
      );
      return;
    }

    // Connectivity gate #1: don't even attempt SDK init without a network.
    // The splash screen already checks this before calling initialize(),
    // but this second check makes the guarantee hold no matter who calls
    // initialize() (defense in depth, not trusting a single call site).
    final online = await NetworkStatus.instance.isOnline();
    if (!online) {
      debugPrint('AdsService: skipped — no internet at init time');
      _hasConnectivity = false;
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      _hasConnectivity = true;
      debugPrint('AdsService: MobileAds initialized');

      // Connectivity gate #2: keep tracking connectivity live for the rest
      // of the session, so a mid-session drop (not just "offline at
      // launch") also makes every method below back off gracefully.
      _connectivitySub?.cancel();
      _connectivitySub = NetworkStatus.instance.onChanged.listen((isOnline) {
        _hasConnectivity = isOnline;
        debugPrint('AdsService: connectivity changed → online=$isOnline');
      });

      // Preload App Open (splash), interstitial (every 5 clears), rewarded
      // (hint / lives) so the first trigger is not waiting on the network.
      unawaited(_loadAppOpen());
      unawaited(_loadInterstitial());
      unawaited(_loadRewarded());
    } catch (e) {
      // Ad SDK failing to initialize (no network, misconfigured app ID,
      // Play services missing, etc.) must never take the app down —
      // every other method below already checks `_canServeAds` and
      // degrades to a no-op / placeholder instead.
      debugPrint('AdsService: initialize failed: $e');
    }
  }

  // --- Banner / native slots -------------------------------------------

  @override
  Widget bannerPlaceholder({required double height}) {
    if (!_adsSupported || !_hasConnectivity) {
      // Keep layout space; never show fake Sponsored placeholder.
      return SizedBox(width: double.infinity, height: height);
    }
    // Always return the real banner widget — it awaits initialize() itself
    // so a slow / late SDK init (or hot reload that skipped main()) still
    // swaps in a live ad once ready. Empty slot until load / on failure.
    return BannerAdWidget(
      adUnitId: _bannerAdUnitId,
      height: height,
      ensureInitialized: initialize,
    );
  }

  @override
  Widget nativeAdPlaceholder({
    required double height,
    NativeAdFormat format = NativeAdFormat.small,
  }) {
    if (!_adsSupported || !_hasConnectivity) {
      return const SizedBox.shrink();
    }
    return NativeAdWidget(
      adUnitId: _nativeAdUnitId,
      height: height,
      format: format,
      ensureInitialized: initialize,
    );
  }

  // --- App Open (splash) -------------------------------------------------

  void _completeAppOpenGate() {
    final gate = _appOpenLoadGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  Future<void> _loadAppOpen() async {
    if (!_canServeAds || _appOpenLoading || _appOpenAd != null) {
      if (_appOpenAd != null) _completeAppOpenGate();
      return;
    }
    _appOpenLoading = true;
    _appOpenLoadGate ??= Completer<void>();
    try {
      await AppOpenAd.load(
        adUnitId: _appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpenLoading = false;
            _appOpenAd = ad;
            _completeAppOpenGate();
          },
          onAdFailedToLoad: (error) {
            _appOpenLoading = false;
            _appOpenAd = null;
            debugPrint(
              'AdsService: app open failed to load '
              '(code=${error.code}, message=${error.message})',
            );
            _completeAppOpenGate();
          },
        ),
      );
    } catch (e) {
      _appOpenLoading = false;
      _appOpenAd = null;
      debugPrint('AdsService: app open load threw: $e');
      _completeAppOpenGate();
    }
  }

  @override
  Future<void> showAppOpenIfReady() async {
    if (_didShowAppOpen) return;
    await initialize();
    if (!_canServeAds) return;

    if (_appOpenAd == null) {
      unawaited(_loadAppOpen());
      try {
        await (_appOpenLoadGate?.future ?? Future<void>.value()).timeout(
          const Duration(milliseconds: 1500),
        );
      } on TimeoutException {
        // Splash must not stall if the ad is slow — skip this session.
      }
    }

    final ad = _appOpenAd;
    if (ad == null) return;
    _appOpenAd = null;
    _didShowAppOpen = true;
    final completer = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (shown, error) {
        shown.dispose();
        debugPrint('AdsService: app open failed to show: $error');
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      await ad.show();
    } catch (e) {
      debugPrint('AdsService: app open show failed: $e');
      if (!completer.isCompleted) completer.complete();
    }

    try {
      await completer.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      debugPrint('AdsService: app open dismiss wait timed out');
    }
  }

  // --- Interstitial ------------------------------------------------------

  Future<void> _loadInterstitial() async {
    if (!_canServeAds || _interstitialLoading || _interstitialAd != null) {
      return;
    }
    _interstitialLoading = true;
    try {
      await InterstitialAd.load(
        adUnitId: _interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialLoading = false;
            _interstitialAd = ad;
          },
          onAdFailedToLoad: (error) {
            _interstitialLoading = false;
            _interstitialAd = null;
            debugPrint(
              'AdsService: interstitial failed to load '
              '(code=${error.code}, message=${error.message})',
            );
          },
        ),
      );
    } catch (e) {
      _interstitialLoading = false;
      _interstitialAd = null;
      debugPrint('AdsService: interstitial load threw: $e');
    }
  }

  @override
  Future<void> showInterstitial(
    BuildContext context, {
    Duration duration = _interstitialDuration,
  }) async {
    if (!context.mounted) return;
    if (!_canServeAds || _interstitialAd == null) {
      // No ad ready (or offline) — never block the player waiting for
      // one. Kick off a fresh load for next time (harmless no-op if
      // offline — _loadInterstitial re-checks _canServeAds) and move on.
      unawaited(_loadInterstitial());
      return;
    }

    final ad = _interstitialAd!;
    _interstitialAd = null; // an InterstitialAd can only be shown once
    final completer = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_loadInterstitial());
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        unawaited(_loadInterstitial());
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      await ad.show();
    } catch (e) {
      debugPrint('AdsService: interstitial show failed: $e');
      if (!completer.isCompleted) completer.complete();
    }
    return completer.future;
  }

  // --- Rewarded ------------------------------------------------------

  Future<void> _loadRewarded() async {
    if (!_canServeAds || _rewardedLoading || _rewardedAd != null) return;
    _rewardedLoading = true;
    try {
      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedLoading = false;
            _rewardedAd = ad;
          },
          onAdFailedToLoad: (error) {
            _rewardedLoading = false;
            _rewardedAd = null;
            debugPrint(
              'AdsService: rewarded failed to load '
              '(code=${error.code}, message=${error.message})',
            );
          },
        ),
      );
    } catch (e) {
      _rewardedLoading = false;
      _rewardedAd = null;
      debugPrint('AdsService: rewarded load threw: $e');
    }
  }

  Future<bool> _showRewarded(BuildContext context) async {
    if (!context.mounted) return false;
    if (!_canServeAds || _rewardedAd == null) {
      unawaited(_loadRewarded());
      return false;
    }

    final ad = _rewardedAd!;
    _rewardedAd = null; // a RewardedAd can only be shown once
    var earnedReward = false;
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_loadRewarded());
        if (!completer.isCompleted) completer.complete(earnedReward);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        unawaited(_loadRewarded());
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          earnedReward = true;
        },
      );
    } catch (e) {
      debugPrint('AdsService: rewarded show failed: $e');
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  @override
  Future<bool> showRewardedForHint(BuildContext context) =>
      _showRewarded(context);

  @override
  Future<bool> showRewardedForLives(BuildContext context) =>
      _showRewarded(context);

  // --- Level-clear hooks -------------------------------------------------

  @override
  Future<void> onLevelCleared(BuildContext context) async {
    _clearsSinceInterstitial++;
    // Every 5th campaign clear → fullscreen interstitial (closeable SDK ad).
    if (_clearsSinceInterstitial < _interstitialEveryNClears) return;
    _clearsSinceInterstitial = 0;
    if (!context.mounted) return;
    await showInterstitial(context);
  }

  @override
  Future<void> onDailyChallengeCleared(BuildContext context) async {
    // Daily has no ads — call site kept so gameplay/streak logic stays intact.
  }

  @override
  Future<void> onReturnToMapAfterFail(BuildContext context) async {}
}
