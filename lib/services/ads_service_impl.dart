import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arrow_drift/services/ads_service.dart';
import 'package:arrow_drift/services/banner_ad_widget.dart';
import 'package:arrow_drift/services/native_ad_widget.dart';
import 'package:arrow_drift/services/network_status.dart';

/// Real AdMob integration using **production** ad unit IDs (App Open, Native,
/// Interstitial, Rewarded) plus the production App ID in AndroidManifest.xml.
/// `_bannerAdUnitId` is unused (no active banner placement) and remains
/// Google's official test unit. Debug builds register test device IDs so QA
/// on a listed phone gets labeled Test Ads and does not count as invalid traffic.
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
class AdsServiceImpl with WidgetsBindingObserver implements AdsService {
  AdsServiceImpl._();
  static final AdsServiceImpl instance = AdsServiceImpl._();

  bool _initialized = false;
  Future<void>? _initializing;
  bool _hasConnectivity = true;
  StreamSubscription<bool>? _connectivitySub;

  InterstitialAd? _interstitialAd;
  bool _interstitialLoading = false;
  RewardedAd? _rewardedAd;
  bool _rewardedLoading = false;
  AppOpenAd? _appOpenAd;
  bool _appOpenLoading = false;
  Completer<void>? _appOpenLoadGate;
  bool _isShowingAppOpen = false;
  bool _isShowingFullscreenAd = false;
  bool _observingLifecycle = false;
  bool _wentBackground = false;
  /// Swallow the resume that follows our own fullscreen ad (not a real leave).
  DateTime? _ignoreAppOpenResumeUntil;

  static const Duration _interstitialDuration = Duration(seconds: 12);
  static const String _clearCountKey = 'campaign_clear_count_for_interstitial';

  // Unused (no active banner placement) — left as Google's test ID.
  static const String _bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _nativeAdUnitId =
      'ca-app-pub-3463774223212169/5930100598';
  static const String _interstitialAdUnitId =
      'ca-app-pub-3463774223212169/9681643343';
  static const String _rewardedAdUnitId =
      'ca-app-pub-3463774223212169/5241881052';
  static const String _appOpenAdUnitId =
      'ca-app-pub-3463774223212169/6504815661';

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
      if (kDebugMode) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: <String>[
              // TODO: paste the device hash ID that appears in the debug console the
              // first time this build runs on a real device — logcat will print a
              // line like: "Use RequestConfiguration.Builder().setTestDeviceIds
              // (Arrays.asList("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")) to get test ads on
              // this device." Copy that hash here.
            ],
          ),
        );
      }
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
      // so the first trigger is not waiting on the network.
      if (!_observingLifecycle) {
        WidgetsBinding.instance.addObserver(this);
        _observingLifecycle = true;
      }

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
    if (_appOpenAd != null) {
      _completeAppOpenGate();
      return;
    }
    if (!_canServeAds) {
      _completeAppOpenGate();
      return;
    }
    if (_appOpenLoading) return;

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
            debugPrint('AdsService: app open loaded');
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

  Future<void> _waitForAppOpen(Duration timeout) async {
    if (_appOpenAd != null) return;
    if (_appOpenLoadGate == null || _appOpenLoadGate!.isCompleted) {
      _appOpenLoadGate = Completer<void>();
      unawaited(_loadAppOpen());
    }
    try {
      await _appOpenLoadGate!.future.timeout(timeout);
    } on TimeoutException {
      debugPrint('AdsService: app open wait timed out');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // App Open / interstitial pause the activity. That is not Recents/Home.
      if (_isShowingAppOpen || _isShowingFullscreenAd) return;
      _wentBackground = true;
      return;
    }
    if (state != AppLifecycleState.resumed || !_wentBackground) return;
    _wentBackground = false;
    if (_isShowingAppOpen || _isShowingFullscreenAd) return;
    final ignoreUntil = _ignoreAppOpenResumeUntil;
    if (ignoreUntil != null && DateTime.now().isBefore(ignoreUntil)) return;
    // Recents / Home se wapas: next App Open. Pehla launch splash handle karta hai.
    unawaited(showAppOpenIfReady());
  }

  @override
  Future<void> showAppOpenIfReady() async {
    if (_isShowingAppOpen) return;
    _isShowingAppOpen = true;
    try {
      await initialize();
      if (!_canServeAds) return;

      await _waitForAppOpen(const Duration(seconds: 6));
      final ad = _appOpenAd;
      if (ad == null) {
        debugPrint('AdsService: app open not ready — skipping');
        return;
      }

      // Let the current frame settle so Android can present a fullscreen ad.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (_appOpenAd != ad) return;

      _appOpenAd = null;
      final completer = Completer<void>();

      ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
        onAdShowedFullScreenContent: (shown) {
          debugPrint('AdsService: app open showing');
        },
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
    } finally {
      _isShowingAppOpen = false;
      _wentBackground = false;
      _ignoreAppOpenResumeUntil =
          DateTime.now().add(const Duration(seconds: 4));
      unawaited(_loadAppOpen());
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
    _isShowingFullscreenAd = true;

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
      return await completer.future;
    } catch (e) {
      debugPrint('AdsService: interstitial show failed: $e');
      if (!completer.isCompleted) completer.complete();
      return;
    } finally {
      _isShowingFullscreenAd = false;
      _wentBackground = false;
      _ignoreAppOpenResumeUntil =
          DateTime.now().add(const Duration(seconds: 4));
    }
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
    _isShowingFullscreenAd = true;

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
      return await completer.future;
    } catch (e) {
      debugPrint('AdsService: rewarded show failed: $e');
      if (!completer.isCompleted) completer.complete(false);
      return false;
    } finally {
      _isShowingFullscreenAd = false;
      _wentBackground = false;
      _ignoreAppOpenResumeUntil =
          DateTime.now().add(const Duration(seconds: 4));
    }
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
    if (!_canServeAds) return;
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_clearCountKey) ?? 0) + 1;
    await prefs.setInt(_clearCountKey, count);

    if (count % 5 == 0) {
      if (!context.mounted) return;
      await showInterstitial(context);
    }
  }

  @override
  Future<void> onDailyChallengeCleared(BuildContext context) async {
    if (!_canServeAds) return;
    if (!context.mounted) return;
    await showInterstitial(context);
  }

  @override
  Future<void> onReturnToMapAfterFail(BuildContext context) async {}
}
