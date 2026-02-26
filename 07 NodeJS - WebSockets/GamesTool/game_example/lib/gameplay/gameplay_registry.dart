import 'common/hero_movement_module.dart';
import 'core/level_registry.dart';
import 'levels/level_001_actions_module.dart';
import 'levels/level_002_actions_module.dart';

GameplayLevelRegistry buildDefaultGameplayRegistry() {
  return const GameplayLevelRegistry(
    commonModuleFactories: <GameplayModuleFactory>[HeroMovementModule.new],
    levelModuleFactoriesByIndex: <int, List<GameplayModuleFactory>>{
      0: <GameplayModuleFactory>[Level001ActionsModule.new],
      1: <GameplayModuleFactory>[Level002ActionsModule.new],
    },
  );
}
