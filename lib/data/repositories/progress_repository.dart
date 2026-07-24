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
  static const String hasAcceptedTermsKey = 'hasAcceptedTerms';

  static const String _legacyCurrentLevelKey = 'current_level';
  static const String _lastCompletedLevelKey = 'last_completed_level';
  static const String _dailyCompletedKey = 'daily_completed_dates';
  static const String _streakKey = 'current_streak';
  /// Last calendar day that counted toward the Snapchat-style streak (`yyyy-MM-dd`).
  static const String _streakLastDateKey = 'daily_streak_last_date';
  /// Epoch millis when the current 24h streak window ends (set only on today's clear).
  static const String _streakDeadlineKey = 'daily_streak_deadline_ms';
  /// Rolling window after each successful today-clear (Snapchat-style).
  static const Duration streakWindow = Duration(hours: 24);

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

  /// Whether the first-launch Terms/Privacy agree screen was accepted.
  bool getHasAcceptedTerms() => _prefs.getBool(hasAcceptedTermsKey) ?? false;

  Future<void> setHasAcceptedTerms(bool value) async {
    await _prefs.setBool(hasAcceptedTermsKey, value);
  }

  /// Marks [completedLevel] done and sets [currentLevel] to the next number.
  Future<void> saveProgress(int completedLevel) async {
    await _prefs.setInt(_lastCompletedLevelKey, completedLevel);
    await _prefs.setInt(currentLevelKey, completedLevel + 1);
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

  /// Snapchat-style streak: alive only while the 24h window from the last
  /// **today** clear has not expired. Past-day backfills keep calendar stars
  /// but never start or extend the timer.
  int getCurrentStreak({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final deadline = getStreakDeadline(now: clock);
    if (deadline == null || !clock.isBefore(deadline)) {
      return 0;
    }
    final lastKey = _prefs.getString(_streakLastDateKey);
    if (lastKey == null || lastKey.isEmpty) return 0;
    if (_parseDateKey(lastKey) == null) return 0;
    return _prefs.getInt(_streakKey) ?? 0;
  }

  /// When the current streak window ends, or null if inactive / expired.
  DateTime? getStreakDeadline({DateTime? now}) {
    final raw = _prefs.getInt(_streakDeadlineKey);
    if (raw == null) return null;
    final deadline = DateTime.fromMillisecondsSinceEpoch(raw);
    final clock = now ?? DateTime.now();
    if (!clock.isBefore(deadline)) return null;
    return deadline;
  }

  /// Remaining time in the active streak window, or [Duration.zero] if none.
  Duration getStreakRemaining({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final deadline = getStreakDeadline(now: clock);
    if (deadline == null) return Duration.zero;
    final left = deadline.difference(clock);
    return left.isNegative ? Duration.zero : left;
  }

  /// Marks a calendar daily complete. Streak + 24h timer update **only** for
  /// today's puzzle, and **only** on a successful clear (caller after win).
  Future<void> markDailyCompleted(DateTime date, {DateTime? now}) async {
    final key = _dateKey(date);
    final existing = [...getCompletedDailyDates()];
    if (!existing.contains(key)) {
      existing.add(key);
      await _prefs.setStringList(_dailyCompletedKey, existing);
    }

    final clock = now ?? DateTime.now();
    final today = _dayOnly(clock);
    final playDay = _dayOnly(date);

    // Past / future puzzles: stars only, no streak / timer change.
    if (!_sameDay(playDay, today)) return;

    final yesterday = today.subtract(const Duration(days: 1));
    final lastKey = _prefs.getString(_streakLastDateKey);
    final last = lastKey == null ? null : _parseDateKey(lastKey);
    final stored = _prefs.getInt(_streakKey) ?? 0;
    final deadline = getStreakDeadline(now: clock);
    final windowOpen = deadline != null;

    int nextStreak;
    if (last != null && _sameDay(last, today)) {
      // Already counted today — keep streak; do not restart the timer.
      nextStreak = stored > 0 ? stored : 1;
      await _prefs.setInt(_streakKey, nextStreak);
      await _prefs.setString(_streakLastDateKey, _dateKey(today));
      return;
    } else if (windowOpen &&
        last != null &&
        _sameDay(last, yesterday)) {
      // Cleared again inside the 24h window → continue streak.
      nextStreak = stored + 1;
    } else {
      // First clear, or previous window expired → fresh streak + timer.
      nextStreak = 1;
    }

    final nextDeadline = clock.add(streakWindow);
    await _prefs.setInt(_streakKey, nextStreak);
    await _prefs.setString(_streakLastDateKey, _dateKey(today));
    await _prefs.setInt(_streakDeadlineKey, nextDeadline.millisecondsSinceEpoch);
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _parseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static const String _ratePromptKey = 'has_shown_rate_prompt';
  static const String _ratePromptL5Key = 'has_shown_rate_prompt_l5';
  static const String _ratePromptL10Key = 'has_shown_rate_prompt_l10';
  static const String _ratePromptL11Key = 'has_shown_rate_prompt_l11';
  static const String _ratePromptMilestonesKey = 'rate_prompt_milestones';
  static const String _nicknameKey = 'player_nickname';
  static const String _avatarIdKey = 'player_avatar_id';

  /// Legacy single flag (older builds); prefer [hasShownRatePromptForLevel].
  bool getHasShownRatePrompt() => _prefs.getBool(_ratePromptKey) ?? false;

  Future<void> setHasShownRatePrompt(bool value) async {
    await _prefs.setBool(_ratePromptKey, value);
  }

  /// Rate dialog on levels 10, 20, 30… Once per milestone.
  bool hasShownRatePromptForLevel(int levelNumber) {
    if (levelNumber < 10 || levelNumber % 10 != 0) return true;

    final milestones =
        _prefs.getStringList(_ratePromptMilestonesKey) ?? const [];
    if (milestones.contains('$levelNumber')) return true;

    if (levelNumber == 10) {
      return (_prefs.getBool(_ratePromptL10Key) ?? false) ||
          getHasShownRatePrompt();
    }
    return false;
  }

  Future<void> setHasShownRatePromptForLevel(int levelNumber) async {
    final key = '$levelNumber';
    final milestones = [
      ...(_prefs.getStringList(_ratePromptMilestonesKey) ?? const <String>[]),
    ];
    if (!milestones.contains(key)) {
      milestones.add(key);
      await _prefs.setStringList(_ratePromptMilestonesKey, milestones);
    }
    if (levelNumber == 10) {
      await _prefs.setBool(_ratePromptL10Key, true);
      await _prefs.setBool(_ratePromptKey, true);
    }
    if (levelNumber == 5) {
      await _prefs.setBool(_ratePromptL5Key, true);
    }
    if (levelNumber == 11) {
      await _prefs.setBool(_ratePromptL11Key, true);
      await _prefs.setBool(_ratePromptKey, true);
    }
  }

  /// Player display name (empty until first-run nickname dialog).
  String getNickname() => _prefs.getString(_nicknameKey)?.trim() ?? '';

  Future<void> setNickname(String value) async {
    await _prefs.setString(_nicknameKey, value.trim());
  }

  /// Selected profile avatar id (see PlayerAvatar catalog on Me screen).
  String getAvatarId() {
    final raw = _prefs.getString(_avatarIdKey)?.trim();
    if (raw == null || raw.isEmpty) return 'avatar_1';
    return raw;
  }

  Future<void> setAvatarId(String value) async {
    await _prefs.setString(_avatarIdKey, value.trim());
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

/// Live remaining time in the Snapchat-style 24h streak window.
/// Emits every second while a window is active; `Duration.zero` when none.
final streakRemainingProvider = StreamProvider<Duration>((ref) async* {
  final repo = await ref.watch(progressRepositoryProvider.future);
  // Re-emit when streak is marked complete (provider invalidated).
  ref.watch(currentStreakProvider);
  while (true) {
    final left = repo.getStreakRemaining();
    yield left;
    if (left == Duration.zero) {
      // Idle until streak changes again.
      await Future<void>.delayed(const Duration(seconds: 5));
    } else {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
});

/// Formats a streak countdown like `14h 32m` or `45m` / `12s`.
String formatStreakRemaining(Duration d) {
  if (d <= Duration.zero) return '';
  final totalSec = d.inSeconds;
  final hours = totalSec ~/ 3600;
  final minutes = (totalSec % 3600) ~/ 60;
  final seconds = totalSec % 60;
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
  return '${seconds}s';
}

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

final playerAvatarIdProvider = FutureProvider<String>((ref) async {
  final repo = await ref.watch(progressRepositoryProvider.future);
  return repo.getAvatarId();
});
