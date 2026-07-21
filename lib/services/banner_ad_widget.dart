import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Loads and shows a real AdMob banner inside a fixed-height reserved slot.
///
/// Fails **silently** by design: if the SDK isn't initialized, there's no
/// connectivity, the ad request errors out, or the widget is disposed
/// mid-load, this keeps an empty reserved-height slot (no fake "Sponsored"
/// placeholder) instead of crashing. Height never changes, so layout
/// around it never jumps.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({
    super.key,
    required this.adUnitId,
    required this.height,
    this.ensureInitialized,
  });

  final String adUnitId;
  final double height;

  /// Called before the first ad request so SDK init (and the connectivity
  /// check it depends on) can finish — safe to pass `null` if the caller
  /// already knows the SDK is ready.
  final Future<void> Function()? ensureInitialized;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _disposed = false;
  bool _loadStarted = false;

  @override
  void initState() {
    super.initState();
    _prepareAndLoad();
  }

  Future<void> _prepareAndLoad() async {
    final ensure = widget.ensureInitialized;
    if (ensure != null) {
      try {
        await ensure();
      } catch (e) {
        debugPrint('BannerAdWidget: init wait failed: $e');
      }
    }
    if (_disposed || !mounted || _loadStarted) return;
    _loadStarted = true;
    unawaited(_load());
  }

  Future<void> _load() async {
    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (_disposed || !mounted) {
            loaded.dispose();
            return;
          }
          setState(() {
            _bannerAd = loaded as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (failed, error) {
          debugPrint(
            'BannerAdWidget: failed to load '
            '(code=${error.code}, message=${error.message})',
          );
          failed.dispose();
          if (!_disposed && mounted) {
            setState(() {
              _isLoaded = false;
              _bannerAd = null;
            });
          }
        },
      ),
    );
    try {
      await ad.load();
    } catch (e) {
      ad.dispose();
      if (!_disposed && mounted) {
        setState(() {
          _isLoaded = false;
          _bannerAd = null;
        });
      }
      debugPrint('BannerAdWidget: load() threw: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reserved height only — empty until a real AdMob banner loads.
    // Do not show the fake "Sponsored · Arrow Drift" AdSlot here.
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: (_isLoaded && _bannerAd != null)
          ? Center(
              child: SizedBox(
                width: AdSize.banner.width.toDouble(),
                height: AdSize.banner.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
