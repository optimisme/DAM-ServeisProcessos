import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:game_example/gameplay/core/gameplay_module.dart';
import 'package:game_example/gameplay/core/level_registry.dart';
import 'package:game_example/gameplay/core/loading_state.dart';
import 'package:game_example/gameplay/gameplay_registry.dart';
import 'package:game_example/utils_flame/utils_flame.dart';
import 'package:game_example/utils_gt/utils_gt.dart';

/// A [FlameGame] that loads and runs a single Games Tool level.
///
/// After [onLoad] completes, [mountResult] holds the fully resolved level data,
/// sprite handles, viewport mode, and viewport origin.
class LevelGame extends FlameGame {
  static const String loadingOverlayId = 'level_loading';
  static const String decorationsCounterOverlayId = 'decorations_counter';
  static const Duration minimumLoadingDuration = Duration(seconds: 1);

  LevelGame({
    required this.projectRoot,
    this.initialLevelName,
    this.initialLevelIndex = 0,
    this.viewportMode = GamesToolViewportMode.fromGameData,
    GameplayLevelRegistry? gameplayRegistry,
    GamesToolFlameLoader? loader,
    GamesToolProjectRepository? repository,
  }) : _loader = loader ?? GamesToolFlameLoader(),
       _repository = repository ?? GamesToolProjectRepository(),
       gameplayRegistry = gameplayRegistry ?? buildDefaultGameplayRegistry();

  final String projectRoot;
  final String? initialLevelName;
  final int initialLevelIndex;
  final GamesToolViewportMode viewportMode;
  final GameplayLevelRegistry gameplayRegistry;
  final GamesToolFlameLoader _loader;
  final GamesToolProjectRepository _repository;

  final ValueNotifier<LevelLoadingState> loadingState = ValueNotifier(
    const LevelLoadingState.hidden(),
  );

  final ValueNotifier<int> removedDecorationsCount = ValueNotifier(0);

  GamesToolLoadedProject? _loadedProject;
  bool _isLoadingLevel = false;
  int? currentLevelIndex;
  GamesToolFlameMountResult? mountResult;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final GamesToolLoadedProject loadedProject = await _ensureProjectLoaded();
    if (initialLevelName != null && initialLevelName!.trim().isNotEmpty) {
      await loadLevelByName(initialLevelName!.trim());
      return;
    }

    if (loadedProject.project.levels.isEmpty) {
      throw StateError(
        'Project "${loadedProject.project.name}" has no levels.',
      );
    }
    final int lastIndex = loadedProject.project.levels.length - 1;
    final int safeIndex = initialLevelIndex.clamp(0, lastIndex);
    await loadLevelByIndex(safeIndex);
  }

  @override
  void onRemove() {
    loadingState.dispose();
    removedDecorationsCount.dispose();
    super.onRemove();
  }

  Future<void> loadLevelByName(String levelName) async {
    final GamesToolLoadedProject loadedProject = await _ensureProjectLoaded();
    final int levelIndex = gameplayRegistry.resolveLevelIndexByName(
      loadedProject: loadedProject,
      levelName: levelName,
    );
    await loadLevelByIndex(levelIndex);
  }

  Future<void> loadLevelByIndex(int levelIndex) async {
    if (_isLoadingLevel) return;
    _isLoadingLevel = true;

    final GamesToolLoadedProject loadedProject = await _ensureProjectLoaded();
    final List<GamesToolLevel> levels = loadedProject.project.levels;
    RangeError.checkValidIndex(levelIndex, levels, 'levelIndex');

    final Stopwatch stopwatch = Stopwatch()..start();
    final Future<void> minDelay = Future<void>.delayed(minimumLoadingDuration);
    double stageProgress = 0.05;
    String message = 'Loading level...';
    _setLoadingState(
      isVisible: true,
      progress: stageProgress,
      message: message,
    );

    final Timer timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final double timedProgress =
          (stopwatch.elapsedMilliseconds /
                  minimumLoadingDuration.inMilliseconds)
              .clamp(0.0, 1.0) *
          0.9;
      _setLoadingState(
        isVisible: true,
        progress: math.max(stageProgress, timedProgress),
        message: message,
      );
    });

    try {
      message = 'Mounting "${levels[levelIndex].name}"...';
      stageProgress = 0.2;
      _setLoadingState(
        isVisible: true,
        progress: stageProgress,
        message: message,
      );

      final GamesToolFlameMountResult result = await _loader.mountLoadedLevel(
        game: this,
        loadedProject: loadedProject,
        levelIndex: levelIndex,
        viewportMode: viewportMode,
      );

      stageProgress = 0.75;
      message = 'Starting gameplay...';
      _setLoadingState(
        isVisible: true,
        progress: stageProgress,
        message: message,
      );
      await _runGameplayModules(result);
      mountResult = result;
      currentLevelIndex = levelIndex;

      stageProgress = 0.9;
      message = 'Finalizing...';
      _setLoadingState(
        isVisible: true,
        progress: stageProgress,
        message: message,
      );
      await minDelay;

      _setLoadingState(isVisible: true, progress: 1.0, message: 'Ready');
      await Future<void>.delayed(const Duration(milliseconds: 120));
    } finally {
      timer.cancel();
      stopwatch.stop();
      _setLoadingState(isVisible: false, progress: 0, message: '');
      if (!overlays.isActive(decorationsCounterOverlayId)) {
        overlays.add(decorationsCounterOverlayId);
      }
      _isLoadingLevel = false;
    }
  }

  Future<GamesToolLoadedProject> _ensureProjectLoaded() async {
    if (_loadedProject != null) return _loadedProject!;
    final GamesToolProjectRootResolution resolution = await _loader
        .resolveProjectRoot(preferredRoot: projectRoot);
    _loadedProject = await _repository.loadFromAssets(
      projectRoot: resolution.resolvedRoot,
      strict: true,
    );
    return _loadedProject!;
  }

  Future<void> _runGameplayModules(GamesToolFlameMountResult result) async {
    final List<GameplayModuleFactory> factories = gameplayRegistry
        .moduleFactoriesForLevel(
          levelIndex: result.levelIndex,
          levelName: result.level.name,
        );
    final GameplayContext context = GameplayContext(
      game: this,
      mountResult: result,
    );
    for (final GameplayModuleFactory factory in factories) {
      final GameplayModule module = factory();
      await module.onLevelMounted(context);
    }
  }

  void _setLoadingState({
    required bool isVisible,
    required double progress,
    required String message,
  }) {
    final double safeProgress = progress.clamp(0.0, 1.0);
    loadingState.value = LevelLoadingState(
      isVisible: isVisible,
      progress: safeProgress,
      message: message,
    );
    if (isVisible) {
      if (!overlays.isActive(loadingOverlayId)) {
        overlays.add(loadingOverlayId);
      }
      return;
    }
    if (overlays.isActive(loadingOverlayId)) {
      overlays.remove(loadingOverlayId);
    }
  }
}
