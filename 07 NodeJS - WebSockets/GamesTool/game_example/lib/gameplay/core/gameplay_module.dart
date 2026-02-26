import 'package:flame/game.dart';
import 'package:game_example/utils_flame/utils_flame.dart';

/// Read-only context passed to gameplay modules after a level is mounted.
class GameplayContext {
  const GameplayContext({required this.game, required this.mountResult});

  final FlameGame game;
  final GamesToolFlameMountResult mountResult;

  String get levelName => mountResult.level.name;
  int get levelIndex => mountResult.levelIndex;
}

/// Unit of gameplay logic that can be shared across levels or be level-specific.
abstract class GameplayModule {
  const GameplayModule();

  Future<void> onLevelMounted(GameplayContext context);
}
