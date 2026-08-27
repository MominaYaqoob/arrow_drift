import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:arrow_drift/core/constants/app_constants.dart';
import 'package:arrow_drift/core/providers/connectivity_provider.dart';
import 'package:arrow_drift/core/services/app_feedback.dart';
import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/utils/online_gate.dart';
import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/models/game_state.dart';
import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/daily_challenge/daily_challenge_screen.dart';
import 'package:arrow_drift/features/daily_challenge/daily_loading_view.dart';
import 'package:arrow_drift/features/gameplay/game_controller.dart';
import 'package:arrow_drift/features/gameplay/widgets/game_board.dart';
import 'package:arrow_drift/features/gameplay/widgets/halfway_complete_toast.dart';
import 'package:arrow_drift/features/gameplay/widgets/level_completed_overlay.dart';
import 'package:arrow_drift/features/gameplay/widgets/out_of_lives_overlay.dart';
import 'package:arrow_drift/features/gameplay/widgets/pause_sheet.dart';
import 'package:arrow_drift/features/gameplay/widgets/rate_game_dialog.dart';
import 'package:arrow_drift/features/home/home_screen.dart';
import 'package:arrow_drift/services/ads_service.dart';

class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({
    super.key,
    this.levelNumber = 1,
    this.isDaily = false,
    this.dailyDate,
  });

  static const String routePath = '/gameplay';

  final int levelNumber;
  final bool isDaily;

  /// Calendar day for daily mode (`yyyy-MM-dd` via router). Defaults to today.
  final DateTime? dailyDate;

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen>
    with SingleTickerProviderStateMixin {
  String? _highlightedArrowId;
  final Map<String, int> _shakeTokens = {};
  final Map<String, double> _wrongBumpCells = {};
  Timer? _hintTimer;

  bool _hasSeenTutorial = true;
  bool _tutorialPrefsLoaded = false;

  bool _boardZoomed = false;

  /// After every 10 campaign levels: rate dialog, then Level Completed.
  bool _ratePromptDone = false;
  bool _ratePromptChecked = false;

  /// Mid-level "50% complete" toast (once per attempt).
  bool _halfwayToastShown = false;
  bool _halfwayToastVisible = false;
  Timer? _halfwayTimer;

  /// Delay Out of Lives until last heart empty animation is visible.
  bool _showOutOfLives = false;
  Timer? _outOfLivesTimer;

  /// Delay Level Complete until last arrow finishes escape on-screen.
  bool _showWinOverlay = false;
  Timer? _winOverlayTimer;

  /// Daily: hide board until load finishes + 1s soft wait.
  bool _dailyBoardVisible = false;
  Timer? _dailyRevealTimer;
  String? _dailyRevealArmedFor;

  /// Main Level 2+: hide board until load finishes + 1.2s soft wait.
  bool _campaignBoardVisible = false;
  Timer? _campaignRevealTimer;
  int? _campaignRevealArmedFor;

  /// Paint loader one frame before heavy board fetch (Daily + Main L2+).
  bool _loadFetchStarted = false;

  late final AnimationController _chromeController;
  late final Animation<double> _chromeOpacity;

  /// Fresh Level 1: guided UI + no heart loss until cleared once.
  bool get _tutorialSessionActive =>
      !widget.isDaily &&
      widget.levelNumber == 1 &&
      _tutorialPrefsLoaded &&
      !_hasSeenTutorial;

  @override
  void initState() {
    super.initState();
    _chromeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _chromeOpacity = CurvedAnimation(
      parent: _chromeController,
      curve: Curves.easeOut,
    );
    _chromeController.forward();
    _loadTutorialFlag();
    // Daily + Main levels 2+: show loader first, then start generation so
    // the previous screen never stays frozen waiting for the board.
    // Level 1 stays instant (tutorial / light board).
    if (widget.isDaily || widget.levelNumber > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _loadFetchStarted = true);
      });
    } else {
      _loadFetchStarted = true;
    }
    // After this frame: warm the next campaign level in the lazy cache so
    // "Next" navigation does not rebuild from scratch on the UI isolate.
    if (!widget.isDaily) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final repo = ref.read(levelRepositoryProvider);
        final next = widget.levelNumber + 1;
        if (next > repo.levelCount) return;
        Future<void>.delayed(const Duration(milliseconds: 80), () async {
          if (!mounted) return;
          // Async + background isolate: prefetching a 100-200 arrow Hard/
          // Expert board must not block the UI thread either.
          try {
            await repo.getLevelAsync(next);
          } catch (_) {}
        });
      });
    }
  }

  Future<void> _loadTutorialFlag() async {
    final repo = await ref.read(progressRepositoryProvider.future);
    if (!mounted) return;
    setState(() {
      _hasSeenTutorial = repo.getHasSeenTutorial();
      _tutorialPrefsLoaded = true;
    });
  }

  Future<void> _markTutorialSeen() async {
    if (_hasSeenTutorial) return;
    setState(() => _hasSeenTutorial = true);
    final repo = await ref.read(progressRepositoryProvider.future);
    await repo.setHasSeenTutorial(true);
    ref.invalidate(hasSeenTutorialProvider);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _halfwayTimer?.cancel();
    _outOfLivesTimer?.cancel();
    _winOverlayTimer?.cancel();
    _dailyRevealTimer?.cancel();
    _campaignRevealTimer?.cancel();
    _chromeController.dispose();
    super.dispose();
  }

  /// After daily board is built, wait 1s then reveal (board stays hidden).
  void _armDailyRevealIfNeeded() {
    if (!widget.isDaily) return;
    if (_dailyRevealArmedFor == _dailyKey) return;
    _dailyRevealArmedFor = _dailyKey;
    _dailyRevealTimer?.cancel();
    _dailyBoardVisible = false;
    _dailyRevealTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _dailyBoardVisible = true);
    });
  }

  /// After Main Level 2+ board is built, wait 1.2s then reveal.
  void _armCampaignRevealIfNeeded() {
    if (widget.isDaily || widget.levelNumber <= 1) return;
    if (_campaignRevealArmedFor == widget.levelNumber) return;
    _campaignRevealArmedFor = widget.levelNumber;
    _campaignRevealTimer?.cancel();
    _campaignBoardVisible = false;
    _campaignRevealTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _campaignBoardVisible = true);
    });
  }

  LevelModel get _level {
    if (widget.isDaily) {
      return ref
          .read(levelRepositoryProvider)
          .getDailyLevel(widget.dailyDate ?? DateTime.now());
    }
    return ref.read(levelByNumberProvider(widget.levelNumber));
  }

  DateTime get _dailyPlayDate => widget.dailyDate ?? DateTime.now();

  String get _dailyKey => dailyDateKey(_dailyPlayDate);

  /// Always point at the current free arrow while tutorial is active.
  String? _currentTutorialArrowId(GameState gameState) {
    if (!_tutorialSessionActive || gameState.isWon) return null;
    return findFreeArrow(gameState)?.id;
  }

  void _resetLocalPlayState() {
    _highlightedArrowId = null;
    _shakeTokens.clear();
    _wrongBumpCells.clear();
    _boardZoomed = false;
    _halfwayToastShown = false;
    _halfwayToastVisible = false;
    _halfwayTimer?.cancel();
    _halfwayTimer = null;
    _outOfLivesTimer?.cancel();
    _outOfLivesTimer = null;
    _showOutOfLives = false;
    _winOverlayTimer?.cancel();
    _winOverlayTimer = null;
    _showWinOverlay = false;
  }

  void _scheduleOutOfLivesOverlay() {
    _outOfLivesTimer?.cancel();
    setState(() => _showOutOfLives = false);
    // Heart pulse is ~200ms; wait so last red heart empties first.
    _outOfLivesTimer = Timer(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      setState(() => _showOutOfLives = true);
    });
  }

  void _maybeShowHalfwayToast(GameState gameState) {
    // Mid-level "50% complete" toast starts from Level 11 only.
    if (widget.isDaily || widget.levelNumber < 11) return;
    if (_halfwayToastShown || gameState.isWon || gameState.isLost) return;
    final total = gameState.arrows.length;
    if (total < 2) return;
    final removed = gameState.arrows.where((a) => a.isRemoved).length;
    final half = (total + 1) ~/ 2;
    if (removed < half) return;

    _halfwayToastShown = true;
    _halfwayTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _halfwayToastVisible = true);
      _halfwayTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _halfwayToastVisible = false);
      });
    });
  }

  void _triggerWrongTapFeedback(ArrowModel arrow, GameState gameState) {
    final hit = findFirstBlockingArrow(
      arrow: arrow,
      arrows: gameState.arrows,
      gridRows: gameState.level.gridRows,
      gridCols: gameState.level.gridCols,
      shapeMask: gameState.level.shapeMask,
    );
    setState(() {
      _shakeTokens[arrow.id] = (_shakeTokens[arrow.id] ?? 0) + 1;
      // Leave a small gap so tip visually "touches" rather than overlapping.
      _wrongBumpCells[arrow.id] =
          hit == null ? 0.55 : math.max(0.35, hit.steps - 0.35);
      if (hit != null) {
        _shakeTokens[hit.blocker.id] =
            (_shakeTokens[hit.blocker.id] ?? 0) + 1;
        _wrongBumpCells.remove(hit.blocker.id);
      }
    });
  }

  /// Matches ArrowTile multi-cell exit timing (+ small cushion).
  Duration _escapeWaitFor(ArrowModel arrow) {
    if (!arrow.isMultiCell) {
      return const Duration(milliseconds: 360);
    }
    final pathCells = arrow.path.length.clamp(2, 14);
    final tip = arrow.path.last;
    final level = _level;
    final toEdge = switch (arrow.direction) {
      ArrowDirection.up => tip.row + 1,
      ArrowDirection.down => level.gridRows - tip.row,
      ArrowDirection.left => tip.col + 1,
      ArrowDirection.right => level.gridCols - tip.col,
    };
    final travel = (pathCells + toEdge).clamp(4, 26);
    return Duration(milliseconds: 300 + travel * 30);
  }

  void _scheduleWinOverlay(ArrowModel lastArrow) {
    _winOverlayTimer?.cancel();
    setState(() => _showWinOverlay = false);
    _winOverlayTimer = Timer(_escapeWaitFor(lastArrow), () {
      if (!mounted) return;
      AppFeedback.levelComplete(ref);
      setState(() => _showWinOverlay = true);
    });
  }

  void _onArrowTap(String arrowId) {
    final gameState = ref.read(gameControllerProvider(_level));
    if (gameState.isLost || gameState.isWon) return;

    final index = gameState.arrows.indexWhere((a) => a.id == arrowId);
    if (index == -1) return;

    final arrow = gameState.arrows[index];
    final blocked = isArrowBlocked(
      arrow: arrow,
      arrows: gameState.arrows,
      gridRows: gameState.level.gridRows,
      gridCols: gameState.level.gridCols,
      shapeMask: gameState.level.shapeMask,
    );

    // Tutorial: wrong taps visual only — never lose hearts.
    if (blocked && _tutorialSessionActive) {
      AppFeedback.wrongTap(ref);
      _triggerWrongTapFeedback(arrow, gameState);
      return;
    }

    final controller = ref.read(gameControllerProvider(_level).notifier);
    final result = controller.tapArrow(arrowId);

    if (result == TapArrowResult.wrongTap) {
      AppFeedback.wrongTap(ref);
      _triggerWrongTapFeedback(arrow, gameState);
    } else if (result == TapArrowResult.removed) {
      AppFeedback.arrowTap(ref);
      final next = ref.read(gameControllerProvider(_level));
      if (next.isWon) {
        // Let last arrow finish escaping before Level Complete covers the board.
        _scheduleWinOverlay(arrow);
      }
      _maybeShowHalfwayToast(next);
    }
  }

  void _onHint() {
    final gameState = ref.read(gameControllerProvider(_level));
    if (gameState.isLost || gameState.isWon) return;
    if (gameState.hintsLeft <= 0) return;

    AppFeedback.buttonTap(ref);
    final controller = ref.read(gameControllerProvider(_level).notifier);

    final id = controller.useHint();
    if (id == null) return;

    _hintTimer?.cancel();
    setState(() => _highlightedArrowId = id);
    _hintTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _highlightedArrowId = null);
    });
  }

  Future<void> _onWatchAdForHint() async {
    final gameState = ref.read(gameControllerProvider(_level));
    if (gameState.isLost || gameState.isWon) return;
    if (!ref.read(connectivityProvider)) {
      showOfflineAdNotice(context);
      return;
    }

    final earned = await AdsService.instance.showRewardedForHint(context);
    if (!earned) return;

    AppFeedback.buttonTap(ref);
    ref.read(gameControllerProvider(_level).notifier).grantExtraHint();
  }

  void _onGridBooster() {
    AppFeedback.buttonTap(ref);
    // Toggle board zoom (visibility aid only — no count / cooldown).
    setState(() => _boardZoomed = !_boardZoomed);
  }

  /// Campaign → Main. Daily → Daily hub (pop stack when possible).
  void _leaveToHub() {
    if (widget.isDaily) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(DailyChallengeScreen.routePath);
      }
      return;
    }
    // Back from the win overlay must persist, otherwise Home stays on the
    // old continue level (e.g. completed 1 & 2, Home still says Level 2).
    final won = ref.read(gameControllerProvider(_level)).isWon;
    if (won) {
      unawaited(_saveCampaignThenHome());
      return;
    }
    context.go(HomeScreen.routePath);
  }

  void _notifyCampaignProgress() {
    ref.read(campaignProgressTickProvider.notifier).update((tick) => tick + 1);
    ref.invalidate(currentLevelProvider);
    ref.invalidate(lastCompletedLevelProvider);
  }

  Future<void> _saveCampaignThenHome() async {
    if (widget.levelNumber == 1) {
      await _markTutorialSeen();
    }
    final repo = await ref.read(progressRepositoryProvider.future);
    await repo.saveProgress(widget.levelNumber);
    _notifyCampaignProgress();
    if (!mounted) return;
    context.go(HomeScreen.routePath);
  }

  void _openPauseSheet() {
    final colors = context.appColors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return PauseSheet(
          onResume: () => Navigator.of(sheetContext).pop(),
          onRestart: () {
            Navigator.of(sheetContext).pop();
            ref.read(gameControllerProvider(_level).notifier).resetLevel();
            setState(_resetLocalPlayState);
          },
          onQuit: () {
            Navigator.of(sheetContext).pop();
            AdsService.instance.onReturnToMapAfterFail(context);
            _leaveToHub();
          },
        );
      },
    );
  }

  Future<void> _markDailyIfNeeded() async {
    if (!widget.isDaily) return;
    final repo = await ref.read(progressRepositoryProvider.future);
    await repo.markDailyCompleted(_dailyPlayDate);
    ref.invalidate(monthlyDailyStarsProvider);
    ref.invalidate(completedDailyDatesProvider);
    ref.invalidate(currentStreakProvider);
  }

  Future<void> _onNextGame() async {
    final repo = await ref.read(progressRepositoryProvider.future);
    final levelCount = ref.read(levelRepositoryProvider).levelCount;

    if (widget.isDaily) {
      await _markDailyIfNeeded();
      if (!mounted) return;
      await AdsService.instance.onDailyChallengeCleared(context);
      if (!mounted) return;
      context.go(DailyChallengeScreen.routePath);
      return;
    }

    if (widget.levelNumber == 1) {
      await _markTutorialSeen();
    }

    await repo.saveProgress(widget.levelNumber);
    _notifyCampaignProgress();
    if (!mounted) return;
    await AdsService.instance.onLevelCleared(context);

    if (!mounted) return;

    final nextNumber = _level.levelNumber + 1;
    if (nextNumber > levelCount) {
      context.go(HomeScreen.routePath);
      return;
    }
    context.pushReplacement('${GameplayScreen.routePath}?level=$nextNumber');
  }

  Future<void> _onMainFromComplete() async {
    if (widget.levelNumber == 1 && !_hasSeenTutorial) {
      await _markTutorialSeen();
    }
    final repo = await ref.read(progressRepositoryProvider.future);
    if (widget.isDaily) {
      await _markDailyIfNeeded();
      if (!mounted) return;
      await AdsService.instance.onDailyChallengeCleared(context);
      if (!mounted) return;
      context.go(DailyChallengeScreen.routePath);
      return;
    }
    await repo.saveProgress(widget.levelNumber);
    _notifyCampaignProgress();
    if (!mounted) return;
    await AdsService.instance.onLevelCleared(context);
    if (!mounted) return;
    context.go(HomeScreen.routePath);
  }

  @override
  Widget build(BuildContext context) {
    // Heavy boards (Hard/Expert tiers, 70-200+ arrows) generate on a
    // background isolate via compute() — watch the async provider FIRST so
    // we can show a loading indicator instead of blocking this build() on
    // the main isolate. Once it resolves, the level is cached on the repo,
    // so the sync providers below (used by the rest of this widget, and by
    // every other `_level` call site in this class) return instantly with
    // no further generation work — nothing else in this file needs to
    // change to become isolate-safe.
    if (!_loadFetchStarted) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F3EC),
        body: widget.isDaily
            ? const DailyChallengeLoadingOverlay()
            : DailyChallengeLoadingOverlay.forLevel(
                levelNumber: widget.levelNumber,
              ),
      );
    }

    final levelAsync = widget.isDaily
        ? ref.watch(dailyLevelForDateAsyncProvider(_dailyKey))
        : ref.watch(levelByNumberAsyncProvider(widget.levelNumber));

    // Daily: center dialog — board hidden until generation + 1s soft pause.
    if (widget.isDaily) {
      if (levelAsync.hasError) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6F3EC),
          body: DailyChallengeLoadingOverlay(
            error: true,
            onRetry: () {
              _dailyRevealArmedFor = null;
              _dailyBoardVisible = false;
              _dailyRevealTimer?.cancel();
              ref.invalidate(dailyLevelForDateAsyncProvider(_dailyKey));
            },
          ),
        );
      }
      if (levelAsync.isLoading || !levelAsync.hasValue) {
        return const Scaffold(
          backgroundColor: Color(0xFFF6F3EC),
          body: DailyChallengeLoadingOverlay(),
        );
      }
      if (!_dailyBoardVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _armDailyRevealIfNeeded();
        });
        return const Scaffold(
          backgroundColor: Color(0xFFF6F3EC),
          body: DailyChallengeLoadingOverlay(),
        );
      }
    } else if (widget.levelNumber > 1) {
      // Main levels 2+: same dialog loader + 1.2s soft wait after board ready.
      if (levelAsync.hasError) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6F3EC),
          body: DailyChallengeLoadingOverlay.forLevel(
            levelNumber: widget.levelNumber,
            error: true,
            onRetry: () {
              _campaignRevealArmedFor = null;
              _campaignBoardVisible = false;
              _campaignRevealTimer?.cancel();
              ref.invalidate(levelByNumberAsyncProvider(widget.levelNumber));
            },
          ),
        );
      }
      if (levelAsync.isLoading || !levelAsync.hasValue) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6F3EC),
          body: DailyChallengeLoadingOverlay.forLevel(
            levelNumber: widget.levelNumber,
          ),
        );
      }
      if (!_campaignBoardVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _armCampaignRevealIfNeeded();
        });
        return Scaffold(
          backgroundColor: const Color(0xFFF6F3EC),
          body: DailyChallengeLoadingOverlay.forLevel(
            levelNumber: widget.levelNumber,
          ),
        );
      }
    } else {
      if (levelAsync.isLoading) {
        return const _LevelLoadingView();
      }
      if (levelAsync.hasError) {
        return _LevelLoadingView(
          error: true,
          onRetry: () {
            ref.invalidate(levelByNumberAsyncProvider(widget.levelNumber));
          },
        );
      }
    }

    final level = widget.isDaily
        ? ref.watch(dailyLevelForDateProvider(_dailyKey))
        : ref.watch(levelByNumberProvider(widget.levelNumber));
    final gameState = ref.watch(gameControllerProvider(level));
    final adsAvailable = ref.watch(connectivityProvider);
    final colors = context.appColors;

    ref.listen(gameControllerProvider(level), (previous, next) {
      final wasLost = previous?.isLost ?? false;
      if (next.isLost && !wasLost) {
        _scheduleOutOfLivesOverlay();
      } else if (!next.isLost && wasLost) {
        _outOfLivesTimer?.cancel();
        _outOfLivesTimer = null;
        if (_showOutOfLives) {
          setState(() => _showOutOfLives = false);
        }
      }
    });

    final remainingArrows =
        gameState.arrows.where((arrow) => !arrow.isRemoved).length;
    final tutorialArrowId = _currentTutorialArrowId(gameState);
    final levelCount = ref.watch(levelRepositoryProvider).levelCount;
    final isCampaignComplete =
        !widget.isDaily && level.levelNumber >= levelCount;
    final inTutorial = _tutorialSessionActive && !gameState.isWon;
    final isNestedPlain =
        !inTutorial &&
        (widget.isDaily ||
            (level.levelNumber >= 2 && level.levelNumber <= levelCount));

    final isRateMilestone =
        !widget.isDaily &&
        widget.levelNumber >= 10 &&
        widget.levelNumber % 10 == 0;

    if (!_ratePromptChecked && isRateMilestone) {
      _ratePromptChecked = true;
      ref.read(progressRepositoryProvider.future).then((repo) {
        if (!mounted) return;
        if (repo.hasShownRatePromptForLevel(widget.levelNumber)) {
          setState(() => _ratePromptDone = true);
        }
      });
    }

    if (gameState.isWon &&
        widget.levelNumber == 1 &&
        !widget.isDaily &&
        !_hasSeenTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markTutorialSeen();
      });
    }

    final showRatePrompt = gameState.isWon &&
        _showWinOverlay &&
        isRateMilestone &&
        !_ratePromptDone;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Nested/tutorial: white board plane in light, #0A101A in dark.
    final plainPlane = isDark ? colors.background : Colors.white;
    final scaffoldBg = (inTutorial || isNestedPlain)
        ? plainPlane
        : colors.background;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _leaveToHub();
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: Stack(
        children: [
          if (inTutorial || isNestedPlain)
            Positioned.fill(
              child: ColoredBox(color: plainPlane),
            ),
          SafeArea(
            child: Column(
              children: [
                FadeTransition(
                  opacity: _chromeOpacity,
                  child: _TopRow(
                    title: widget.isDaily
                        ? 'Daily'
                        : 'Level ${level.levelNumber}',
                    onBack: _leaveToHub,
                    onSettings: inTutorial ? null : _openPauseSheet,
                    minimal: inTutorial,
                  ),
                ),
                if (!inTutorial) ...[
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _chromeOpacity,
                    child: _LevelProgressBar(
                      progress: level.arrows.isEmpty
                          ? 0
                          : (level.arrows.length - remainingArrows) /
                              level.arrows.length,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _chromeOpacity,
                    child: _StatsRow(
                      remainingArrows: remainingArrows,
                      heartsLeft: gameState.heartsLeft,
                      heartsAllowed: level.heartsAllowed,
                      difficulty: level.difficulty,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else
                  const Spacer(flex: 2),
                Expanded(
                  flex: inTutorial ? 3 : 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isNestedPlain ? 20 : 12,
                      vertical: isNestedPlain ? 6 : 0,
                    ),
                    child: GameBoard(
                      gameState: gameState,
                      highlightedArrowId: _highlightedArrowId,
                      tutorialArrowId: tutorialArrowId,
                      showTutorialTip: tutorialArrowId != null,
                      plainTutorial: inTutorial,
                      plainBoard: isNestedPlain,
                      // Level 2+: spinner covers load; show full board at once.
                      // Level 1 keeps staggered entrance; Daily never uses it.
                      playEntrance: !widget.isDaily && widget.levelNumber == 1,
                      boardZoomed: _boardZoomed,
                      shakeTokens: Map<String, int>.from(_shakeTokens),
                      wrongBumpCells: Map<String, double>.from(_wrongBumpCells),
                      onArrowTap: _onArrowTap,
                    ),
                  ),
                ),
                if (inTutorial) const Spacer(flex: 2),
                if (!inTutorial) ...[
                  _BottomActions(
                    hintsLeft: gameState.hintsLeft,
                    adsAvailable: adsAvailable,
                    onHint: _onHint,
                    onWatchAdForHint: _onWatchAdForHint,
                    onGridBooster: _onGridBooster,
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
          if (_halfwayToastVisible &&
              !gameState.isWon &&
              !gameState.isLost &&
              !showRatePrompt)
            Positioned(
              // Sit under Level title / hearts — not mid-screen.
              top: MediaQuery.paddingOf(context).top + 52,
              left: 0,
              right: 0,
              child: const HalfwayCompleteToast(),
            ),
          if (_showOutOfLives)
            OutOfLivesOverlay(
              adsAvailable: adsAvailable,
              onRestart: () {
                ref.read(gameControllerProvider(level).notifier).resetLevel();
                setState(_resetLocalPlayState);
              },
              onWatchAd: () async {
                final earned =
                    await AdsService.instance.showRewardedForLives(context);
                if (earned) {
                  ref
                      .read(gameControllerProvider(level).notifier)
                      .grantExtraLife();
                  setState(_resetLocalPlayState);
                }
              },
            ),
          if (showRatePrompt)
            RateGameDialog(
              onDismiss: _finishRatePrompt,
              onLowStars: _finishRatePrompt,
              onFiveStars: () async {
                await _openPlayStoreListing();
                await _finishRatePrompt();
              },
            )
          else if (gameState.isWon && _showWinOverlay)
            LevelCompletedOverlay(
              completedLevel: level.levelNumber,
              nextLevelNumber: level.levelNumber + 1,
              previewArrows: List<ArrowModel>.from(level.arrows),
              gridRows: level.gridRows,
              gridCols: level.gridCols,
              heartsLeft: gameState.heartsLeft,
              heartsAllowed: level.heartsAllowed,
              isCampaignComplete: isCampaignComplete,
              isDaily: widget.isDaily,
              onNextGame: _onNextGame,
              onMain: _onMainFromComplete,
            ),
        ],
      ),
    ),
    );
  }

  Future<void> _openPlayStoreListing() async {
    final market = Uri.parse(
      'market://details?id=${AppConstants.applicationId}',
    );
    final https = Uri.parse(AppConstants.playStoreListingUrl);
    try {
      if (await canLaunchUrl(market)) {
        await launchUrl(market, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (await canLaunchUrl(https)) {
      await launchUrl(https, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _finishRatePrompt() async {
    final repo = await ref.read(progressRepositoryProvider.future);
    await repo.setHasShownRatePromptForLevel(widget.levelNumber);
    if (!mounted) return;
    setState(() => _ratePromptDone = true);
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.title,
    required this.onBack,
    required this.onSettings,
    this.minimal = false,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onSettings;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (minimal) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.primaryText,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.chevron_left_rounded,
              size: 32,
              color: colors.primaryText,
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.primaryText,
              ),
            ),
          ),
          IconButton(
            onPressed: onSettings,
            icon: Icon(
              Icons.settings_rounded,
              size: 24,
              color: colors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelProgressBar extends StatelessWidget {
  const _LevelProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clamped = progress.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 3,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  ColoredBox(
                    color: isDark ? colors.border : const Color(0xFFEDE8DC),
                    child: const SizedBox.expand(),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * clamped,
                    height: 3,
                    color: const Color(0xFF2EC4A6),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatefulWidget {
  const _StatsRow({
    required this.remainingArrows,
    required this.heartsLeft,
    required this.heartsAllowed,
    required this.difficulty,
  });

  final int remainingArrows;
  final int heartsLeft;
  final int heartsAllowed;
  final LevelDifficulty difficulty;

  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow>
    with SingleTickerProviderStateMixin {
  late int _prevHearts;
  int? _pulseIndex;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _prevHearts = widget.heartsLeft;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _pulseIndex = null);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _StatsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.heartsLeft < _prevHearts) {
      // Rightmost heart that just emptied (0-based fill from left).
      setState(() => _pulseIndex = widget.heartsLeft);
      _pulseController.forward(from: 0);
    }
    _prevHearts = widget.heartsLeft;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final totalHearts = widget.heartsAllowed.clamp(1, 5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Pill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🚀', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  '${widget.remainingArrows}',
                  style: AppTextStyles.label(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(totalHearts, (index) {
                  final filled = index < widget.heartsLeft;
                  final pulsing = _pulseIndex == index;
                  final icon = Icon(
                    Icons.favorite_rounded,
                    size: 22,
                    color: filled
                        ? colors.heartRed
                        : colors.border.withValues(alpha: 0.85),
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: pulsing
                        ? Transform.scale(
                            scale: _pulseScale.value,
                            child: icon,
                          )
                        : icon,
                  );
                }),
              );
            },
          ),
          const Spacer(),
          _DifficultyChip(label: widget.difficulty.label),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: child,
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2FBF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9F5EE), width: 1),
      ),
      child: Text(
        label,
        style: AppTextStyles.label(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F8F7A),
        ),
      ),
    );
  }
}

class _BottomActions extends StatefulWidget {
  const _BottomActions({
    required this.hintsLeft,
    required this.adsAvailable,
    required this.onHint,
    required this.onWatchAdForHint,
    required this.onGridBooster,
  });

  final int hintsLeft;
  final bool adsAvailable;
  final VoidCallback onHint;
  final VoidCallback onWatchAdForHint;
  final VoidCallback onGridBooster;

  @override
  State<_BottomActions> createState() => _BottomActionsState();
}

class _BottomActionsState extends State<_BottomActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hintShakeController;
  late final Animation<double> _hintShake;

  @override
  void initState() {
    super.initState();
    _hintShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _hintShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 5, end: -4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _hintShakeController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _hintShakeController.dispose();
    super.dispose();
  }

  void _onHintTap() {
    if (widget.hintsLeft <= 0) {
      if (!widget.adsAvailable) {
        showOfflineAdNotice(context);
        return;
      }
      _hintShakeController.forward(from: 0);
      widget.onWatchAdForHint();
      return;
    }
    widget.onHint();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hintsEmpty = widget.hintsLeft <= 0;
    final adHintOffline = hintsEmpty && !widget.adsAvailable;

    Widget hintFab = _ActionFab(
      onTap: _onHintTap,
      child: Badge(
        isLabelVisible: true,
        backgroundColor:
            adHintOffline ? colors.border : colors.accentTealDeep,
        label: Text(
          hintsEmpty ? 'AD' : '${widget.hintsLeft}',
          style: AppTextStyles.label(
            fontSize: 10,
            color: Colors.white,
          ),
        ),
        child: Icon(
          Icons.lightbulb_rounded,
          color: adHintOffline ? colors.secondaryText : colors.primaryText,
        ),
      ),
    );
    if (adHintOffline) {
      hintFab = Opacity(opacity: 0.45, child: hintFab);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _hintShakeController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_hintShake.value, 0),
                child: child,
              );
            },
            child: hintFab,
          ),
          const Spacer(),
          _ActionFab(
            onTap: widget.onGridBooster,
            child: Icon(
              Icons.grid_view_rounded,
              color: colors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionFab extends StatelessWidget {
  const _ActionFab({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? colors.surface2 : Colors.white,
            shape: BoxShape.circle,
            border: isDark ? Border.all(color: colors.border) : null,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0E1726)
                    .withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Shown while a level generates on the background isolate (see
/// `LevelRepository.getLevelAsync`/`getDailyLevelAsync`). Hard/Expert
/// boards can carry 70-200+ arrows, so generation is no longer done
/// synchronously on the UI isolate — this replaces what would otherwise be
/// a multi-hundred-millisecond freeze on level open. Same dark-gradient
/// look as the splash/no-internet screens for visual consistency.
class _LevelLoadingView extends StatelessWidget {
  const _LevelLoadingView({this.error = false, this.onRetry});

  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1726),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.1,
            colors: [
              Color(0xFF173049),
              Color(0xFF0E1726),
              Color(0xFF090F18),
            ],
            stops: [0.0, 0.58, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: error
                  ? [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 40,
                        color: Color(0xFF9DB0C4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Could not build this level',
                        style: AppTextStyles.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentTeal,
                          foregroundColor: const Color(0xFF0A2430),
                        ),
                        child: const Text('Retry'),
                      ),
                    ]
                  : [
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.accentTeal),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Building your puzzle…',
                        style: AppTextStyles.body(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9DB0C4),
                        ),
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}
