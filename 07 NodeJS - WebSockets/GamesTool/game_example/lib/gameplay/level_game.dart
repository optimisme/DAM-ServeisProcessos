import 'package:flame/game.dart';
import 'package:game_example/utils_flame/utils_flame.dart';

/// A [FlameGame] that loads and runs a single Games Tool level.
///
/// After [onLoad] completes, [mountResult] holds the fully resolved level data,
/// sprite handles, viewport mode, and viewport origin.
class LevelGame extends FlameGame {
  LevelGame({
    required this.projectRoot,
    required this.levelIndex,
    this.viewportMode = GamesToolViewportMode.fromGameData,
    GamesToolFlameLoader? loader,
  }) : _loader = loader ?? GamesToolFlameLoader();

  final String projectRoot;
  final int levelIndex;
  final GamesToolViewportMode viewportMode;
  final GamesToolFlameLoader _loader;

  GamesToolFlameMountResult? mountResult;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    mountResult = await _loader.mountLevel(
      game: this,
      projectRoot: projectRoot,
      levelIndex: levelIndex,
      viewportMode: viewportMode,
    );
  }
}
