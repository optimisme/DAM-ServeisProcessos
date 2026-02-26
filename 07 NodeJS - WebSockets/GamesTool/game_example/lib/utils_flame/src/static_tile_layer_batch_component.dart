import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

/// Renders a single tile-layer from a Games Tool export.
///
/// ## Rendering strategy
///
/// The batch is rebuilt **every frame** but only for tiles that overlap the
/// current camera's visible world rect. This means the GPU upload is always
/// proportional to the number of *visible* tiles — typically a small, fixed
/// window — regardless of how large the total map is.
///
/// Why not a static batch?
/// `SpriteBatch` passes `cullRect` straight to `Canvas.drawAtlas`, which is a
/// GPU-level hint only. The full transform array (one entry per non-empty tile)
/// is still uploaded every frame. For a small example map (2 k tiles) that is
/// negligible, but games_tool maps can be arbitrarily large. Per-frame rebuild
/// from a visible-tile window keeps the upload O(viewport) instead of O(map).
///
/// Why rebuild instead of a dirty flag?
/// The camera moves every frame in a scrolling game, so the visible window
/// changes every frame anyway. The rebuild cost is dominated by the
/// `Float32List` fills inside `SpriteBatch.add`, which is extremely fast even
/// for a full viewport worth of tiles (hundreds at most for typical tile sizes).
class StaticTileLayerBatchComponent extends Component {
  StaticTileLayerBatchComponent({
    required this.atlas,
    required this.tileMap,
    required this.tileWidth,
    required this.tileHeight,
    required this.worldX,
    required this.worldY,
    super.priority,
  });

  final Image atlas;
  final List<List<int>> tileMap;
  final int tileWidth;
  final int tileHeight;
  final double worldX;
  final double worldY;

  // Pre-computed atlas layout — set once in onLoad.
  int _atlasColumns = 0;
  int _atlasRows = 0;

  // Source-rect cache — one entry per unique tile index, populated lazily.
  final Map<int, Rect> _sourceCache = <int, Rect>{};

  // Batch is re-used each frame (cleared then refilled).
  late final SpriteBatch _batch;

  // World-space bounding box of the *entire* layer (not just the visible part).
  Rect _worldBounds = Rect.zero;
  Rect get worldBounds => _worldBounds;

  @override
  Future<void> onLoad() async {
    _batch = SpriteBatch(atlas);

    _atlasColumns = tileWidth > 0 ? atlas.width ~/ tileWidth : 0;
    _atlasRows = tileHeight > 0 ? atlas.height ~/ tileHeight : 0;

    // Compute world bounds from the full map extents.
    if (_atlasColumns > 0 && _atlasRows > 0 && tileMap.isNotEmpty) {
      int maxCols = 0;
      for (final List<int> row in tileMap) {
        if (row.length > maxCols) maxCols = row.length;
      }
      _worldBounds = Rect.fromLTWH(
        worldX,
        worldY,
        (maxCols * tileWidth).toDouble(),
        (tileMap.length * tileHeight).toDouble(),
      );
    } else {
      _worldBounds = Rect.fromLTWH(worldX, worldY, 0, 0);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_atlasColumns <= 0 || _atlasRows <= 0 || tileMap.isEmpty) return;

    final CameraComponent? camera = CameraComponent.currentCamera;

    // Without a camera render everything (editor / test context).
    Rect? visibleRect;
    if (camera != null) {
      visibleRect = camera.visibleWorldRect;
      if (!visibleRect.overlaps(_worldBounds)) return;
    }

    _buildVisibleBatch(visibleRect);
    if (!_batch.isEmpty) {
      _batch.render(canvas);
    }
  }

  void _buildVisibleBatch(Rect? visibleRect) {
    _batch.clear();

    // Compute the row/col range that overlaps the visible rect.
    // When there is no camera we render all tiles (fallback path).
    final int rowStart;
    final int rowEnd;
    final int colStart;
    final int colEnd;

    if (visibleRect != null) {
      // Convert world-space visible rect to tile-grid indices, clamped to map.
      rowStart = math
          .max(0, ((visibleRect.top - worldY) / tileHeight).floor());
      rowEnd = math.min(
        tileMap.length - 1,
        ((visibleRect.bottom - worldY) / tileHeight).ceil(),
      );
      colStart = math
          .max(0, ((visibleRect.left - worldX) / tileWidth).floor());
      colEnd = math.min(
        (tileMap.isNotEmpty ? tileMap[0].length : 0) - 1,
        ((visibleRect.right - worldX) / tileWidth).ceil(),
      );
    } else {
      rowStart = 0;
      rowEnd = tileMap.length - 1;
      colStart = 0;
      colEnd = tileMap.isNotEmpty ? tileMap[0].length - 1 : -1;
    }

    if (rowEnd < rowStart || colEnd < colStart) return;

    for (int rowIndex = rowStart; rowIndex <= rowEnd; rowIndex++) {
      final List<int> row = tileMap[rowIndex];
      final int clampedColEnd = math.min(colEnd, row.length - 1);
      for (int colIndex = colStart; colIndex <= clampedColEnd; colIndex++) {
        final int tileIndex = row[colIndex];
        if (tileIndex < 0) continue;

        final Rect? source = _sourceForTileIndex(tileIndex);
        if (source == null) continue;

        _batch.add(
          source: source,
          offset: Vector2(
            worldX + (colIndex * tileWidth).toDouble(),
            worldY + (rowIndex * tileHeight).toDouble(),
          ),
        );
      }
    }
  }

  Rect? _sourceForTileIndex(int tileIndex) {
    final Rect? cached = _sourceCache[tileIndex];
    if (cached != null) return cached;

    final int sourceColumn = tileIndex % _atlasColumns;
    final int sourceRow = tileIndex ~/ _atlasColumns;
    if (sourceRow < 0 || sourceRow >= _atlasRows) return null;

    final Rect source = Rect.fromLTWH(
      (sourceColumn * tileWidth).toDouble(),
      (sourceRow * tileHeight).toDouble(),
      tileWidth.toDouble(),
      tileHeight.toDouble(),
    );
    _sourceCache[tileIndex] = source;
    return source;
  }
}
