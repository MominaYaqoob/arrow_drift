import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arrow_drift/data/repositories/settings_repository.dart';

/// Gates system sounds / haptics behind Settings toggles.
class AppFeedback {
  AppFeedback._();

  static bool _soundsOn(WidgetRef ref) => ref.read(soundsEnabledProvider);
  static bool _vibrationOn(WidgetRef ref) =>
      ref.read(vibrationEnabledProvider);

  static void _playClick() {
    SystemSound.play(SystemSoundType.click);
  }

  /// Correct arrow remove.
  static void arrowTap(WidgetRef ref) {
    if (_soundsOn(ref)) _playClick();
    if (_vibrationOn(ref)) HapticFeedback.selectionClick();
  }

  /// Blocked / wrong arrow.
  static void wrongTap(WidgetRef ref) {
    if (_soundsOn(ref)) _playClick();
    if (_vibrationOn(ref)) HapticFeedback.mediumImpact();
  }

  /// Level cleared.
  static void levelComplete(WidgetRef ref) {
    if (_soundsOn(ref)) _playClick();
    if (_vibrationOn(ref)) HapticFeedback.lightImpact();
  }

  /// UI buttons (hint, zoom, etc.).
  static void buttonTap(WidgetRef ref) {
    if (_soundsOn(ref)) _playClick();
    if (_vibrationOn(ref)) HapticFeedback.selectionClick();
  }

  /// Play once when enabling Sounds in Settings.
  static void previewSound() {
    _playClick();
  }

  /// Play once when enabling Vibration in Settings.
  static void previewVibration() {
    HapticFeedback.mediumImpact();
  }
}
