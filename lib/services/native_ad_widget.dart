import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/services/ads_service.dart';

/// Loads a Google native template into a reserved slot.
///
/// Empty until a real ad arrives — no fake "Sponsored" placeholder, and no
/// leftover gap if the request fails.
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
        debugPrint('NativeAdWidget: init wait failed: $e');
      }
    }
    if (_disposed || !mounted || _loadStarted) return;
    _loadStarted = true;
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    unawaited(_load(colors, isDark));
  }

  Future<void> _load(AppColorScheme colors, bool isDark) async {
    final ad = NativeAd(
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.format == NativeAdFormat.medium
            ? TemplateType.medium
            : TemplateType.small,
        mainBackgroundColor: isDark ? colors.surface : Colors.white,
        cornerRadius: 12,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppColors.accentTealDeep,
          size: 14,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: colors.primaryText,
          size: 14,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: colors.secondaryText,
          size: 12,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (loaded) {
          if (_disposed || !mounted) {
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
          if (!_disposed && mounted) {
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
      if (!_disposed && mounted) {
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
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}
