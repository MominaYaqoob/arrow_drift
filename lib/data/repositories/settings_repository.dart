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

  static const _soundsKey = 'settings_sounds';
  static const _vibrationKey = 'settings_vibration';
  static const _darkThemeKey = 'settings_dark_theme';
  static const _autoLockKey = 'settings_auto_lock';

  AppSettings load() {
    return AppSettings(
      sounds: _prefs.getBool(_soundsKey) ?? true,
      vibration: _prefs.getBool(_vibrationKey) ?? true,
      darkTheme: _prefs.getBool(_darkThemeKey) ?? false,
      autoLock: _prefs.getBool(_autoLockKey) ?? false,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_soundsKey, settings.sounds);
    await _prefs.setBool(_vibrationKey, settings.vibration);
    await _prefs.setBool(_darkThemeKey, settings.darkTheme);
    await _prefs.setBool(_autoLockKey, settings.autoLock);
  }
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final settings = SettingsRepository(prefs).load();
    ref.read(themeModeProvider.notifier).state =
        settings.darkTheme ? ThemeMode.dark : ThemeMode.light;
    return settings;
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
    await _update(current.copyWith(darkTheme: value));
    ref.read(themeModeProvider.notifier).state =
        value ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setAutoLock(bool value) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _update(current.copyWith(autoLock: value));
  }

  Future<void> _update(AppSettings next) async {
    state = AsyncData(next);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await SettingsRepository(prefs).save(next);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
