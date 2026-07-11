import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'preferences_repository.g.dart';

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) async {
  return SharedPreferences.getInstance();
}

class PreferencesRepository {
  const PreferencesRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _onboardingCompleteKey = 'onboarding_complete';

  bool get isOnboardingComplete =>
      _prefs.getBool(_onboardingCompleteKey) ?? false;

  Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setBool(_onboardingCompleteKey, value);
  }
}

@Riverpod(keepAlive: true)
Future<PreferencesRepository> preferencesRepository(Ref ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return PreferencesRepository(prefs);
}
