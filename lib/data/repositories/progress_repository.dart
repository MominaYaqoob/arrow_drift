import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arrow_drift/data/repositories/preferences_repository.dart';

/// Persists campaign progress, tutorial flag, daily stars, and streak.
class ProgressRepository {
  ProgressRepository(this._prefs) {
    coinBalanceTick.value = getCoinBalance();
  }

  final SharedPreferences _prefs;

  /// Current coin balance; updated inside [addCoins] / [spendCoins].
  static final ValueNotifier<int> coinBalanceTick = ValueNotifier<int>(0);

  /// Bumped inside [unlockPatternLevel] so gallery lock badges refresh.
  static final ValueNotifier<int> unlockedPatternTick = ValueNotifier<int>(0);

  /// Exact keys required by progression spec.
  static const String currentLevelKey = 'currentLevel';
  static const String hasSeenTutorialKey = 'hasSeenTutorial';
  static const String hasAcceptedTermsKey = 'hasAcceptedTerms';

  static const String _legacyCurrentLevelKey = 'current_level';
  static const String _lastCompletedLevelKey = 'last_completed_level';
  static const String _dailyCompletedKey = 'daily_completed_dates';
  static const String _patternCompletedKey = 'pattern_completed_levels';
  static const String _unlockedPatternLevelsKey = 'unlocked_pattern_levels';
  static const String _coinBalanceKey = 'coin_balance';
  static const String _streakKey = 'current_streak';
  /// Last calendar day that counted toward the Snapchat-style streak (`yyyy-MM-dd`).
  static const String _streakLastDateKey = 'daily_streak_last_date';
  /// Legacy key from the old rolling 24h timer — no longer written; kept so
  /// old installs don't crash if something still reads prefs.
  static const String _streakDeadlineKey = 'daily_streak_deadline_ms';
  /// Hours left in the day when the countdown turns urgent (red).
  static const Duration streakUrgentWindow = Duration(hours: 4);

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

  /// Gallery numbers (1, 2, 3…) the player has cleared in Patterns.
  /// Does not write campaign [saveProgress] keys.
  List<int> getCompletedPatternLevels() {
    return (_prefs.getStringList(_patternCompletedKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
  }

  bool isPatternCompleted(int patternNumber) =>
      getCompletedPatternLevels().contains(patternNumber);

  Future<void> markPatternCompleted(int patternNumber) async {
    final stored = [
      ...(_prefs.getStringList(_patternCompletedKey) ?? const <String>[]),
    ];
    final key = '$patternNumber';
    if (stored.contains(key)) return;
    stored.add(key);
    await _prefs.setStringList(_patternCompletedKey, stored);
  }

  int getCoinBalance() => _prefs.getInt(_coinBalanceKey) ?? 0;

  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    final next = getCoinBalance() + amount;
    await _prefs.setInt(_coinBalanceKey, next);
    coinBalanceTick.value = next;
  }

  Future<bool> spendCoins(int amount) async {
    if (amount <= 0) return false;
    final balance = getCoinBalance();
    if (balance < amount) return false;
    final next = balance - amount;
    await _prefs.setInt(_coinBalanceKey, next);
    coinBalanceTick.value = next;
    return true;
  }

  List<int> getUnlockedPatternLevels() {
    return (_prefs.getStringList(_unlockedPatternLevelsKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
  }

  bool isPatternLevelUnlocked(int level) {
    if (level == 1) return true;
    if (level < 2 || level > 100) return false;
    return getUnlockedPatternLevels().contains(level);
  }

  Future<void> unlockPatternLevel(int level) async {
    if (level < 1 || level > 100) return;
    final stored = [
      ...(_prefs.getStringList(_unlockedPatternLevelsKey) ?? const <String>[]),
    ];
    final key = '$level';
    if (!stored.contains(key)) {
      stored.add(key);
      await _prefs.setStringList(_unlockedPatternLevelsKey, stored);
    }
    unlockedPatternTick.value++;
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

  /// Snapchat-style calendar streak: alive if the last counted clear was
  /// **today** or **yesterday**. Miss a full calendar day → 0.
  int getCurrentStreak({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final today = _dayOnly(clock);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastKey = _prefs.getString(_streakLastDateKey);
    if (lastKey == null || lastKey.isEmpty) return 0;
    final last = _parseDateKey(lastKey);
    if (last == null) return 0;
    final stored = _prefs.getInt(_streakKey) ?? 0;
    if (stored <= 0) return 0;
    if (_sameDay(last, today) || _sameDay(last, yesterday)) return stored;
    return 0;
  }

  /// True when streak is alive and today's daily is still pending.
  bool isTodayStreakPending({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final today = _dayOnly(clock);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastKey = _prefs.getString(_streakLastDateKey);
    final last = lastKey == null ? null : _parseDateKey(lastKey);
    if (last == null) return false;
    final stored = _prefs.getInt(_streakKey) ?? 0;
    if (stored <= 0) return false;
    return _sameDay(last, yesterday);
  }

  /// True when today's daily already counted toward the streak.
  bool isTodayStreakCleared({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final today = _dayOnly(clock);
    final lastKey = _prefs.getString(_streakLastDateKey);
    final last = lastKey == null ? null : _parseDateKey(lastKey);
    if (last == null) return false;
    return _sameDay(last, today) && getCurrentStreak(now: clock) > 0;
  }

  /// Midnight that ends today's calendar window (start of tomorrow).
  DateTime? getStreakDeadline({DateTime? now}) {
    final clock = now ?? DateTime.now();
    if (!isTodayStreakPending(now: clock)) return null;
    return _dayOnly(clock).add(const Duration(days: 1));
  }

  /// Countdown until tonight's midnight — only while streak is alive and
  /// today's daily is still pending. Zero when today is already cleared.
  Duration getStreakRemaining({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final deadline = getStreakDeadline(now: clock);
    if (deadline == null) return Duration.zero;
    final left = deadline.difference(clock);
    return left.isNegative ? Duration.zero : left;
  }

  /// Last few hours of the day → urgent (UI can turn red).
  bool isStreakUrgent({DateTime? now}) {
    final left = getStreakRemaining(now: now);
    return left > Duration.zero && left <= streakUrgentWindow;
  }

  /// Marks a calendar daily complete. Streak updates **only** for today's
  /// puzzle on a successful clear. Past/future dates = stars only.
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

    int nextStreak;
    if (last != null && _sameDay(last, today)) {
      // Already counted today — keep streak; timer stays hidden.
      nextStreak = stored > 0 ? stored : 1;
      await _prefs.setInt(_streakKey, nextStreak);
      await _prefs.setString(_streakLastDateKey, _dateKey(today));
      return;
    } else if (last != null && _sameDay(last, yesterday) && stored > 0) {
      // Cleared again on the next calendar day → continue streak.
      nextStreak = stored + 1;
    } else {
      // First clear, or missed a day → fresh streak.
      nextStreak = 1;
    }

    await _prefs.setInt(_streakKey, nextStreak);
    await _prefs.setString(_streakLastDateKey, _dateKey(today));
    // Drop legacy rolling deadline if present.
    await _prefs.remove(_streakDeadlineKey);
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

/// Bumped after campaign progress is written so Home/Me re-read prefs.
/// FutureProvider otherwise can keep the previous int when only prefs changed.
final campaignProgressTickProvider = StateProvider<int>((ref) => 0);

/// Bumped after a Patterns puzzle is cleared (separate from campaign).
final patternProgressTickProvider = StateProvider<int>((ref) => 0);

/// Bumped after coins are earned or spent (see [ProgressRepository.coinBalanceTick]).
final coinBalanceTickProvider = StateProvider<int>((ref) => 0);

final coinBalanceProvider = FutureProvider<int>((ref) async {
  ref.watch(coinBalanceTickProvider);
  final repo = await ref.watch(progressRepositoryProvider.future);
  return repo.getCoinBalance();
});

/// Bumped after a Custom level is coin-unlocked.
final unlockedPatternTickProvider = StateProvider<int>((ref) => 0);

final completedPatternLevelsProvider = FutureProvider<List<int>>((ref) async {
  ref.watch(patternProgressTickProvider);
  final repo = await ref.watch(progressRepositoryProvider.future);
  return repo.getCompletedPatternLevels();
});

final currentLevelProvider = FutureProvider<int>((ref) async {
  ref.watch(campaignProgressTickProvider);
  final repo = await ref.watch(progressRepositoryProvider.future);
  return repo.getCurrentLevel();
});

final lastCompletedLevelProvider = FutureProvider<int>((ref) async {
  ref.watch(campaignProgressTickProvider);
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

/// Live remaining time until tonight's midnight while today's streak is pending.
/// Emits every second while a window is active; `Duration.zero` when none.
final streakRemainingProvider = StreamProvider<Duration>((ref) {
  // Re-subscribe when streak is marked complete (provider invalidated).
  ref.watch(currentStreakProvider);

  final controller = StreamController<Duration>();
  Timer? timer;
  var disposed = false;

  Future<void> start() async {
    final repo = await ref.watch(progressRepositoryProvider.future);
    if (disposed || controller.isClosed) return;

    void tick() {
      if (disposed || controller.isClosed) return;
      final left = repo.getStreakRemaining();
      controller.add(left);
      final delay = left == Duration.zero
          ? const Duration(seconds: 5)
          : const Duration(seconds: 1);
      timer = Timer(delay, tick);
    }

    tick();
  }

  start();

  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
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
