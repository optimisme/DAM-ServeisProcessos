import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_example/gameplay/core/loading_state.dart';
import 'package:game_example/utils_flame/utils_flame.dart';
import 'package:game_example/gameplay/level_game.dart';

/// Full-screen widget that runs a Games Tool level inside a [GameWidget].
///
/// Displays a back-button overlay so the user can return to the menu.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.projectRoot,
    required this.levelName,
    required this.levelIndexFallback,
    this.viewportMode = GamesToolViewportMode.fromGameData,
  });

  final String projectRoot;
  final String levelName;
  final int levelIndexFallback;
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
      initialLevelName: widget.levelName,
      initialLevelIndex: widget.levelIndexFallback,
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
            loadingBuilder: (BuildContext context) =>
                _GameWidgetLoadingOverlay(game: _game),
            overlayBuilderMap:
                <String, Widget Function(BuildContext, LevelGame)>{
                  LevelGame.loadingOverlayId:
                      (BuildContext context, LevelGame game) =>
                          _LevelLoadingOverlay(game: game),
                  LevelGame.decorationsCounterOverlayId:
                      (BuildContext context, LevelGame game) =>
                          _DecorationsCounter(game: game),
                },
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

class _DecorationsCounter extends StatelessWidget {
  const _DecorationsCounter({required this.game});

  final LevelGame game;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
        child: ValueListenableBuilder<int>(
          valueListenable: game.removedDecorationsCount,
          builder: (BuildContext context, int count, Widget? _) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Trees: $count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LevelLoadingOverlay extends StatelessWidget {
  const _LevelLoadingOverlay({required this.game});

  final LevelGame game;

  @override
  Widget build(BuildContext context) {
    return _GameLoadingOverlayScaffold(
      child: ValueListenableBuilder<LevelLoadingState>(
        valueListenable: game.loadingState,
        builder: (BuildContext context, LevelLoadingState state, Widget? _) {
          return _GameLoadingPanel(
            message: state.message,
            progress: state.progress,
            showIndeterminateWhenZero: false,
          );
        },
      ),
    );
  }
}

class _GameWidgetLoadingOverlay extends StatelessWidget {
  const _GameWidgetLoadingOverlay({required this.game});

  final LevelGame game;

  @override
  Widget build(BuildContext context) {
    return _GameLoadingOverlayScaffold(
      child: ValueListenableBuilder<LevelLoadingState>(
        valueListenable: game.loadingState,
        builder: (BuildContext context, LevelLoadingState state, Widget? _) {
          return _GameLoadingPanel(
            message: state.message,
            progress: state.progress,
            showIndeterminateWhenZero: true,
          );
        },
      ),
    );
  }
}

class _GameLoadingOverlayScaffold extends StatelessWidget {
  const _GameLoadingOverlayScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xCC000000),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GameLoadingPanel extends StatelessWidget {
  const _GameLoadingPanel({
    required this.message,
    required this.progress,
    required this.showIndeterminateWhenZero,
  });

  final String message;
  final double progress;
  final bool showIndeterminateWhenZero;

  @override
  Widget build(BuildContext context) {
    final bool hasMessage = message.trim().isNotEmpty;
    final String safeMessage = hasMessage ? message : 'Initializing game...';
    final bool useIndeterminate = showIndeterminateWhenZero && progress <= 0;
    final double safeProgress = progress.clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'Loading',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          safeMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: useIndeterminate ? null : safeProgress,
          minHeight: 8,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          useIndeterminate ? '...' : '${(safeProgress * 100).round()}%',
          style: const TextStyle(color: Colors.white60),
        ),
      ],
    );
  }
}
