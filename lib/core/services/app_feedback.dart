import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arrow_drift/data/repositories/settings_repository.dart';

/// Game SFX + haptics, gated by Settings toggles.
///
/// Soft puzzle-game feel: short blips on correct escape, a low buzz on
/// wrong taps, a tiny rising chime on level clear — never loud/gamey.
class AppFeedback {
  AppFeedback._();

  static final AudioPlayer _player = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  static bool _soundsOn(WidgetRef ref) => ref.read(soundsEnabledProvider);
  static bool _vibrationOn(WidgetRef ref) =>
      ref.read(vibrationEnabledProvider);

  static Future<void> _playAsset(String asset) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset), volume: 0.55);
    } catch (_) {
      // Missing asset / platform audio failure must never break taps.
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Correct arrow remove — soft high blip + light tap.
  static void arrowTap(WidgetRef ref) {
    if (_soundsOn(ref)) unawaited(_playAsset('sounds/tap_ok.wav'));
    if (_vibrationOn(ref)) HapticFeedback.lightImpact();
  }

  /// Blocked / wrong arrow — low buzz + heavier double thump.
  static void wrongTap(WidgetRef ref) {
    if (_soundsOn(ref)) unawaited(_playAsset('sounds/tap_wrong.wav'));
    if (_vibrationOn(ref)) {
      HapticFeedback.mediumImpact();
      Future<void>.delayed(const Duration(milliseconds: 70), () {
        HapticFeedback.heavyImpact();
      });
    }
  }

  /// Level cleared — short rising chime + celebratory pulse.
  static void levelComplete(WidgetRef ref) {
    if (_soundsOn(ref)) unawaited(_playAsset('sounds/level_win.wav'));
    if (_vibrationOn(ref)) {
      HapticFeedback.mediumImpact();
      Future<void>.delayed(const Duration(milliseconds: 90), () {
        HapticFeedback.lightImpact();
      });
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        HapticFeedback.selectionClick();
      });
    }
  }

  /// UI buttons (hint, zoom, etc.) — tiny tick + selection haptic.
  static void buttonTap(WidgetRef ref) {
    if (_soundsOn(ref)) unawaited(_playAsset('sounds/ui_tap.wav'));
    if (_vibrationOn(ref)) HapticFeedback.selectionClick();
  }

  /// Play once when enabling Sounds in Settings.
  static void previewSound() {
    unawaited(_playAsset('sounds/ui_tap.wav'));
  }

  /// Play once when enabling Vibration in Settings.
  static void previewVibration() {
    HapticFeedback.mediumImpact();
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      HapticFeedback.lightImpact();
    });
  }
}
