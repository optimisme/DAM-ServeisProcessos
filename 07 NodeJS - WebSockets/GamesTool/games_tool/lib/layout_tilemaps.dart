import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart'
    show
        GestureBinding,
        PointerPanZoomEndEvent,
        PointerPanZoomStartEvent,
        PointerPanZoomUpdateEvent,
        PointerScrollEvent,
        PointerSignalEvent;
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_layer.dart';
import 'widgets/section_help_button.dart';
import 'widgets/selectable_color_swatch.dart';

class _AccentColorOption {
  const _AccentColorOption({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
}

const List<_AccentColorOption> _tilesetAccentOptions = [
  _AccentColorOption(label: 'Blue', color: Color(0xFF2196F3)),
  _AccentColorOption(label: 'Green', color: Color(0xFF34C759)),
  _AccentColorOption(label: 'Orange', color: Color(0xFFFF9500)),
  _AccentColorOption(label: 'Red', color: Color(0xFFFF3B30)),
  _AccentColorOption(label: 'Pink', color: Color(0xFFFF2D55)),
  _AccentColorOption(label: 'Purple', color: Color(0xFFAF52DE)),
  _AccentColorOption(label: 'Teal', color: Color(0xFF30B0C7)),
  _AccentColorOption(label: 'Yellow', color: Color(0xFFFFCC00)),
];

class LayoutTilemaps extends StatefulWidget {
  const LayoutTilemaps({super.key});

  @override
  LayoutTilemapsState createState() => LayoutTilemapsState();
}

class LayoutTilemapsState extends State<LayoutTilemaps> {
  static const double _minTilesetZoom = 0.5;
  static const double _maxTilesetZoom = 8.0;
  static const double _tilesetZoomStep = 0.25;

  Offset? _dragSelectionStartTile;
  bool _isDraggingSelection = false;
  Future<ui.Image>? _tilesetImageFuture;
  String _tilesetImagePath = '';
  final ScrollController _tilesetHorizontalScrollController =
      ScrollController();
  final ScrollController _tilesetVerticalScrollController = ScrollController();
  double _tilesetZoom = 1.0;
  bool _isTrackpadPanZoomActive = false;
  double _lastTrackpadScale = 1.0;

  @override
  void dispose() {
    _tilesetHorizontalScrollController.dispose();
    _tilesetVerticalScrollController.dispose();
    super.dispose();
  }

  void _ensureTilesetImageFuture(AppData appData, String tilesheetPath) {
    if (_tilesetImageFuture != null && _tilesetImagePath == tilesheetPath) {
      return;
    }
    _tilesetImagePath = tilesheetPath;
    appData.selectedTileIndex = -1;
    appData.selectedTilePattern = [];
    appData.tilesetSelectionColStart = -1;
    appData.tilesetSelectionRowStart = -1;
    appData.tilesetSelectionColEnd = -1;
    appData.tilesetSelectionRowEnd = -1;
    _tilesetImageFuture = appData.getImage(tilesheetPath);
  }

  Widget _buildHeader() {
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    final TextStyle sectionTitleStyle = typography.title.copyWith(
      fontSize: (typography.title.fontSize ?? 17) + 2,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Row(
        children: [
          CDKText(
            'Layer Tileset',
            role: CDKTextRole.title,
            style: sectionTitleStyle,
          ),
          const SizedBox(width: 6),
          const SectionHelpButton(
            message:
                'The Tileset viewer shows the tile grid for the selected layer\'s spritesheet. Click tiles or drag to select a region to paint on the map.',
          ),
        ],
      ),
    );
  }

  Future<void> _setSelectionColorForLayer(
      AppData appData, GameLayer layer, Color color) async {
    final bool changed =
        appData.setTilesetSelectionColorForFile(layer.tilesSheetFile, color);
    if (!changed) {
      return;
    }
    appData.update();
    if (appData.selectedProject != null) {
      appData.queueAutosave();
    }
  }

  Widget _buildSelectionColorRow(AppData appData, GameLayer layer) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: _TilesetSelectionColorPicker(
        selectedColor:
            appData.tilesetSelectionColorForFile(layer.tilesSheetFile),
        onSelect: (Color color) {
          unawaited(_setSelectionColorForLayer(appData, layer, color));
        },
      ),
    );
  }

  void _setTilesetZoom(double nextZoom) {
    final double clamped =
        nextZoom.clamp(_minTilesetZoom, _maxTilesetZoom).toDouble();
    if ((clamped - _tilesetZoom).abs() < 0.0001) {
      return;
    }
    setState(() {
      _tilesetZoom = clamped;
    });
  }

  void _zoomTilesetAtLocalPosition({
    required Offset localPosition,
    required double zoomDelta,
    required Size viewportSize,
    required ui.Image image,
  }) {
    if (zoomDelta == 0) {
      return;
    }
    final double nextZoom =
        (_tilesetZoom + zoomDelta).clamp(_minTilesetZoom, _maxTilesetZoom);
    if ((nextZoom - _tilesetZoom).abs() < 0.0001) {
      return;
    }

    const double padding = 8.0;
    ({
      double imageScale,
      Offset imageOffset,
    }) metricsForZoom(double zoom) {
      final double maxWidth = math.max(1, viewportSize.width - padding * 2);
      final double maxHeight = math.max(1, viewportSize.height - padding * 2);
      final double fitScale = math.min(
        maxWidth / image.width,
        maxHeight / image.height,
      );
      final double imageScale = fitScale * zoom;
      final double drawWidth = image.width * imageScale;
      final double drawHeight = image.height * imageScale;
      final double contentWidth =
          math.max(viewportSize.width, drawWidth + padding * 2);
      final double contentHeight =
          math.max(viewportSize.height, drawHeight + padding * 2);
      final Offset imageOffset = Offset(
        (contentWidth - drawWidth) / 2,
        (contentHeight - drawHeight) / 2,
      );
      return (
        imageScale: imageScale,
        imageOffset: imageOffset,
      );
    }

    final ({
      double imageScale,
      Offset imageOffset,
    }) oldMetrics = metricsForZoom(_tilesetZoom);
    final double oldHorizontalOffset =
        _tilesetHorizontalScrollController.hasClients
            ? _tilesetHorizontalScrollController.offset
            : 0.0;
    final double oldVerticalOffset = _tilesetVerticalScrollController.hasClients
        ? _tilesetVerticalScrollController.offset
        : 0.0;
    final Offset viewportPoint = Offset(
      localPosition.dx - oldHorizontalOffset,
      localPosition.dy - oldVerticalOffset,
    );
    final Offset focalImagePoint = Offset(
      (localPosition.dx - oldMetrics.imageOffset.dx) / oldMetrics.imageScale,
      (localPosition.dy - oldMetrics.imageOffset.dy) / oldMetrics.imageScale,
    );

    setState(() {
      _tilesetZoom = nextZoom;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_tilesetHorizontalScrollController.hasClients ||
          !_tilesetVerticalScrollController.hasClients) {
        return;
      }

      final ({
        double imageScale,
        Offset imageOffset,
      }) newMetrics = metricsForZoom(nextZoom);
      final Offset newLocalPosition = Offset(
        newMetrics.imageOffset.dx + focalImagePoint.dx * newMetrics.imageScale,
        newMetrics.imageOffset.dy + focalImagePoint.dy * newMetrics.imageScale,
      );
      final double targetHorizontal = newLocalPosition.dx - viewportPoint.dx;
      final double targetVertical = newLocalPosition.dy - viewportPoint.dy;
      final double clampedHorizontal = targetHorizontal
          .clamp(
            0.0,
            _tilesetHorizontalScrollController.position.maxScrollExtent,
          )
          .toDouble();
      final double clampedVertical = targetVertical
          .clamp(
            0.0,
            _tilesetVerticalScrollController.position.maxScrollExtent,
          )
          .toDouble();

      _tilesetHorizontalScrollController.jumpTo(clampedHorizontal);
      _tilesetVerticalScrollController.jumpTo(clampedVertical);
    });
  }

  Widget _buildToolRow(AppData appData) {
    void toggleEraser() {
      appData.tilemapEraserEnabled = !appData.tilemapEraserEnabled;
      appData.update();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          const CDKText(
            'Erase',
            role: CDKTextRole.caption,
          ),
          const SizedBox(width: 8),
          CDKButton(
            style: appData.tilemapEraserEnabled
                ? CDKButtonStyle.action
                : CDKButtonStyle.normal,
            onPressed: toggleEraser,
            child: const Icon(
              CupertinoIcons.trash,
              size: 14,
            ),
          ),
          const Spacer(),
          const CDKText(
            'Zoom',
            role: CDKTextRole.caption,
          ),
          const SizedBox(width: 8),
          CDKButton(
            style: CDKButtonStyle.normal,
            enabled: _tilesetZoom > _minTilesetZoom,
            onPressed: () => _setTilesetZoom(_tilesetZoom - _tilesetZoomStep),
            child: const Icon(
              CupertinoIcons.minus,
              size: 14,
            ),
          ),
          const SizedBox(width: 6),
          CDKButton(
            style: CDKButtonStyle.normal,
            enabled: (_tilesetZoom - 1.0).abs() > 0.0001,
            onPressed: () => _setTilesetZoom(1.0),
            child: CDKText(
              '${(_tilesetZoom * 100).round()}%',
              role: CDKTextRole.caption,
            ),
          ),
          const SizedBox(width: 6),
          CDKButton(
            style: CDKButtonStyle.normal,
            enabled: _tilesetZoom < _maxTilesetZoom,
            onPressed: () => _setTilesetZoom(_tilesetZoom + _tilesetZoomStep),
            child: const Icon(
              CupertinoIcons.plus,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  Offset? _tileFromLocalPosition({
    required Offset localPosition,
    required Offset imageOffset,
    required double imageScale,
    required GameLayer layer,
    required ui.Image image,
  }) {
    if (imageScale <= 0) return null;
    final double imageX = (localPosition.dx - imageOffset.dx) / imageScale;
    final double imageY = (localPosition.dy - imageOffset.dy) / imageScale;
    if (imageX < 0 ||
        imageY < 0 ||
        imageX >= image.width ||
        imageY >= image.height) {
      return null;
    }

    if (layer.tilesWidth <= 0 || layer.tilesHeight <= 0) return null;
    final int cols = (image.width / layer.tilesWidth).floor();
    final int rows = (image.height / layer.tilesHeight).floor();
    if (cols <= 0 || rows <= 0) return null;

    final int col = (imageX / layer.tilesWidth).floor();
    final int row = (imageY / layer.tilesHeight).floor();
    if (col < 0 || row < 0 || col >= cols || row >= rows) return null;
    return Offset(col.toDouble(), row.toDouble());
  }

  void _clearTileSelection(AppData appData) {
    appData.selectedTileIndex = -1;
    appData.selectedTilePattern = [];
    appData.tilesetSelectionColStart = -1;
    appData.tilesetSelectionRowStart = -1;
    appData.tilesetSelectionColEnd = -1;
    appData.tilesetSelectionRowEnd = -1;
    appData.update();
  }

  void _setRectTileSelection({
    required AppData appData,
    required GameLayer layer,
    required ui.Image image,
    required Offset startTile,
    required Offset endTile,
    bool notify = true,
  }) {
    final int cols = (image.width / layer.tilesWidth).floor();
    final int rows = (image.height / layer.tilesHeight).floor();
    if (cols <= 0 || rows <= 0) {
      _clearTileSelection(appData);
      return;
    }

    final int startCol = startTile.dx.toInt().clamp(0, cols - 1);
    final int startRow = startTile.dy.toInt().clamp(0, rows - 1);
    final int endCol = endTile.dx.toInt().clamp(0, cols - 1);
    final int endRow = endTile.dy.toInt().clamp(0, rows - 1);

    final int left = math.min(startCol, endCol);
    final int right = math.max(startCol, endCol);
    final int top = math.min(startRow, endRow);
    final int bottom = math.max(startRow, endRow);

    final List<List<int>> pattern = [];
    for (int row = top; row <= bottom; row++) {
      final List<int> patternRow = [];
      for (int col = left; col <= right; col++) {
        patternRow.add(row * cols + col);
      }
      pattern.add(patternRow);
    }

    appData.selectedTilePattern = pattern;
    appData.selectedTileIndex = pattern.isNotEmpty && pattern.first.isNotEmpty
        ? pattern.first.first
        : -1;
    appData.tilesetSelectionColStart = left;
    appData.tilesetSelectionRowStart = top;
    appData.tilesetSelectionColEnd = right;
    appData.tilesetSelectionRowEnd = bottom;
    if (notify) {
      appData.update();
    }
  }

  void _toggleSingleTileSelection({
    required AppData appData,
    required GameLayer layer,
    required ui.Image image,
    required Offset localPosition,
    required Offset imageOffset,
    required double imageScale,
  }) {
    final Offset? tile = _tileFromLocalPosition(
      localPosition: localPosition,
      imageOffset: imageOffset,
      imageScale: imageScale,
      layer: layer,
      image: image,
    );
    if (tile == null) return;

    final int col = tile.dx.toInt();
    final int row = tile.dy.toInt();
    if (appData.selectedTilePattern.isNotEmpty &&
        appData.tilesetSelectionColStart >= 0 &&
        appData.tilesetSelectionRowStart >= 0 &&
        appData.tilesetSelectionColEnd >= 0 &&
        appData.tilesetSelectionRowEnd >= 0) {
      final int left = math.min(
          appData.tilesetSelectionColStart, appData.tilesetSelectionColEnd);
      final int right = math.max(
          appData.tilesetSelectionColStart, appData.tilesetSelectionColEnd);
      final int top = math.min(
          appData.tilesetSelectionRowStart, appData.tilesetSelectionRowEnd);
      final int bottom = math.max(
          appData.tilesetSelectionRowStart, appData.tilesetSelectionRowEnd);
      final bool isInsideCurrentSelection =
          col >= left && col <= right && row >= top && row <= bottom;
      if (isInsideCurrentSelection) {
        _clearTileSelection(appData);
        return;
      }
    }

    _setRectTileSelection(
      appData: appData,
      layer: layer,
      image: image,
      startTile: tile,
      endTile: tile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);

    final bool hasLevel = appData.selectedLevel >= 0 &&
        appData.selectedLevel < appData.gameData.levels.length;
    final Set<int> selectedLayerIndices = hasLevel
        ? appData.selectedLayerIndices
            .where((index) =>
                index >= 0 &&
                index <
                    appData
                        .gameData.levels[appData.selectedLevel].layers.length)
            .toSet()
        : <int>{};
    final bool hasMultipleSelectedLayers = selectedLayerIndices.length > 1;
    final bool hasLayer = hasLevel &&
        !hasMultipleSelectedLayers &&
        appData.selectedLayer >= 0 &&
        appData.selectedLayer <
            appData.gameData.levels[appData.selectedLevel].layers.length;
    if (!hasLayer) {
      final String message;
      if (!hasLevel) {
        message = 'Select a Level to edit the tilemap.';
      } else if (hasMultipleSelectedLayers) {
        message = 'Select only one layer to edit its tilemap.';
      } else if (appData
          .gameData.levels[appData.selectedLevel].layers.isEmpty) {
        message = 'This level has no layers yet. Add a Layer first.';
      } else {
        message = 'Select a Layer to edit its tilemap.';
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: Center(
              child: CDKText(
                message,
                role: CDKTextRole.body,
                color: cdkColors.colorText.withValues(alpha: 0.62),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    final GameLayer layer = appData
        .gameData.levels[appData.selectedLevel].layers[appData.selectedLayer];
    _ensureTilesetImageFuture(appData, layer.tilesSheetFile);
    final int selectedRows = appData.selectedTilePattern.length;
    final int selectedCols =
        selectedRows == 0 ? 0 : appData.selectedTilePattern.first.length;
    final bool hasSelection = selectedRows > 0;
    final String selectionLabel = appData.tilemapEraserEnabled && hasSelection
        ? 'Selection: hidden while erasing'
        : selectedRows == 0
            ? 'Selection: none'
            : 'Selection: ${selectedCols}x$selectedRows tile(s)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        _buildSelectionColorRow(appData, layer),
        const SizedBox(height: 6),
        _buildToolRow(appData),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: CDKText(
            'Layer: ${layer.name}',
            role: CDKTextRole.bodyStrong,
            color: cdkColors.colorText,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: CDKText(
            'Tileset: ${appData.mediaDisplayNameByFileName(layer.tilesSheetFile)}',
            role: CDKTextRole.caption,
            color: cdkColors.colorText,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: CDKText(
            selectionLabel,
            role: CDKTextRole.caption,
            color: cdkColors.colorText,
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: CDKText(
            'Click to toggle one tile. Drag to select a tile block.',
            role: CDKTextRole.caption,
            secondary: true,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<ui.Image>(
            future: _tilesetImageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.data == null) {
                return const Center(child: CupertinoActivityIndicator());
              }
              final ui.Image? image = snapshot.data;
              if (image == null) {
                return const Center(
                  child: CDKText(
                    'Tileset image not available.',
                    role: CDKTextRole.body,
                    secondary: true,
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  const double padding = 8.0;
                  final double maxWidth =
                      math.max(1, constraints.maxWidth - padding * 2);
                  final double maxHeight =
                      math.max(1, constraints.maxHeight - padding * 2);
                  final double fitScale = math.min(
                    maxWidth / image.width,
                    maxHeight / image.height,
                  );
                  final double imageScale = fitScale * _tilesetZoom;
                  final double drawWidth = image.width * imageScale;
                  final double drawHeight = image.height * imageScale;
                  final double contentWidth =
                      math.max(constraints.maxWidth, drawWidth + padding * 2);
                  final double contentHeight =
                      math.max(constraints.maxHeight, drawHeight + padding * 2);
                  final Offset imageOffset = Offset(
                    (contentWidth - drawWidth) / 2,
                    (contentHeight - drawHeight) / 2,
                  );

                  return CupertinoScrollbar(
                    controller: _tilesetVerticalScrollController,
                    child: SingleChildScrollView(
                      controller: _tilesetVerticalScrollController,
                      child: CupertinoScrollbar(
                        controller: _tilesetHorizontalScrollController,
                        notificationPredicate: (notification) =>
                            notification.depth == 1,
                        child: SingleChildScrollView(
                          controller: _tilesetHorizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: contentWidth,
                            height: contentHeight,
                            child: Listener(
                              onPointerPanZoomStart:
                                  (PointerPanZoomStartEvent _) {
                                _isTrackpadPanZoomActive = true;
                                _lastTrackpadScale = 1.0;
                                _isDraggingSelection = false;
                                _dragSelectionStartTile = null;
                              },
                              onPointerPanZoomUpdate:
                                  (PointerPanZoomUpdateEvent event) {
                                if (!_isTrackpadPanZoomActive) {
                                  _isTrackpadPanZoomActive = true;
                                }
                                final double scaleDelta =
                                    event.scale / _lastTrackpadScale;
                                _lastTrackpadScale = event.scale;
                                if ((scaleDelta - 1.0).abs() < 0.0001) {
                                  return;
                                }
                                final double zoomDelta =
                                    (math.log(scaleDelta) / math.ln2) *
                                        (_tilesetZoomStep * 2);
                                _zoomTilesetAtLocalPosition(
                                  localPosition: event.localPosition,
                                  zoomDelta: zoomDelta,
                                  viewportSize: Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  ),
                                  image: image,
                                );
                              },
                              onPointerPanZoomEnd: (PointerPanZoomEndEvent _) {
                                _isTrackpadPanZoomActive = false;
                                _lastTrackpadScale = 1.0;
                              },
                              onPointerSignal: (event) {
                                if (event is! PointerScrollEvent) {
                                  return;
                                }
                                GestureBinding.instance.pointerSignalResolver
                                    .register(
                                  event,
                                  (PointerSignalEvent resolvedEvent) {
                                    final PointerScrollEvent scrollEvent =
                                        resolvedEvent as PointerScrollEvent;
                                    final double dy =
                                        scrollEvent.scrollDelta.dy;
                                    if (dy == 0) {
                                      return;
                                    }
                                    _zoomTilesetAtLocalPosition(
                                      localPosition: scrollEvent.localPosition,
                                      zoomDelta: dy < 0
                                          ? _tilesetZoomStep
                                          : -_tilesetZoomStep,
                                      viewportSize: Size(
                                        constraints.maxWidth,
                                        constraints.maxHeight,
                                      ),
                                      image: image,
                                    );
                                  },
                                );
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (details) {
                                  if (_isTrackpadPanZoomActive ||
                                      details.kind !=
                                          ui.PointerDeviceKind.mouse) {
                                    return;
                                  }
                                  if (appData.tilemapEraserEnabled) {
                                    return;
                                  }
                                  _toggleSingleTileSelection(
                                    appData: appData,
                                    layer: layer,
                                    image: image,
                                    localPosition: details.localPosition,
                                    imageOffset: imageOffset,
                                    imageScale: imageScale,
                                  );
                                },
                                onPanStart: (details) {
                                  if (_isTrackpadPanZoomActive ||
                                      details.kind !=
                                          ui.PointerDeviceKind.mouse) {
                                    _dragSelectionStartTile = null;
                                    _isDraggingSelection = false;
                                    return;
                                  }
                                  if (appData.tilemapEraserEnabled) {
                                    _dragSelectionStartTile = null;
                                    _isDraggingSelection = false;
                                    return;
                                  }
                                  final Offset? tile = _tileFromLocalPosition(
                                    localPosition: details.localPosition,
                                    imageOffset: imageOffset,
                                    imageScale: imageScale,
                                    layer: layer,
                                    image: image,
                                  );
                                  if (tile == null) {
                                    _dragSelectionStartTile = null;
                                    _isDraggingSelection = false;
                                    return;
                                  }
                                  _dragSelectionStartTile = tile;
                                  _isDraggingSelection = true;
                                  _setRectTileSelection(
                                    appData: appData,
                                    layer: layer,
                                    image: image,
                                    startTile: tile,
                                    endTile: tile,
                                  );
                                },
                                onPanUpdate: (details) {
                                  if (!_isDraggingSelection ||
                                      _dragSelectionStartTile == null) {
                                    return;
                                  }
                                  final Offset? tile = _tileFromLocalPosition(
                                    localPosition: details.localPosition,
                                    imageOffset: imageOffset,
                                    imageScale: imageScale,
                                    layer: layer,
                                    image: image,
                                  );
                                  if (tile == null) return;
                                  _setRectTileSelection(
                                    appData: appData,
                                    layer: layer,
                                    image: image,
                                    startTile: _dragSelectionStartTile!,
                                    endTile: tile,
                                  );
                                },
                                onPanEnd: (_) {
                                  _isDraggingSelection = false;
                                  _dragSelectionStartTile = null;
                                },
                                child: CustomPaint(
                                  painter: _TilesetSelectionPainter(
                                    image: image,
                                    imageOffset: imageOffset,
                                    imageScale: imageScale,
                                    tileWidth: layer.tilesWidth.toDouble(),
                                    tileHeight: layer.tilesHeight.toDouble(),
                                    selectionColStart:
                                        appData.tilemapEraserEnabled
                                            ? -1
                                            : appData.tilesetSelectionColStart,
                                    selectionRowStart:
                                        appData.tilemapEraserEnabled
                                            ? -1
                                            : appData.tilesetSelectionRowStart,
                                    selectionColEnd:
                                        appData.tilemapEraserEnabled
                                            ? -1
                                            : appData.tilesetSelectionColEnd,
                                    selectionRowEnd:
                                        appData.tilemapEraserEnabled
                                            ? -1
                                            : appData.tilesetSelectionRowEnd,
                                    selectionColor:
                                        appData.tilesetSelectionColorForFile(
                                      layer.tilesSheetFile,
                                    ),
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TilesetSelectionPainter extends CustomPainter {
  const _TilesetSelectionPainter({
    required this.image,
    required this.imageOffset,
    required this.imageScale,
    required this.tileWidth,
    required this.tileHeight,
    required this.selectionColStart,
    required this.selectionRowStart,
    required this.selectionColEnd,
    required this.selectionRowEnd,
    required this.selectionColor,
  });

  final ui.Image image;
  final Offset imageOffset;
  final double imageScale;
  final double tileWidth;
  final double tileHeight;
  final int selectionColStart;
  final int selectionRowStart;
  final int selectionColEnd;
  final int selectionRowEnd;
  final Color selectionColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final Rect dst = Rect.fromLTWH(
      imageOffset.dx,
      imageOffset.dy,
      image.width * imageScale,
      image.height * imageScale,
    );
    canvas.drawImageRect(image, src, dst, Paint());

    if (tileWidth > 0 && tileHeight > 0) {
      final int cols = (image.width / tileWidth).floor();
      final int rows = (image.height / tileHeight).floor();
      final Paint gridPaint = Paint()
        ..color = const Color(0xAA000000)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      for (int col = 0; col <= cols; col++) {
        final double x = imageOffset.dx + col * tileWidth * imageScale;
        canvas.drawLine(
          Offset(x, imageOffset.dy),
          Offset(x, imageOffset.dy + rows * tileHeight * imageScale),
          gridPaint,
        );
      }
      for (int row = 0; row <= rows; row++) {
        final double y = imageOffset.dy + row * tileHeight * imageScale;
        canvas.drawLine(
          Offset(imageOffset.dx, y),
          Offset(imageOffset.dx + cols * tileWidth * imageScale, y),
          gridPaint,
        );
      }
    }

    if (selectionColStart >= 0 &&
        selectionRowStart >= 0 &&
        selectionColEnd >= 0 &&
        selectionRowEnd >= 0) {
      final int left = math.min(selectionColStart, selectionColEnd);
      final int right = math.max(selectionColStart, selectionColEnd);
      final int top = math.min(selectionRowStart, selectionRowEnd);
      final int bottom = math.max(selectionRowStart, selectionRowEnd);

      final Rect selectedRect = Rect.fromLTWH(
        imageOffset.dx + left * tileWidth * imageScale,
        imageOffset.dy + top * tileHeight * imageScale,
        (right - left + 1) * tileWidth * imageScale,
        (bottom - top + 1) * tileHeight * imageScale,
      );

      canvas.drawRect(
        selectedRect,
        Paint()..color = selectionColor.withValues(alpha: 0.35),
      );
      canvas.drawRect(
        selectedRect,
        Paint()
          ..color = selectionColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TilesetSelectionPainter oldDelegate) {
    return image != oldDelegate.image ||
        imageOffset != oldDelegate.imageOffset ||
        imageScale != oldDelegate.imageScale ||
        tileWidth != oldDelegate.tileWidth ||
        tileHeight != oldDelegate.tileHeight ||
        selectionColStart != oldDelegate.selectionColStart ||
        selectionRowStart != oldDelegate.selectionRowStart ||
        selectionColEnd != oldDelegate.selectionColEnd ||
        selectionRowEnd != oldDelegate.selectionRowEnd ||
        selectionColor != oldDelegate.selectionColor;
  }
}

class _TilesetSelectionColorPicker extends StatelessWidget {
  const _TilesetSelectionColorPicker({
    required this.selectedColor,
    required this.onSelect,
  });

  final Color selectedColor;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CDKText(
          'Selection Color',
          role: CDKTextRole.caption,
        ),
        SizedBox(height: spacing.xs),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: _tilesetAccentOptions.map((option) {
              final bool isSelected = option.color == selectedColor;
              return SelectableColorSwatch(
                color: option.color,
                selected: isSelected,
                onTap: () => onSelect(option.color),
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }
}
