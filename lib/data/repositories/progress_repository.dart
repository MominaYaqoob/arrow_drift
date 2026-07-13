import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arrow_drift/data/repositories/preferences_repository.dart';

/// Persists campaign progress, tutorial flag, daily stars, and streak.
class ProgressRepository {
  ProgressRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Exact keys required by progression spec.
  static const String currentLevelKey = 'currentLevel';
  static const String hasSeenTutorialKey = 'hasSeenTutorial';

  static const String _legacyCurrentLevelKey = 'current_level';
  static const String _lastCompletedLevelKey = 'last_completed_level';
  static const String _dailyCompletedKey = 'daily_completed_dates';
  static const String _streakKey = 'current_streak';

  /// Next level to resume (defaults to 1 on fresh install).
  int getCurrentLevel() {
    return _prefs.getInt(currentLevelKey) ??
        _prefs.getInt(_legacyCurrentLevelKey) ??
        1;
  }

  /// Highest level finished (defaults to 0).
  int getLastCompletedLevel() => _prefs.getInt(_lastCompletedLevelKey) ?? 0;

  /// Whether the Level-1 guided tutorial has already been shown.
  /// Fresh install / reinstall → false (SharedPreferences wiped by OS).
  bool getHasSeenTutorial() => _prefs.getBool(hasSeenTutorialKey) ?? false;

  Future<void> setHasSeenTutorial(bool value) async {
    await _prefs.setBool(hasSeenTutorialKey, value);
  }

  /// Current daily play streak (defaults to 0).
  int getCurrentStreak() => _prefs.getInt(_streakKey) ?? 0;

  /// Marks [completedLevel] done and sets [currentLevel] to the next number.
  Future<void> saveProgress(int completedLevel) async {
    await _prefs.setInt(_lastCompletedLevelKey, completedLevel);
    await _prefs.setInt(currentLevelKey, completedLevel + 1);
    // Drop legacy key if present so resume always reads currentLevel.
    await _prefs.remove(_legacyCurrentLevelKey);
  }

  List<String> getCompletedDailyDates() =>
      _prefs.getStringList(_dailyCompletedKey) ?? const [];

  bool isDailyCompleted(DateTime date) {
    final key = _dateKey(date);
    return getCompletedDailyDates().contains(key);
  }

  int monthlyDailyStars(int year, int month) {
    return getCompletedDailyDates().where((value) {
      final parts = value.split('-');
      if (parts.length != 3) return false;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      return y == year && m == month;
    }).length;
  }

  Future<void> markDailyCompleted(DateTime date) async {
    final key = _dateKey(date);
    final existing = [...getCompletedDailyDates()];
    if (!existing.contains(key)) {
      existing.add(key);
      await _prefs.setStringList(_dailyCompletedKey, existing);
    }

    var computed = 0;
    var cursor = DateTime(date.year, date.month, date.day);
    final completed = existing.toSet();
    while (completed.contains(_dateKey(cursor))) {
      computed++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    await _prefs.setInt(_streakKey, computed);
  }

  static const String _ratePromptKey = 'has_shown_rate_prompt';
  static const String _ratePromptL5Key = 'has_shown_rate_prompt_l5';
  static const String _ratePromptL10Key = 'has_shown_rate_prompt_l10';
  static const String _ratePromptL11Key = 'has_shown_rate_prompt_l11';
  static const String _nicknameKey = 'player_nickname';

  /// Legacy single flag (older builds); prefer [hasShownRatePromptForLevel].
  bool getHasShownRatePrompt() => _prefs.getBool(_ratePromptKey) ?? false;

  Future<void> setHasShownRatePrompt(bool value) async {
    await _prefs.setBool(_ratePromptKey, value);
  }

  /// Rate dialog after Level 11 (once). Legacy L5/L10 keys kept for old installs.
  bool hasShownRatePromptForLevel(int levelNumber) {
    if (levelNumber == 11) {
      return (_prefs.getBool(_ratePromptL11Key) ?? false) ||
          getHasShownRatePrompt();
    }
    if (levelNumber == 5) {
      return _prefs.getBool(_ratePromptL5Key) ?? false;
    }
    if (levelNumber == 10) {
      return (_prefs.getBool(_ratePromptL10Key) ?? false) ||
          getHasShownRatePrompt();
    }
    return false;
  }

  Future<void> setHasShownRatePromptForLevel(int levelNumber) async {
    if (levelNumber == 11) {
      await _prefs.setBool(_ratePromptL11Key, true);
      await _prefs.setBool(_ratePromptKey, true);
    } else if (levelNumber == 5) {
      await _prefs.setBool(_ratePromptL5Key, true);
    } else if (levelNumber == 10) {
      await _prefs.setBool(_ratePromptL10Key, true);
      await _prefs.setBool(_ratePromptKey, true);
    }
  }

  /// Player display name (empty until first-run nickname dialog).
  String getNickname() => _prefs.getString(_nicknameKey)?.trim() ?? '';

  Future<void> setNickname(String value) async {
    await _prefs.setString(_nicknameKey, value.trim());
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

final progressRepositoryProvider =
    FutureProvider<ProgressRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return ProgressRepository(prefs);
});

final currentLevelProvider = FutureProvider<int>((ref) async {
  final repo = await ref.watch(progressRepositoryProvider.future);
  return repo.getCurrentLevel();
});

final lastCompletedLevelProvider = FutureProvider<int>((ref) async {
  final repo = await ref.watch(progressRepositoryProvider.future);
  return repo.getLastCompletedLevel();
});

final hasSeenTutorialProvider = FutureProvider<bool>((ref) async {
  final repo = await ref.watch(progressRepositoryProvider.future);
  return repo.getHasSeenTutorial();
});

final currentStreakProvider = FutureProvider<int>((ref) async {
  final repo = await ref.watch(progressRepositoryProvider.future);
  return repo.getCurrentStreak();
});

final monthlyDailyStarsProvider = FutureProvider<int>((ref) async {
  final repo = await ref.watch(progressRepositoryProvider.future);
  final now = DateTime.now();
  return repo.monthlyDailyStars(now.year, now.month);
});

final completedDailyDatesProvider = FutureProvider<Set<String>>((ref) async {
  final repo = await ref.watch(progressRepositoryProvider.future);
  return repo.getCompletedDailyDates().toSet();
});

final playerNicknameProvider = FutureProvider<String>((ref) async {
  final repo = await ref.watch(progressRepositoryProvider.future);
  return repo.getNickname();
});
