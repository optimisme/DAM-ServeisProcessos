import 'package:flutter/material.dart';
import 'package:game_example/gameplay/game_screen.dart';
import 'package:game_example/menu/level_menu_screen.dart';

void main() {
  runApp(const GamesToolExampleApp());
}

class GamesToolExampleApp extends StatelessWidget {
  const GamesToolExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Games Tool',
      theme: ThemeData.dark(),
      home: LevelMenuScreen(
        onLevelSelected:
            (
              BuildContext ctx,
              String projectRoot,
              String levelName,
              int levelIndex,
            ) {
              Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => GameScreen(
                    projectRoot: projectRoot,
                    levelName: levelName,
                    levelIndexFallback: levelIndex,
                  ),
                ),
              );
            },
      ),
    );
  }
}
