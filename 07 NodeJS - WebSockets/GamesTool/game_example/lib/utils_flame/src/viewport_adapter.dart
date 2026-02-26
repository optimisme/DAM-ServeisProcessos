import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:game_example/utils_gt/utils_gt.dart';

// ---------------------------------------------------------------------------
// GamesToolViewportMode — how the game world is mapped to the screen
// ---------------------------------------------------------------------------

/// Controls how the level's designed resolution is adapted to the device screen.
///
/// - [fromGameData] reads the `viewportAdaptation` field from the exported
///   `game_data.json` and applies the matching mode automatically.
/// - [letterbox] preserves the exact design resolution with black bars on the
///   sides/top as needed. This is the recommended default for pixel-art games.
/// - [expand] enlarges the visible world area to fill the screen without
///   distortion — more of the world becomes visible on wider screens.
/// - [stretch] scales the game to fill the screen, ignoring aspect ratio.
///   Content may appear distorted.
enum GamesToolViewportMode {
  fromGameData,
  letterbox,
  expand,
  stretch,
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

GamesToolViewportMode _modeFromString(String raw) {
  switch (raw.toLowerCase().trim()) {
    case 'letterbox':
      return GamesToolViewportMode.letterbox;
    case 'expand':
      return GamesToolViewportMode.expand;
    case 'stretch':
      return GamesToolViewportMode.stretch;
    default:
      return GamesToolViewportMode.letterbox;
  }
}

// ---------------------------------------------------------------------------
// buildCamera — creates the fully configured camera for a level
// ---------------------------------------------------------------------------

/// Creates a [CameraComponent] configured for [level] using [mode].
///
/// [screenSize] should be the current physical screen size in logical pixels
/// (e.g. from `MediaQuery.of(context).size`). It is only needed for the
/// [GamesToolViewportMode.expand] and [GamesToolViewportMode.stretch] modes;
/// for [GamesToolViewportMode.letterbox] it is ignored.
///
/// Returns a tuple of the camera and the resolved effective mode.
(CameraComponent camera, GamesToolViewportMode resolvedMode) buildCamera({
  required GamesToolLevel level,
  required World world,
  required GamesToolViewportMode mode,
  Size screenSize = Size.zero,
}) {
  final GamesToolViewportMode resolved = mode == GamesToolViewportMode.fromGameData
      ? _modeFromString(level.viewportAdaptation)
      : mode;

  final double designW = level.viewportWidth > 0
      ? level.viewportWidth.toDouble()
      : 320.0;
  final double designH = level.viewportHeight > 0
      ? level.viewportHeight.toDouble()
      : 180.0;

  final CameraComponent camera;

  switch (resolved) {
    case GamesToolViewportMode.letterbox:
    case GamesToolViewportMode.fromGameData:
      // FixedResolutionViewport maintains the exact design resolution and adds
      // black bars — identical to Flame's CameraComponent.withFixedResolution.
      camera = CameraComponent(
        viewport: FixedResolutionViewport(
          resolution: Vector2(designW, designH),
        ),
        world: world,
      );

    case GamesToolViewportMode.expand:
      // Enlarges the visible world area to fill screen without distortion.
      // On wider screens more horizontal world is visible; on taller screens
      // more vertical world is visible.
      camera = CameraComponent(
        viewport: MaxViewport(),
        world: world,
      );
      if (screenSize != Size.zero && designW > 0 && designH > 0) {
        final double screenAspect = screenSize.width / screenSize.height;
        final double designAspect = designW / designH;
        double zoom;
        if (screenAspect > designAspect) {
          // Screen is wider → fit height, show more width.
          zoom = screenSize.height / designH;
        } else {
          // Screen is taller → fit width, show more height.
          zoom = screenSize.width / designW;
        }
        if (zoom > 0) camera.viewfinder.zoom = zoom;
      }

    case GamesToolViewportMode.stretch:
      // MaxViewport fills the entire screen. Without a fixed-resolution
      // viewport the game world simply stretches to fit — correct content
      // will be visible but proportions may be distorted.
      camera = CameraComponent(
        viewport: MaxViewport(),
        world: world,
      );
      // No zoom adjustment — Flame will naturally stretch the world to fill.
  }

  return (camera, resolved);
}
