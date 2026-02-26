import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_example/utils_flame/utils_flame.dart';
import 'package:game_example/gameplay/level_game.dart';

/// Full-screen widget that runs a Games Tool level inside a [GameWidget].
///
/// Displays a back-button overlay so the user can return to the menu.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.projectRoot,
    required this.levelIndex,
    this.viewportMode = GamesToolViewportMode.fromGameData,
  });

  final String projectRoot;
  final int levelIndex;
  final GamesToolViewportMode viewportMode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final LevelGame _game;

  @override
  void initState() {
    super.initState();
    _game = LevelGame(
      projectRoot: widget.projectRoot,
      levelIndex: widget.levelIndex,
      viewportMode: widget.viewportMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          GameWidget<LevelGame>(
            game: _game,
            errorBuilder: (BuildContext ctx, Object error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load level:\n$error',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
