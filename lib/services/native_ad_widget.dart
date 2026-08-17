import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/services/ads_service.dart';

/// Loads a Google native template into a reserved slot.
///
/// Empty until a real ad arrives — no fake "Sponsored" placeholder, and no
/// leftover gap if the request fails. Card chrome matches Me tiles
/// (Awards / Settings): surface, radius 14, light border + soft shadow.
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({
    super.key,
    required this.adUnitId,
    required this.height,
    required this.format,
    this.ensureInitialized,
  });

  final String adUnitId;
  final double height;
  final NativeAdFormat format;
  final Future<void> Function()? ensureInitialized;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _disposed = false;
  bool _loadStarted = false;
  Brightness? _appliedBrightness;
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _prepareAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (!_loadStarted) return;
    if (_appliedBrightness == brightness) return;
    unawaited(_reload(brightness));
  }

  Future<void> _prepareAndLoad() async {
    final ensure = widget.ensureInitialized;
    if (ensure != null) {
      try {
        await ensure();
      } catch (e) {
        debugPrint('NativeAdWidget: init wait failed: $e');
      }
    }
    if (_disposed || !mounted || _loadStarted) return;
    _loadStarted = true;
    final brightness = Theme.of(context).brightness;
    _appliedBrightness = brightness;
    unawaited(_load(brightness == Brightness.dark));
  }

  Future<void> _reload(Brightness brightness) async {
    _appliedBrightness = brightness;
    _nativeAd?.dispose();
    _nativeAd = null;
    if (mounted) {
      setState(() => _isLoaded = false);
    }
    await _load(brightness == Brightness.dark);
  }

  Future<void> _load(bool isDark) async {
    final gen = ++_loadGen;
    final isMedium = widget.format == NativeAdFormat.medium;
    final ad = NativeAd(
      adUnitId: widget.adUnitId,
      factoryId: 'arrow_native',
      customOptions: <String, Object>{
        'format': isMedium ? 'medium' : 'small',
        'isDark': isDark,
      },
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (loaded) {
          if (_disposed || !mounted || gen != _loadGen) {
            loaded.dispose();
            return;
          }
          setState(() {
            _nativeAd = loaded as NativeAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (failed, error) {
          debugPrint(
            'NativeAdWidget: failed to load '
            '(code=${error.code}, message=${error.message})',
          );
          failed.dispose();
          if (!_disposed && mounted && gen == _loadGen) {
            setState(() {
              _isLoaded = false;
              _nativeAd = null;
            });
          }
        },
      ),
    );
    try {
      await ad.load();
    } catch (e) {
      ad.dispose();
      if (!_disposed && mounted && gen == _loadGen) {
        setState(() {
          _isLoaded = false;
          _nativeAd = null;
        });
      }
      debugPrint('NativeAdWidget: load() threw: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const radius = 14.0;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: colors.border.withValues(alpha: isDark ? 1 : 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}
