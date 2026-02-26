import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import 'static_tile_layer_batch_component.dart';

// ---------------------------------------------------------------------------
// Parallax formula — matches games_tool layout_utils.dart exactly
// ---------------------------------------------------------------------------

/// Returns the parallax scroll factor for [depth], using the same exponential
/// formula as the games_tool editor:
///
///   `factor = clamp(e^(-depth * 0.08), 0.25, 4.0)`
///
/// - `depth == 0.0` → factor `1.0` (scrolls at camera speed, no parallax)
/// - `depth > 0`    → factor `< 1.0` (background, scrolls slower)
/// - `depth < 0`    → factor `> 1.0` (foreground, scrolls faster)
double parallaxFactorForDepth(double depth) {
  const double step = 0.08;
  const double minFactor = 0.25;
  const double maxFactor = 4.0;
  return math.exp(-depth * step).clamp(minFactor, maxFactor);
}

// ---------------------------------------------------------------------------
// ParallaxTileLayerComponent
// ---------------------------------------------------------------------------

/// A [PositionComponent] container that holds a [StaticTileLayerBatchComponent]
/// and applies a per-frame parallax offset based on the layer's designer-set
/// [depth] value.
///
/// The parallax formula matches the games_tool editor exactly.
/// For layers with `depth == 0` (factor == 1.0) the position update is skipped
/// every frame to avoid unnecessary work.
///
/// **Painter order** is controlled entirely by [priority], which the loader
/// assigns based on declaration order — faithfully reproducing the painter
/// algorithm from the editor.
///
/// Usage: the loader creates these instead of bare
/// [StaticTileLayerBatchComponent] instances. Game code does not need to
/// interact with this class directly.
class ParallaxTileLayerComponent extends PositionComponent {
  ParallaxTileLayerComponent({
    required Image atlas,
    required List<List<int>> tileMap,
    required int tileWidth,
    required int tileHeight,

    /// World-space origin of this layer as designed (before any parallax).
    required double baseX,
    required double baseY,

    /// The designer-set depth value from the layer data.
    required this.depth,

    /// The camera world position at the time the level was mounted.
    /// Used as the parallax scroll reference point.
    required Vector2 viewportOrigin,

    super.priority,
  })  : _baseX = baseX,
        _baseY = baseY,
        _parallaxFactor = parallaxFactorForDepth(depth),
        _viewportOrigin = viewportOrigin.clone(),
        _hasParallax = parallaxFactorForDepth(depth) != 1.0 {
    _batchComponent = StaticTileLayerBatchComponent(
      atlas: atlas,
      tileMap: tileMap,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      worldX: 0,
      worldY: 0,
    );
    position = Vector2(baseX, baseY);
  }

  /// Designer depth value. Exposed for debugging / game logic.
  final double depth;

  final double _baseX;
  final double _baseY;
  final double _parallaxFactor;
  final Vector2 _viewportOrigin;
  final bool _hasParallax;

  late final StaticTileLayerBatchComponent _batchComponent;

  /// The world-space bounds of the rendered tiles (after parallax offset).
  Rect get worldBounds => _batchComponent.worldBounds.translate(
        position.x,
        position.y,
      );

  @override
  Future<void> onLoad() async {
    await add(_batchComponent);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_hasParallax) return;

    final CameraComponent? cam = CameraComponent.currentCamera;
    if (cam == null) return;

    final Vector2 cameraPos = cam.viewfinder.position;
    final double offsetX = cameraPos.x - _viewportOrigin.x;
    final double offsetY = cameraPos.y - _viewportOrigin.y;

    // drawX = baseX + cameraOffset * (factor - 1)
    // This matches the games_tool canvas_painter.dart formula exactly.
    position.setValues(
      _baseX + offsetX * (_parallaxFactor - 1.0),
      _baseY + offsetY * (_parallaxFactor - 1.0),
    );
  }
}
