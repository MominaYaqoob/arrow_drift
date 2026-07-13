import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/preferences_repository.dart';

class AppSettings {
  const AppSettings({
    required this.sounds,
    required this.vibration,
    required this.darkTheme,
    required this.autoLock,
  });

  final bool sounds;
  final bool vibration;
  final bool darkTheme;
  final bool autoLock;

  AppSettings copyWith({
    bool? sounds,
    bool? vibration,
    bool? darkTheme,
    bool? autoLock,
  }) {
    return AppSettings(
      sounds: sounds ?? this.sounds,
      vibration: vibration ?? this.vibration,
      darkTheme: darkTheme ?? this.darkTheme,
      autoLock: autoLock ?? this.autoLock,
    );
  }
}

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const soundsEnabledKey = 'soundsEnabled';
  static const vibrationEnabledKey = 'vibrationEnabled';
  static const darkThemeKey = 'settings_dark_theme';
  static const autoLockKey = 'autoLock';

  AppSettings load() {
    return AppSettings(
      sounds: _prefs.getBool(soundsEnabledKey) ?? true,
      vibration: _prefs.getBool(vibrationEnabledKey) ?? true,
      darkTheme: _prefs.getBool(darkThemeKey) ?? false,
      autoLock: _prefs.getBool(autoLockKey) ?? false,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(soundsEnabledKey, settings.sounds);
    await _prefs.setBool(vibrationEnabledKey, settings.vibration);
    await _prefs.setBool(darkThemeKey, settings.darkTheme);
    await _prefs.setBool(autoLockKey, settings.autoLock);
  }
}

/// Live flags used by feedback / lock (defaults match fresh-install prefs).
final soundsEnabledProvider = StateProvider<bool>((ref) => true);
final vibrationEnabledProvider = StateProvider<bool>((ref) => true);
final autoLockEnabledProvider = StateProvider<bool>((ref) => false);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final settings = SettingsRepository(prefs).load();
    _syncLiveProviders(settings);
    ref.read(themeModeProvider.notifier).state =
        settings.darkTheme ? ThemeMode.dark : ThemeMode.light;
    return settings;
  }

  void _syncLiveProviders(AppSettings settings) {
    ref.read(soundsEnabledProvider.notifier).state = settings.sounds;
    ref.read(vibrationEnabledProvider.notifier).state = settings.vibration;
    ref.read(autoLockEnabledProvider.notifier).state = settings.autoLock;
  }

  Future<void> setSounds(bool value) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _update(current.copyWith(sounds: value));
  }

  Future<void> setVibration(bool value) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _update(current.copyWith(vibration: value));
  }

  Future<void> setDarkTheme(bool value) async {
    final current = state.valueOrNull;
    if (current == null) return;
    ref.read(themeModeProvider.notifier).state =
        value ? ThemeMode.dark : ThemeMode.light;
    await _update(current.copyWith(darkTheme: value));
  }

  Future<void> setAutoLock(bool value) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _update(current.copyWith(autoLock: value));
  }

  Future<void> _update(AppSettings next) async {
    state = AsyncData(next);
    _syncLiveProviders(next);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await SettingsRepository(prefs).save(next);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Whether the Settings Dark Theme switch should appear ON.
bool isDarkThemeToggleOn(BuildContext context, ThemeMode mode) {
  return switch (mode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark,
  };
}
