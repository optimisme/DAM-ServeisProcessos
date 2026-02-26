import 'package:game_example/utils_gt/utils_gt.dart';

import 'gameplay_module.dart';

typedef GameplayModuleFactory = GameplayModule Function();

/// Registry of common and per-level gameplay modules.
class GameplayLevelRegistry {
  const GameplayLevelRegistry({
    this.commonModuleFactories = const <GameplayModuleFactory>[],
    this.levelModuleFactoriesByIndex =
        const <int, List<GameplayModuleFactory>>{},
    this.levelModuleFactoriesByName =
        const <String, List<GameplayModuleFactory>>{},
  });

  final List<GameplayModuleFactory> commonModuleFactories;
  final Map<int, List<GameplayModuleFactory>> levelModuleFactoriesByIndex;
  final Map<String, List<GameplayModuleFactory>> levelModuleFactoriesByName;

  List<GameplayModuleFactory> moduleFactoriesForLevel({
    required int levelIndex,
    required String levelName,
  }) {
    final String key = normalizeLevelKey(levelName);
    return <GameplayModuleFactory>[
      ...commonModuleFactories,
      ...?levelModuleFactoriesByIndex[levelIndex],
      ...?levelModuleFactoriesByName[key],
    ];
  }

  int resolveLevelIndexByName({
    required GamesToolLoadedProject loadedProject,
    required String levelName,
  }) {
    final String requested = normalizeLevelKey(levelName);
    final List<GamesToolLevel> levels = loadedProject.project.levels;
    final int index = levels.indexWhere(
      (GamesToolLevel level) => normalizeLevelKey(level.name) == requested,
    );
    if (index >= 0) return index;

    final String available = levels
        .map((GamesToolLevel e) => e.name)
        .join(', ');
    throw StateError(
      'Level "$levelName" not found in project "${loadedProject.project.name}". '
      'Available levels: $available',
    );
  }
}

String normalizeLevelKey(String value) => value.trim().toLowerCase();
