import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/providers/connectivity_provider.dart';
import 'package:arrow_drift/core/services/app_feedback.dart';
import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/core/utils/online_gate.dart';
import 'package:arrow_drift/data/models/arrow_model.dart';
import 'package:arrow_drift/data/models/game_state.dart';
import 'package:arrow_drift/data/models/level_model.dart';
import 'package:arrow_drift/data/repositories/level_repository.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/data/repositories/shape_masks.dart';
import 'package:arrow_drift/data/repositories/synthetic_arrows.dart';
import 'package:arrow_drift/features/daily_challenge/daily_loading_view.dart';
import 'package:arrow_drift/features/gameplay/game_controller.dart';
import 'package:arrow_drift/features/gameplay/widgets/game_board.dart';
import 'package:arrow_drift/features/gameplay/widgets/game_bottom_actions.dart';
import 'package:arrow_drift/features/gameplay/widgets/game_stats_row.dart';
import 'package:arrow_drift/features/gameplay/widgets/game_top_row.dart';
import 'package:arrow_drift/features/gameplay/widgets/level_completed_overlay.dart';
import 'package:arrow_drift/features/gameplay/widgets/out_of_lives_overlay.dart';
import 'package:arrow_drift/features/gameplay/widgets/pause_sheet.dart';
import 'package:arrow_drift/services/ads_service.dart';

/// Pattern preview. Levels 1–100 are real nested puzzles via GameController.
class PatternPreviewScreen extends ConsumerStatefulWidget {
  const PatternPreviewScreen({super.key, required this.levelNumber});

  static const String routePath = '/patterns/preview';

  final int levelNumber;

  @override
  ConsumerState<PatternPreviewScreen> createState() =>
      _PatternPreviewScreenState();
}

class _PatternPreviewScreenState extends ConsumerState<PatternPreviewScreen> {
  bool _boardZoomed = false;
  bool _loading = true;
  Object? _loadError;

  /// Loaded nested LevelModel for playable levels 1–100.
  LevelModel? _playLevel;

  /// Static board fallback when no loader exists (levels 101+).
  GameState? _previewState;

  String? _highlightedArrowId;
  final Map<String, int> _shakeTokens = {};
  final Map<String, double> _wrongBumpCells = {};
  Timer? _hintTimer;
  Timer? _outOfLivesTimer;
  Timer? _winOverlayTimer;
  bool _showOutOfLives = false;
  bool _showWinOverlay = false;
  bool _didPersistWin = false;

  bool get _isPlayable =>
      widget.levelNumber >= 1 && widget.levelNumber <= 100;

  @override
  void initState() {
    super.initState();
    if (widget.levelNumber >= 1 && widget.levelNumber <= 100) {
      _loadBoard();
    } else {
      _loading = false;
      _previewState = _buildHeartPreviewPlaceholder();
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _outOfLivesTimer?.cancel();
    _winOverlayTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBoard() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _previewState = null;
      _playLevel = null;
    });
    try {
      final loader = patternLevelLoaders[widget.levelNumber];
      if (loader != null) {
        final level = await loader();
        if (!mounted) return;
        ref.invalidate(gameControllerProvider(level));
        setState(() {
          _playLevel = level;
          _loading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _previewState = _buildHeartPreviewPlaceholder();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  void _resetLocalPlayState() {
    _highlightedArrowId = null;
    _shakeTokens.clear();
    _wrongBumpCells.clear();
    _boardZoomed = false;
    _outOfLivesTimer?.cancel();
    _outOfLivesTimer = null;
    _showOutOfLives = false;
    _winOverlayTimer?.cancel();
    _winOverlayTimer = null;
    _showWinOverlay = false;
    _didPersistWin = false;
  }

  void _leaveToPatterns() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _scheduleOutOfLivesOverlay() {
    _outOfLivesTimer?.cancel();
    setState(() => _showOutOfLives = false);
    _outOfLivesTimer = Timer(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      setState(() => _showOutOfLives = true);
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
      _wrongBumpCells[arrow.id] =
          hit == null ? 0.55 : math.max(0.35, hit.steps - 0.35);
      if (hit != null) {
        _shakeTokens[hit.blocker.id] =
            (_shakeTokens[hit.blocker.id] ?? 0) + 1;
        _wrongBumpCells.remove(hit.blocker.id);
      }
    });
  }

  Duration _escapeWaitFor(ArrowModel arrow, LevelModel level) {
    if (!arrow.isMultiCell) {
      return const Duration(milliseconds: 360);
    }
    final pathCells = arrow.path.length.clamp(2, 14);
    final tip = arrow.path.last;
    final toEdge = switch (arrow.direction) {
      ArrowDirection.up => tip.row + 1,
      ArrowDirection.down => level.gridRows - tip.row,
      ArrowDirection.left => tip.col + 1,
      ArrowDirection.right => level.gridCols - tip.col,
    };
    final travel = (pathCells + toEdge).clamp(4, 26);
    return Duration(milliseconds: 300 + travel * 30);
  }

  void _scheduleWinOverlay(ArrowModel lastArrow, LevelModel level) {
    _winOverlayTimer?.cancel();
    setState(() => _showWinOverlay = false);
    _winOverlayTimer = Timer(_escapeWaitFor(lastArrow, level), () {
      if (!mounted) return;
      AppFeedback.levelComplete(ref);
      setState(() => _showWinOverlay = true);
    });
  }

  Future<void> _persistPatternClear() async {
    if (_didPersistWin) return;
    _didPersistWin = true;
    final repo = await ref.read(progressRepositoryProvider.future);
    await repo.markPatternCompleted(widget.levelNumber);
    await repo.addCoins(30);
    if (mounted) await AdsService.instance.onCustomLevelCleared(context);
    ref.read(patternProgressTickProvider.notifier).update((tick) => tick + 1);
  }

  void _onArrowTap(String arrowId, LevelModel level) {
    final gameState = ref.read(gameControllerProvider(level));
    if (gameState.isLost || gameState.isWon) return;

    final index = gameState.arrows.indexWhere((a) => a.id == arrowId);
    if (index == -1) return;

    final arrow = gameState.arrows[index];
    final controller = ref.read(gameControllerProvider(level).notifier);
    final result = controller.tapArrow(arrowId);

    if (result == TapArrowResult.wrongTap) {
      AppFeedback.wrongTap(ref);
      _triggerWrongTapFeedback(arrow, gameState);
    } else if (result == TapArrowResult.removed) {
      AppFeedback.arrowTap(ref);
      final next = ref.read(gameControllerProvider(level));
      if (next.isWon) {
        unawaited(_persistPatternClear());
        _scheduleWinOverlay(arrow, level);
      }
    }
  }

  void _onHint(LevelModel level) {
    final gameState = ref.read(gameControllerProvider(level));
    if (gameState.isLost || gameState.isWon) return;
    if (gameState.hintsLeft <= 0) return;

    AppFeedback.buttonTap(ref);
    final controller = ref.read(gameControllerProvider(level).notifier);

    final id = controller.useHint();
    if (id == null) return;

    _hintTimer?.cancel();
    setState(() => _highlightedArrowId = id);
    _hintTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _highlightedArrowId = null);
    });
  }

  Future<void> _onWatchAdForHint(LevelModel level) async {
    final gameState = ref.read(gameControllerProvider(level));
    if (gameState.isLost || gameState.isWon) return;
    if (!ref.read(connectivityProvider)) {
      showOfflineAdNotice(context);
      return;
    }

    final earned = await AdsService.instance.showRewardedForHint(context);
    if (!earned) return;

    AppFeedback.buttonTap(ref);
    ref.read(gameControllerProvider(level).notifier).grantExtraHint();
  }

  void _onGridBooster() {
    AppFeedback.buttonTap(ref);
    setState(() => _boardZoomed = !_boardZoomed);
  }

  void _openPauseSheet(LevelModel level) {
    final colors = context.appColors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return PauseSheet(
          quitLabel: 'Quit to Custom',
          onResume: () => Navigator.of(sheetContext).pop(),
          onRestart: () {
            Navigator.of(sheetContext).pop();
            ref.read(gameControllerProvider(level).notifier).resetLevel();
            setState(_resetLocalPlayState);
          },
          onQuit: () {
            Navigator.of(sheetContext).pop();
            _leaveToPatterns();
          },
        );
      },
    );
  }

  void _onNextPattern() {
    if (widget.levelNumber >= 100) {
      _leaveToPatterns();
      return;
    }
    context.pushReplacement(
      PatternPreviewScreen.routePath,
      extra: widget.levelNumber + 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const paletteBlue = Color(0xFF4C7EF3);

    final playLevel = _playLevel;
    if (_isPlayable && !_loading && _loadError == null && playLevel != null) {
      return _buildPlayable(
        context,
        playLevel,
        colors: colors,
        isDark: isDark,
        paletteBlue: paletteBlue,
      );
    }

    final preview = _previewState;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          gradient: RadialGradient(
            center: const Alignment(0.85, -0.85),
            radius: 1.1,
            colors: [
              colors.accentTeal.withValues(alpha: 0.14),
              colors.background,
            ],
            stops: const [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              GameTopRow(
                title: 'Level ${widget.levelNumber}',
                onBack: () => context.pop(),
                onSettings: () {},
              ),
              if (_loading || _loadError != null || preview == null)
                Expanded(
                  child: DailyChallengeLoadingOverlay.forLevel(
                    levelNumber: widget.levelNumber,
                    error: _loadError != null,
                    onRetry: _loadBoard,
                  ),
                )
              else ...[
                const SizedBox(height: 6),
                GameStatsRow(
                  remainingArrows: preview.arrows
                      .where((a) => !a.isRemoved)
                      .length,
                  heartsLeft: 3,
                  heartsAllowed: 3,
                  difficulty: preview.level.difficulty,
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GameBoard(
                      gameState: preview,
                      onArrowTap: (_) {},
                      boardZoomed: _boardZoomed,
                      hideDots: true,
                      patternBoardChrome: true,
                      boldFactor: 1.65,
                      boardBackgroundOverride: colors.background,
                      arrowColorResolver: (_, index) {
                        final palette = [
                          colors.accentTeal,
                          colors.gold,
                          colors.heartRed,
                          paletteBlue,
                        ];
                        return palette[index % palette.length];
                      },
                    ),
                  ),
                ),
                GameBottomActions(
                  hintsLeft: 2,
                  adsAvailable: true,
                  onHint: () {},
                  onWatchAdForHint: () {},
                  onGridBooster: () {
                    setState(() => _boardZoomed = !_boardZoomed);
                  },
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayable(
    BuildContext context,
    LevelModel level, {
    required AppColorScheme colors,
    required bool isDark,
    required Color paletteBlue,
  }) {
    final gameState = ref.watch(gameControllerProvider(level));
    final adsAvailable = ref.watch(connectivityProvider);

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

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          gradient: RadialGradient(
            center: const Alignment(0.85, -0.85),
            radius: 1.1,
            colors: [
              colors.accentTeal.withValues(alpha: 0.14),
              colors.background,
            ],
            stops: const [0.0, 0.45],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  GameTopRow(
                    title: 'Level ${widget.levelNumber}',
                    onBack: _leaveToPatterns,
                    onSettings: () => _openPauseSheet(level),
                  ),
                  const SizedBox(height: 6),
                  GameStatsRow(
                    remainingArrows: remainingArrows,
                    heartsLeft: gameState.heartsLeft,
                    heartsAllowed: level.heartsAllowed,
                    difficulty: level.difficulty,
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GameBoard(
                        gameState: gameState,
                        highlightedArrowId: _highlightedArrowId,
                        tutorialArrowId: _highlightedArrowId,
                        showTutorialTip: false,
                        boardZoomed: _boardZoomed,
                        shakeTokens: Map<String, int>.from(_shakeTokens),
                        wrongBumpCells:
                            Map<String, double>.from(_wrongBumpCells),
                        hideDots: true,
                        patternBoardChrome: true,
                        boldFactor: 1.65,
                        boardBackgroundOverride: colors.background,
                        arrowColorResolver: (_, index) {
                          final palette = [
                            colors.accentTeal,
                            colors.gold,
                            colors.heartRed,
                            paletteBlue,
                          ];
                          return palette[index % palette.length];
                        },
                        onArrowTap: (id) => _onArrowTap(id, level),
                      ),
                    ),
                  ),
                  GameBottomActions(
                    hintsLeft: gameState.hintsLeft,
                    adsAvailable: adsAvailable,
                    onHint: () => _onHint(level),
                    onWatchAdForHint: () => _onWatchAdForHint(level),
                    onGridBooster: _onGridBooster,
                  ),
                  const SizedBox(height: 6),
                ],
              ),
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
            if (gameState.isWon && _showWinOverlay)
              LevelCompletedOverlay(
                completedLevel: widget.levelNumber,
                nextLevelNumber: widget.levelNumber + 1,
                previewArrows: List<ArrowModel>.from(level.arrows),
                gridRows: level.gridRows,
                gridCols: level.gridCols,
                heartsLeft: gameState.heartsLeft,
                heartsAllowed: level.heartsAllowed,
                onNextGame: _onNextPattern,
                onMain: _leaveToPatterns,
              ),
          ],
        ),
      ),
    );
  }
}

/// Fallback placeholder when no pattern loader is registered.
GameState _buildHeartPreviewPlaceholder() {
  const size = 12;
  final mask = generateHeartShapeMask(size);
  final arrows = buildSyntheticDecorativeArrows(mask);

  final level = LevelModel(
    levelNumber: 909999,
    gridRows: size,
    gridCols: size,
    arrows: arrows,
    heartsAllowed: 3,
    hintsAllowed: 2,
    difficulty: LevelDifficulty.easy,
    shapeMask: mask,
  );

  return GameState(
    level: level,
    arrows: arrows,
    heartsLeft: 3,
    hintsLeft: 2,
  );
}
