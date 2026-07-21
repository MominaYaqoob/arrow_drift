import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import 'package:arrow_drift/data/repositories/settings_repository.dart';

/// Game SFX + haptics, gated by Settings toggles.
///
/// Soft puzzle-game feel: short blips on correct escape, a low buzz on
/// wrong taps, a tiny rising chime on level clear — never loud/gamey.
///
/// Vibration uses the Android [Vibrator] API (via `vibration` package).
/// Flutter [HapticFeedback] alone is often silent on many phones when
/// system "touch haptics" are weak or off.
class AppFeedback {
  AppFeedback._();

  static final AudioPlayer _player = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  static bool? _hasVibrator;

  static bool _soundsOn(WidgetRef ref) => ref.read(soundsEnabledProvider);
  static bool _vibrationOn(WidgetRef ref) =>
      ref.read(vibrationEnabledProvider);

  static Future<void> _playAsset(String asset, {double volume = 0.55}) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset), volume: volume);
    } catch (_) {
      // Missing asset / platform audio failure must never break taps.
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Real motor buzz — works on phones where HapticFeedback does nothing.
  static Future<void> _buzz({
    int durationMs = 45,
    int amplitude = 180,
    List<int>? pattern,
  }) async {
    if (kIsWeb) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
      return;
    }
    try {
      _hasVibrator ??= await Vibration.hasVibrator();
      if (_hasVibrator != true) {
        await HapticFeedback.mediumImpact();
        return;
      }
      if (pattern != null) {
        await Vibration.vibrate(pattern: pattern);
      } else {
        final hasAmp = await Vibration.hasAmplitudeControl();
        if (hasAmp) {
          await Vibration.vibrate(
            duration: durationMs,
            amplitude: amplitude.clamp(1, 255),
          );
        } else {
          await Vibration.vibrate(duration: durationMs);
        }
      }
    } catch (_) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  /// Correct arrow remove — soft escape sound + light tap.
  static void arrowTap(WidgetRef ref) {
    if (_vibrationOn(ref)) {
      unawaited(_buzz(durationMs: 35, amplitude: 140));
    }
    if (_soundsOn(ref)) {
      unawaited(_playAsset('sounds/arrow_escape.wav', volume: 0.38));
    }
  }

  /// Blocked / wrong arrow — hit thud + stronger double buzz.
  static void wrongTap(WidgetRef ref) {
    if (_vibrationOn(ref)) {
      unawaited(_buzz(pattern: [0, 50, 40, 70]));
    }
    if (_soundsOn(ref)) {
      unawaited(_playAsset('sounds/arrow_hit.wav', volume: 0.55));
    }
  }

  /// Level cleared — short rising chime + celebratory pulse.
  static void levelComplete(WidgetRef ref) {
    if (_vibrationOn(ref)) {
      unawaited(_buzz(pattern: [0, 40, 50, 40, 50, 55]));
    }
    if (_soundsOn(ref)) unawaited(_playAsset('sounds/level_win.wav'));
  }

  /// UI buttons (hint, zoom, etc.) — tiny tick + short buzz.
  static void buttonTap(WidgetRef ref) {
    if (_vibrationOn(ref)) {
      unawaited(_buzz(durationMs: 25, amplitude: 100));
    }
    if (_soundsOn(ref)) unawaited(_playAsset('sounds/ui_tap.wav'));
  }

  /// Play once when enabling Sounds in Settings.
  static void previewSound() {
    unawaited(_playAsset('sounds/ui_tap.wav'));
  }

  /// Play once when enabling Vibration in Settings.
  static void previewVibration() {
    unawaited(_buzz(pattern: [0, 60, 40, 80]));
  }
}
