import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'canvas_painter.dart';
import 'game_layer.dart';
import 'game_level.dart';
import 'game_sprite.dart';
import 'game_zone.dart';
import 'layout_animations.dart';
import 'layout_sprites.dart';
import 'layout_layers.dart';
import 'layout_levels.dart';
import 'layout_media.dart';
import 'layout_projects.dart';
import 'layout_projects_main.dart';
import 'layout_tilemaps.dart';
import 'layout_zones.dart';
import 'layout_viewport.dart';
import 'layout_utils.dart';

class Layout extends StatefulWidget {
  const Layout({super.key, required this.title});

  final String title;

  @override
  State<Layout> createState() => _LayoutState();
}

enum _LayersCanvasTool { arrow, hand }

class _LayoutState extends State<Layout> {
  // Clau del layout escollit
  final GlobalKey<LayoutSpritesState> layoutSpritesKey =
      GlobalKey<LayoutSpritesState>();
  final GlobalKey<LayoutZonesState> layoutZonesKey =
      GlobalKey<LayoutZonesState>();
  final GlobalKey<LayoutViewportState> layoutViewportKey =
      GlobalKey<LayoutViewportState>();

  // ignore: unused_field
  Timer? _timer;
  ui.Image? _layerImage;
  bool _isDraggingLayer = false;
  bool _isDraggingViewport = false;
  bool _isResizingViewport = false;
  bool _isDraggingZone = false;
  bool _isResizingZone = false;
  bool _isDraggingSprite = false;
  bool _isSelectingAnimationFrames = false;
  bool _isPaintingTilemap = false;
  bool _didModifyZoneDuringGesture = false;
  bool _didModifySpriteDuringGesture = false;
  bool _didModifyLayerDuringGesture = false;
  bool _didModifyAnimationDuringGesture = false;
  bool _didModifyTilemapDuringGesture = false;
  int? _animationDragStartFrame;
  bool _isPointerDown = false;
  bool _isHoveringSelectedTilemapLayer = false;
  bool _isDragGestureActive = false;
  bool _pendingLayersViewportCenter = false;
  int? _pendingLevelsViewportFitLevelIndex;
  int? _lastAutoFramedLevelIndex;
  final Set<int> _selectedLayerIndices = <int>{};
  final Map<int, Offset> _layerDragOffsetsByIndex = <int, Offset>{};
  int _layerSelectionLevelIndex = -1;
  bool _isMarqueeSelectingLayers = false;
  bool _marqueeSelectionAdditive = false;
  Offset? _layersMarqueeStartLocal;
  Offset? _layersMarqueeCurrentLocal;
  Set<int> _marqueeBaseLayerSelection = <int>{};
  final Set<int> _selectedZoneIndices = <int>{};
  final Map<int, Offset> _zoneDragOffsetsByIndex = <int, Offset>{};
  int _zoneSelectionLevelIndex = -1;
  bool _isMarqueeSelectingZones = false;
  bool _zoneMarqueeSelectionAdditive = false;
  Offset? _zonesMarqueeStartLocal;
  Offset? _zonesMarqueeCurrentLocal;
  Set<int> _marqueeBaseZoneSelection = <int>{};
  final Set<int> _selectedSpriteIndices = <int>{};
  final Map<int, Offset> _spriteDragOffsetsByIndex = <int, Offset>{};
  int _spriteSelectionLevelIndex = -1;
  bool _isMarqueeSelectingSprites = false;
  bool _spriteMarqueeSelectionAdditive = false;
  Offset? _spritesMarqueeStartLocal;
  Offset? _spritesMarqueeCurrentLocal;
  Set<int> _marqueeBaseSpriteSelection = <int>{};
  final FocusNode _focusNode = FocusNode();
  _LayersCanvasTool _layersCanvasTool = _LayersCanvasTool.hand;
  List<String> sections = [
    'projects',
    'media',
    'animations',
    'levels',
    'layers',
    'tilemap',
    'zones',
    'sprites',
    'viewport',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appData = Provider.of<AppData>(context, listen: false);
      appData.selectedSection = 'projects';
      _focusNode.requestFocus();
    });

    _startFrameTimer();
  }

  void _startFrameTimer() {
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      final appData = Provider.of<AppData>(context, listen: false);
      appData.frame++;
      if (appData.frame > 4096) {
        appData.frame = 0;
      }
      appData.update();
    });
  }

  @override
  void dispose() {
    try {
      final appData = Provider.of<AppData>(context, listen: false);
      unawaited(appData.flushPendingAutosave());
    } catch (_) {}
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onTabSelected(AppData appData, String value) async {
    await appData.setSelectedSection(value);
  }

  int _selectedSectionIndex(String selectedSection) {
    final selectedIndex = sections.indexOf(selectedSection);
    return selectedIndex == -1 ? 0 : selectedIndex;
  }

  List<MapEntry<String, String>> _selectedBreadcrumbParts(AppData appData) {
    final List<MapEntry<String, String>> parts = [];
    final String? projectName = appData.selectedProject?.name.trim();
    if (projectName != null && projectName.isNotEmpty) {
      parts.add(MapEntry('Project', projectName));
    }

    final bool hasLevel = appData.selectedLevel >= 0 &&
        appData.selectedLevel < appData.gameData.levels.length;
    final level =
        hasLevel ? appData.gameData.levels[appData.selectedLevel] : null;

    void addLevel() {
      if (level == null) return;
      parts.add(
        MapEntry(
          'Level',
          level.name.trim().isEmpty
              ? 'Level ${appData.selectedLevel + 1}'
              : level.name.trim(),
        ),
      );
    }

    void addLayer() {
      if (level == null) return;
      if (appData.selectedLayer < 0 ||
          appData.selectedLayer >= level.layers.length) {
        return;
      }
      final layer = level.layers[appData.selectedLayer];
      parts.add(
        MapEntry(
          'Layer',
          layer.name.trim().isEmpty
              ? 'Layer ${appData.selectedLayer + 1}'
              : layer.name.trim(),
        ),
      );
    }

    void addZone() {
      if (level == null) return;
      if (appData.selectedZone < 0 ||
          appData.selectedZone >= level.zones.length) {
        return;
      }
      final zone = level.zones[appData.selectedZone];
      final String zoneType = zone.type.trim();
      parts.add(
        MapEntry(
          'Zone',
          zoneType.isEmpty ? 'Zone ${appData.selectedZone + 1}' : zoneType,
        ),
      );
    }

    void addSprite() {
      if (level == null) return;
      if (appData.selectedSprite < 0 ||
          appData.selectedSprite >= level.sprites.length) {
        return;
      }
      final sprite = level.sprites[appData.selectedSprite];
      final String spriteName = sprite.name.trim();
      parts.add(
        MapEntry(
          'Sprite',
          spriteName.isEmpty
              ? 'Sprite ${appData.selectedSprite + 1}'
              : spriteName,
        ),
      );
    }

    void addAnimation() {
      if (appData.selectedAnimation < 0 ||
          appData.selectedAnimation >= appData.gameData.animations.length) {
        return;
      }
      final animation = appData.gameData.animations[appData.selectedAnimation];
      final String name = animation.name.trim().isNotEmpty
          ? animation.name.trim()
          : appData.animationDisplayNameById(animation.id);
      parts.add(MapEntry('Animation', name));
    }

    void addMedia() {
      if (appData.selectedMedia < 0 ||
          appData.selectedMedia >= appData.gameData.mediaAssets.length) {
        return;
      }
      final media = appData.gameData.mediaAssets[appData.selectedMedia];
      parts.add(MapEntry(
          'Media', appData.mediaDisplayNameByFileName(media.fileName)));
    }

    switch (appData.selectedSection) {
      case 'levels':
      case 'viewport':
        addLevel();
        break;
      case 'layers':
      case 'tilemap':
        addLevel();
        addLayer();
        break;
      case 'zones':
        addLevel();
        addZone();
        break;
      case 'sprites':
        addLevel();
        addSprite();
        break;
      case 'animations':
        addAnimation();
        break;
      case 'media':
        addMedia();
        break;
      case 'projects':
      default:
        break;
    }

    if (parts.isEmpty) {
      return const [MapEntry('Selection', 'None')];
    }
    return parts;
  }

  Widget _buildBreadcrumb(AppData appData, BuildContext context) {
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    const Color breadcrumbLabelColor = Color(0xFF66B2FF);
    final List<MapEntry<String, String>> parts =
        _selectedBreadcrumbParts(appData);
    final List<InlineSpan> spans = [];

    for (int i = 0; i < parts.length; i++) {
      if (i > 0) {
        spans.add(
          TextSpan(
            text: ' > ',
            style: typography.body.copyWith(
              color: breadcrumbLabelColor,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: '${parts[i].key}: ',
          style: typography.body.copyWith(
            color: breadcrumbLabelColor,
          ),
        ),
      );
      spans.add(
        TextSpan(
          text: parts[i].value,
          style: typography.body.copyWith(color: cdkColors.colorText),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  List<Widget> _buildSegmentedOptions(BuildContext context) {
    return sections
        .map(
          (segment) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            child: CDKText(
              segment[0].toUpperCase() + segment.substring(1),
              role: CDKTextRole.caption,
            ),
          ),
        )
        .toList(growable: false);
  }

  Widget _getSelectedLayout(AppData appData) {
    switch (appData.selectedSection) {
      case 'projects':
        return const LayoutProjects();
      case 'levels':
        return const LayoutLevels();
      case 'layers':
        return const LayoutLayers();
      case 'tilemap':
        return const LayoutTilemaps();
      case 'zones':
        return LayoutZones(key: layoutZonesKey);
      case 'animations':
        return const LayoutAnimations();
      case 'sprites':
        return LayoutSprites(key: layoutSpritesKey);
      case 'viewport':
        return LayoutViewport(key: layoutViewportKey);
      case 'media':
        return const LayoutMedia();
      default:
        return const Center(
          child: CDKText(
            'Unknown Layout',
            role: CDKTextRole.body,
            secondary: true,
          ),
        );
    }
  }

  Future<void> _drawCanvasImage(AppData appData) async {
    ui.Image image;
    switch (appData.selectedSection) {
      case 'projects':
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'levels':
        // Levels section renders in world space via CanvasPainter.
        await LayoutUtils.preloadLayerImages(appData);
        await LayoutUtils.preloadSpriteImages(appData);
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'layers':
        // Layers section renders directly in world space via CanvasPainter.
        // Preload tileset and sprite images for the preview.
        await LayoutUtils.preloadLayerImages(appData);
        await LayoutUtils.preloadSpriteImages(appData);
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'tilemap':
        // Tilemap section now renders in world space via CanvasPainter.
        await LayoutUtils.preloadLayerImages(appData);
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'zones':
        // Zones section reuses the world viewport rendering from layers.
        await LayoutUtils.preloadLayerImages(appData);
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'sprites':
        await LayoutUtils.preloadLayerImages(appData);
        await LayoutUtils.preloadSpriteImages(appData);
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'viewport':
        // Viewport section renders in world space via CanvasPainter.
        await LayoutUtils.preloadLayerImages(appData);
        await LayoutUtils.preloadSpriteImages(appData);
        LayoutUtils.ensureViewportPreviewInitialized(appData);
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'animations':
        image = await LayoutUtils.drawCanvasImageAnimations(appData);
      case 'media':
        image = await LayoutUtils.drawCanvasImageMedia(appData);
      default:
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
    }

    setState(() {
      _layerImage = image;
    });
  }

  void _applyLayersZoom(AppData appData, Offset cursor, double scrollDy) {
    if (scrollDy == 0) return;
    const double zoomSensitivity = 0.01;
    const double minScale = 0.05;
    const double maxScale = 20.0;
    final double oldScale = appData.layersViewScale;
    final double newScale = (oldScale * (1.0 - scrollDy * zoomSensitivity))
        .clamp(minScale, maxScale);
    appData.layersViewOffset =
        cursor + (appData.layersViewOffset - cursor) * (newScale / oldScale);
    appData.layersViewScale = newScale;
    appData.update();
  }

  Future<void> _autoSaveIfPossible(AppData appData) async {
    if (appData.selectedProject == null) {
      return;
    }
    appData.queueAutosave();
  }

  bool _isLayerSelectionModifierPressed() {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    return keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed;
  }

  Offset _parallaxImageOffsetForLayer(AppData appData, GameLayer layer) {
    final double parallax = LayoutUtils.parallaxFactorForDepth(
      layer.depth,
      sensitivity: LayoutUtils.parallaxSensitivityForSelectedLevel(appData),
    );
    return Offset(
      appData.imageOffset.dx * parallax,
      appData.imageOffset.dy * parallax,
    );
  }

  int _firstLayerIndexInSelection(Set<int> selection) {
    if (selection.isEmpty) {
      return -1;
    }
    final List<int> sorted = selection.toList()..sort();
    return sorted.first;
  }

  Rect? get _layersMarqueeRect {
    if (!_isMarqueeSelectingLayers ||
        _layersMarqueeStartLocal == null ||
        _layersMarqueeCurrentLocal == null) {
      return null;
    }
    return Rect.fromPoints(
        _layersMarqueeStartLocal!, _layersMarqueeCurrentLocal!);
  }

  void _publishLayerSelectionToAppData(AppData appData) {
    final Set<int> next = Set<int>.from(_selectedLayerIndices);
    if (appData.selectedLayerIndices.length == next.length &&
        appData.selectedLayerIndices.containsAll(next)) {
      return;
    }
    appData.selectedLayerIndices = next;
  }

  Rect? _layerScreenRect(AppData appData, GameLayer layer) {
    if (!layer.visible ||
        layer.tileMap.isEmpty ||
        layer.tileMap.first.isEmpty ||
        layer.tilesWidth <= 0 ||
        layer.tilesHeight <= 0) {
      return null;
    }
    final int rows = layer.tileMap.length;
    final int cols = layer.tileMap.first.length;
    final Offset parallaxOffset = _parallaxImageOffsetForLayer(appData, layer);
    final double scale = appData.scaleFactor;
    final double left = parallaxOffset.dx + layer.x * scale;
    final double top = parallaxOffset.dy + layer.y * scale;
    final double width = cols * layer.tilesWidth * scale;
    final double height = rows * layer.tilesHeight * scale;
    if (width <= 0 || height <= 0) {
      return null;
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  Set<int> _layerIndicesInMarqueeRect(AppData appData, Rect marqueeRect) {
    if (appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return <int>{};
    }
    final List<GameLayer> layers =
        appData.gameData.levels[appData.selectedLevel].layers;
    final Set<int> hits = <int>{};
    for (int i = 0; i < layers.length; i++) {
      final Rect? layerRect = _layerScreenRect(appData, layers[i]);
      if (layerRect == null) {
        continue;
      }
      if (marqueeRect.overlaps(layerRect)) {
        hits.add(i);
      }
    }
    return hits;
  }

  bool _applyMarqueeSelection(AppData appData) {
    final Rect? marqueeRect = _layersMarqueeRect;
    if (marqueeRect == null) {
      return false;
    }
    final Set<int> hitSelection =
        _layerIndicesInMarqueeRect(appData, marqueeRect);
    final Set<int> nextSelection = _marqueeSelectionAdditive
        ? <int>{..._marqueeBaseLayerSelection, ...hitSelection}
        : hitSelection;
    final int preferredPrimary = hitSelection.isEmpty
        ? appData.selectedLayer
        : _firstLayerIndexInSelection(hitSelection);
    return _setLayerSelection(
      appData,
      nextSelection,
      preferredPrimary: preferredPrimary,
    );
  }

  Set<int> _validatedLayerSelection(AppData appData, Iterable<int> input) {
    if (appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return <int>{};
    }
    final int layerCount =
        appData.gameData.levels[appData.selectedLevel].layers.length;
    final Set<int> output = <int>{};
    for (final int index in input) {
      if (index >= 0 && index < layerCount) {
        output.add(index);
      }
    }
    return output;
  }

  Set<int> _selectedLayersForCurrentLevel(AppData appData) {
    return _validatedLayerSelection(appData, appData.selectedLayerIndices);
  }

  bool _hasMultipleLayersSelected(AppData appData) {
    return _selectedLayersForCurrentLevel(appData).length > 1;
  }

  bool _setLayerSelection(
    AppData appData,
    Set<int> nextSelection, {
    int? preferredPrimary,
  }) {
    final Set<int> validated = _validatedLayerSelection(appData, nextSelection);
    final int nextPrimary = validated.isEmpty
        ? -1
        : (preferredPrimary != null && validated.contains(preferredPrimary)
            ? preferredPrimary
            : _firstLayerIndexInSelection(validated));
    final bool sameSelection =
        validated.length == _selectedLayerIndices.length &&
            _selectedLayerIndices.containsAll(validated);
    final bool samePrimary = appData.selectedLayer == nextPrimary;
    if (sameSelection && samePrimary) {
      return false;
    }
    _selectedLayerIndices
      ..clear()
      ..addAll(validated);
    appData.selectedLayer = nextPrimary;
    _publishLayerSelectionToAppData(appData);
    return true;
  }

  void _syncLayerSelectionState(AppData appData) {
    if ((appData.selectedSection != 'layers' &&
            appData.selectedSection != 'tilemap') ||
        appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      _selectedLayerIndices.clear();
      _layerDragOffsetsByIndex.clear();
      _isMarqueeSelectingLayers = false;
      _layersMarqueeStartLocal = null;
      _layersMarqueeCurrentLocal = null;
      _marqueeBaseLayerSelection = <int>{};
      _layerSelectionLevelIndex = -1;
      _publishLayerSelectionToAppData(appData);
      return;
    }

    if (_layerSelectionLevelIndex != appData.selectedLevel) {
      _selectedLayerIndices.clear();
      _layerDragOffsetsByIndex.clear();
      _layerSelectionLevelIndex = appData.selectedLevel;
    }

    final Set<int> validated =
        _validatedLayerSelection(appData, appData.selectedLayerIndices);
    if (validated.length != _selectedLayerIndices.length ||
        !_selectedLayerIndices.containsAll(validated)) {
      _selectedLayerIndices
        ..clear()
        ..addAll(validated);
    }

    final bool selectedLayerValid = validated.contains(appData.selectedLayer);
    final bool appDataSelectionValid = appData.selectedLayer >= 0 &&
        appData.selectedLayer <
            appData.gameData.levels[appData.selectedLevel].layers.length;
    if (selectedLayerValid || !appDataSelectionValid) {
      _publishLayerSelectionToAppData(appData);
      return;
    }

    _selectedLayerIndices
      ..clear()
      ..add(appData.selectedLayer);
    _publishLayerSelectionToAppData(appData);
  }

  bool _startDraggingSelectedLayers(AppData appData, Offset localPosition) {
    if (appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return false;
    }
    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    final Set<int> selection = _validatedLayerSelection(
      appData,
      _selectedLayerIndices,
    );
    if (selection.isEmpty) {
      return false;
    }

    final Map<int, Offset> offsets = <int, Offset>{};
    for (final int layerIndex in selection) {
      final GameLayer layer = level.layers[layerIndex];
      if (!layer.visible) {
        continue;
      }
      final Offset worldPos = LayoutUtils.translateCoords(
        localPosition,
        _parallaxImageOffsetForLayer(appData, layer),
        appData.scaleFactor,
      );
      offsets[layerIndex] =
          worldPos - Offset(layer.x.toDouble(), layer.y.toDouble());
    }
    if (offsets.isEmpty) {
      return false;
    }

    appData.pushUndo();
    _layerDragOffsetsByIndex
      ..clear()
      ..addAll(offsets);
    return true;
  }

  bool _dragSelectedLayers(AppData appData, Offset localPosition) {
    if (appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length ||
        _layerDragOffsetsByIndex.isEmpty) {
      return false;
    }
    final List<GameLayer> layers =
        appData.gameData.levels[appData.selectedLevel].layers;
    bool changed = false;

    for (final MapEntry<int, Offset> entry
        in _layerDragOffsetsByIndex.entries) {
      final int layerIndex = entry.key;
      if (layerIndex < 0 || layerIndex >= layers.length) {
        continue;
      }
      final GameLayer oldLayer = layers[layerIndex];
      final Offset worldPos = LayoutUtils.translateCoords(
        localPosition,
        _parallaxImageOffsetForLayer(appData, oldLayer),
        appData.scaleFactor,
      );
      final int newX = (worldPos.dx - entry.value.dx).round();
      final int newY = (worldPos.dy - entry.value.dy).round();
      if (newX == oldLayer.x && newY == oldLayer.y) {
        continue;
      }
      layers[layerIndex] = GameLayer(
        name: oldLayer.name,
        x: newX,
        y: newY,
        depth: oldLayer.depth,
        tilesSheetFile: oldLayer.tilesSheetFile,
        tilesWidth: oldLayer.tilesWidth,
        tilesHeight: oldLayer.tilesHeight,
        tileMap: oldLayer.tileMap,
        visible: oldLayer.visible,
        groupId: oldLayer.groupId,
      );
      changed = true;
    }

    return changed;
  }

  Future<void> _confirmAndDeleteSelectedLayers(AppData appData) async {
    if (!mounted ||
        appData.selectedSection != 'layers' ||
        appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return;
    }

    final GameLevel level = appData.gameData.levels[appData.selectedLevel];
    final List<int> selected = _validatedLayerSelection(
      appData,
      _selectedLayerIndices,
    ).toList()
      ..sort();
    if (selected.isEmpty) {
      final int selectedLayer = appData.selectedLayer;
      if (selectedLayer < 0 || selectedLayer >= level.layers.length) {
        return;
      }
      selected.add(selectedLayer);
    }

    final String message;
    if (selected.length == 1) {
      final String rawName = level.layers[selected.first].name.trim();
      final String displayName =
          rawName.isEmpty ? 'Layer ${selected.first + 1}' : rawName;
      message = 'Delete "$displayName"? This cannot be undone.';
    } else {
      message =
          'Delete ${selected.length} selected layers? This cannot be undone.';
    }

    final bool? confirmed = await CDKDialogsManager.showConfirm(
      context: context,
      title: selected.length == 1 ? 'Delete layer' : 'Delete layers',
      message: message,
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
      showBackgroundShade: true,
    );

    if (confirmed != true || !mounted) {
      return;
    }

    appData.pushUndo();
    for (int i = selected.length - 1; i >= 0; i--) {
      level.layers.removeAt(selected[i]);
    }
    _selectedLayerIndices.clear();
    _layerDragOffsetsByIndex.clear();
    _isMarqueeSelectingLayers = false;
    _layersMarqueeStartLocal = null;
    _layersMarqueeCurrentLocal = null;
    _marqueeBaseLayerSelection = <int>{};
    appData.selectedLayer = -1;
    _publishLayerSelectionToAppData(appData);
    appData.update();
    await _autoSaveIfPossible(appData);
  }

  int _firstZoneIndexInSelection(Set<int> selection) {
    if (selection.isEmpty) {
      return -1;
    }
    final List<int> sorted = selection.toList()..sort();
    return sorted.first;
  }

  Rect? get _zonesMarqueeRect {
    if (!_isMarqueeSelectingZones ||
        _zonesMarqueeStartLocal == null ||
        _zonesMarqueeCurrentLocal == null) {
      return null;
    }
    return Rect.fromPoints(
        _zonesMarqueeStartLocal!, _zonesMarqueeCurrentLocal!);
  }

  void _publishZoneSelectionToAppData(AppData appData) {
    final Set<int> next = Set<int>.from(_selectedZoneIndices);
    if (appData.selectedZoneIndices.length == next.length &&
        appData.selectedZoneIndices.containsAll(next)) {
      return;
    }
    appData.selectedZoneIndices = next;
  }

  Set<int> _validatedZoneSelection(AppData appData, Iterable<int> input) {
    if (appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return <int>{};
    }
    final int zoneCount =
        appData.gameData.levels[appData.selectedLevel].zones.length;
    final Set<int> output = <int>{};
    for (final int index in input) {
      if (index >= 0 && index < zoneCount) {
        output.add(index);
      }
    }
    return output;
  }

  Rect? _zoneScreenRect(AppData appData, GameZone zone) {
    if (zone.width <= 0 || zone.height <= 0) {
      return null;
    }
    final double scale = appData.scaleFactor;
    final double left = appData.imageOffset.dx + zone.x * scale;
    final double top = appData.imageOffset.dy + zone.y * scale;
    final double width = zone.width * scale;
    final double height = zone.height * scale;
    if (width <= 0 || height <= 0) {
      return null;
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  Set<int> _zoneIndicesInMarqueeRect(AppData appData, Rect marqueeRect) {
    if (appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return <int>{};
    }
    final List<GameZone> zones =
        appData.gameData.levels[appData.selectedLevel].zones;
    final Set<int> hits = <int>{};
    for (int i = 0; i < zones.length; i++) {
      final Rect? zoneRect = _zoneScreenRect(appData, zones[i]);
      if (zoneRect == null) {
        continue;
      }
      if (marqueeRect.overlaps(zoneRect)) {
        hits.add(i);
      }
    }
    return hits;
  }

  bool _applyZoneMarqueeSelection(AppData appData) {
    final Rect? marqueeRect = _zonesMarqueeRect;
    if (marqueeRect == null) {
      return false;
    }
    final Set<int> hitSelection =
        _zoneIndicesInMarqueeRect(appData, marqueeRect);
    final Set<int> nextSelection = _zoneMarqueeSelectionAdditive
        ? <int>{..._marqueeBaseZoneSelection, ...hitSelection}
        : hitSelection;
    final int preferredPrimary = hitSelection.isEmpty
        ? appData.selectedZone
        : _firstZoneIndexInSelection(hitSelection);
    return _setZoneSelection(
      appData,
      nextSelection,
      preferredPrimary: preferredPrimary,
    );
  }

  bool _setZoneSelection(
    AppData appData,
    Set<int> nextSelection, {
    int? preferredPrimary,
  }) {
    final Set<int> validated = _validatedZoneSelection(appData, nextSelection);
    final int nextPrimary = validated.isEmpty
        ? -1
        : (preferredPrimary != null && validated.contains(preferredPrimary)
            ? preferredPrimary
            : _firstZoneIndexInSelection(validated));
    final bool sameSelection =
        validated.length == _selectedZoneIndices.length &&
            _selectedZoneIndices.containsAll(validated);
    final bool samePrimary = appData.selectedZone == nextPrimary;
    if (sameSelection && samePrimary) {
      return false;
    }
    _selectedZoneIndices
      ..clear()
      ..addAll(validated);
    appData.selectedZone = nextPrimary;
    _publishZoneSelectionToAppData(appData);
    return true;
  }

  void _syncZoneSelectionState(AppData appData) {
    if (appData.selectedSection != 'zones' ||
        appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      _selectedZoneIndices.clear();
      _zoneDragOffsetsByIndex.clear();
      _isMarqueeSelectingZones = false;
      _zonesMarqueeStartLocal = null;
      _zonesMarqueeCurrentLocal = null;
      _marqueeBaseZoneSelection = <int>{};
      _zoneSelectionLevelIndex = -1;
      _publishZoneSelectionToAppData(appData);
      return;
    }

    if (_zoneSelectionLevelIndex != appData.selectedLevel) {
      _selectedZoneIndices.clear();
      _zoneDragOffsetsByIndex.clear();
      _zoneSelectionLevelIndex = appData.selectedLevel;
    }

    final Set<int> validated =
        _validatedZoneSelection(appData, appData.selectedZoneIndices);
    if (validated.length != _selectedZoneIndices.length ||
        !_selectedZoneIndices.containsAll(validated)) {
      _selectedZoneIndices
        ..clear()
        ..addAll(validated);
    }

    final bool selectedZoneValid = validated.contains(appData.selectedZone);
    final bool appDataSelectionValid = appData.selectedZone >= 0 &&
        appData.selectedZone <
            appData.gameData.levels[appData.selectedLevel].zones.length;
    if (selectedZoneValid || !appDataSelectionValid) {
      _publishZoneSelectionToAppData(appData);
      return;
    }

    _selectedZoneIndices
      ..clear()
      ..add(appData.selectedZone);
    _publishZoneSelectionToAppData(appData);
  }

  bool _startDraggingSelectedZones(AppData appData, Offset localPosition) {
    if (appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return false;
    }
    final List<GameZone> zones =
        appData.gameData.levels[appData.selectedLevel].zones;
    final Set<int> selection = _validatedZoneSelection(
      appData,
      _selectedZoneIndices,
    );
    if (selection.isEmpty) {
      return false;
    }

    final Offset worldPos = LayoutUtils.translateCoords(
      localPosition,
      appData.imageOffset,
      appData.scaleFactor,
    );
    final Map<int, Offset> offsets = <int, Offset>{};
    for (final int zoneIndex in selection) {
      if (zoneIndex < 0 || zoneIndex >= zones.length) {
        continue;
      }
      final GameZone zone = zones[zoneIndex];
      offsets[zoneIndex] =
          worldPos - Offset(zone.x.toDouble(), zone.y.toDouble());
    }
    if (offsets.isEmpty) {
      return false;
    }

    appData.pushUndo();
    _zoneDragOffsetsByIndex
      ..clear()
      ..addAll(offsets);
    return true;
  }

  bool _dragSelectedZones(AppData appData, Offset localPosition) {
    if (appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length ||
        _zoneDragOffsetsByIndex.isEmpty) {
      return false;
    }
    final Offset worldPos = LayoutUtils.translateCoords(
      localPosition,
      appData.imageOffset,
      appData.scaleFactor,
    );
    final List<GameZone> zones =
        appData.gameData.levels[appData.selectedLevel].zones;
    bool changed = false;
    for (final MapEntry<int, Offset> entry in _zoneDragOffsetsByIndex.entries) {
      final int zoneIndex = entry.key;
      if (zoneIndex < 0 || zoneIndex >= zones.length) {
        continue;
      }
      final GameZone zone = zones[zoneIndex];
      final int newX = (worldPos.dx - entry.value.dx).round();
      final int newY = (worldPos.dy - entry.value.dy).round();
      if (newX == zone.x && newY == zone.y) {
        continue;
      }
      zone.x = newX;
      zone.y = newY;
      changed = true;
    }
    return changed;
  }

  int _firstSpriteIndexInSelection(Set<int> selection) {
    if (selection.isEmpty) {
      return -1;
    }
    final List<int> sorted = selection.toList()..sort();
    return sorted.first;
  }

  Rect? get _spritesMarqueeRect {
    if (!_isMarqueeSelectingSprites ||
        _spritesMarqueeStartLocal == null ||
        _spritesMarqueeCurrentLocal == null) {
      return null;
    }
    return Rect.fromPoints(
      _spritesMarqueeStartLocal!,
      _spritesMarqueeCurrentLocal!,
    );
  }

  void _publishSpriteSelectionToAppData(AppData appData) {
    final Set<int> next = Set<int>.from(_selectedSpriteIndices);
    if (appData.selectedSpriteIndices.length == next.length &&
        appData.selectedSpriteIndices.containsAll(next)) {
      return;
    }
    appData.selectedSpriteIndices = next;
  }

  Set<int> _validatedSpriteSelection(AppData appData, Iterable<int> input) {
    if (appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return <int>{};
    }
    final int spriteCount =
        appData.gameData.levels[appData.selectedLevel].sprites.length;
    final Set<int> output = <int>{};
    for (final int index in input) {
      if (index >= 0 && index < spriteCount) {
        output.add(index);
      }
    }
    return output;
  }

  Rect? _spriteScreenRect(AppData appData, GameSprite sprite) {
    final Size frameSize = LayoutUtils.spriteFrameSize(appData, sprite);
    if (frameSize.width <= 0 || frameSize.height <= 0) {
      return null;
    }
    final double scale = appData.scaleFactor;
    return Rect.fromLTWH(
      appData.imageOffset.dx + sprite.x * scale,
      appData.imageOffset.dy + sprite.y * scale,
      frameSize.width * scale,
      frameSize.height * scale,
    );
  }

  Set<int> _spriteIndicesInMarqueeRect(AppData appData, Rect marqueeRect) {
    if (appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return <int>{};
    }
    final List<GameSprite> sprites =
        appData.gameData.levels[appData.selectedLevel].sprites;
    final Set<int> hits = <int>{};
    for (int i = 0; i < sprites.length; i++) {
      final Rect? spriteRect = _spriteScreenRect(appData, sprites[i]);
      if (spriteRect == null) {
        continue;
      }
      if (marqueeRect.overlaps(spriteRect)) {
        hits.add(i);
      }
    }
    return hits;
  }

  bool _applySpriteMarqueeSelection(AppData appData) {
    final Rect? marqueeRect = _spritesMarqueeRect;
    if (marqueeRect == null) {
      return false;
    }
    final Set<int> hitSelection =
        _spriteIndicesInMarqueeRect(appData, marqueeRect);
    final Set<int> nextSelection = _spriteMarqueeSelectionAdditive
        ? <int>{..._marqueeBaseSpriteSelection, ...hitSelection}
        : hitSelection;
    final int preferredPrimary = hitSelection.isEmpty
        ? appData.selectedSprite
        : _firstSpriteIndexInSelection(hitSelection);
    return _setSpriteSelection(
      appData,
      nextSelection,
      preferredPrimary: preferredPrimary,
    );
  }

  bool _setSpriteSelection(
    AppData appData,
    Set<int> nextSelection, {
    int? preferredPrimary,
  }) {
    final Set<int> validated =
        _validatedSpriteSelection(appData, nextSelection);
    final int nextPrimary = validated.isEmpty
        ? -1
        : (preferredPrimary != null && validated.contains(preferredPrimary)
            ? preferredPrimary
            : _firstSpriteIndexInSelection(validated));
    final bool sameSelection =
        validated.length == _selectedSpriteIndices.length &&
            _selectedSpriteIndices.containsAll(validated);
    final bool samePrimary = appData.selectedSprite == nextPrimary;
    if (sameSelection && samePrimary) {
      return false;
    }
    _selectedSpriteIndices
      ..clear()
      ..addAll(validated);
    appData.selectedSprite = nextPrimary;
    _publishSpriteSelectionToAppData(appData);
    return true;
  }

  void _syncSpriteSelectionState(AppData appData) {
    if (appData.selectedSection != 'sprites' ||
        appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      _selectedSpriteIndices.clear();
      _spriteDragOffsetsByIndex.clear();
      _isMarqueeSelectingSprites = false;
      _spriteMarqueeSelectionAdditive = false;
      _spritesMarqueeStartLocal = null;
      _spritesMarqueeCurrentLocal = null;
      _marqueeBaseSpriteSelection = <int>{};
      _spriteSelectionLevelIndex = -1;
      _publishSpriteSelectionToAppData(appData);
      return;
    }

    if (_spriteSelectionLevelIndex != appData.selectedLevel) {
      _selectedSpriteIndices.clear();
      _spriteDragOffsetsByIndex.clear();
      _spriteSelectionLevelIndex = appData.selectedLevel;
    }

    final Set<int> validated =
        _validatedSpriteSelection(appData, appData.selectedSpriteIndices);
    if (validated.length != _selectedSpriteIndices.length ||
        !_selectedSpriteIndices.containsAll(validated)) {
      _selectedSpriteIndices
        ..clear()
        ..addAll(validated);
    }

    final bool selectedSpriteValid = validated.contains(appData.selectedSprite);
    final bool appDataSelectionValid = appData.selectedSprite >= 0 &&
        appData.selectedSprite <
            appData.gameData.levels[appData.selectedLevel].sprites.length;
    if (selectedSpriteValid || !appDataSelectionValid) {
      _publishSpriteSelectionToAppData(appData);
      return;
    }

    _selectedSpriteIndices
      ..clear()
      ..add(appData.selectedSprite);
    _publishSpriteSelectionToAppData(appData);
  }

  bool _startDraggingSelectedSprites(AppData appData, Offset localPosition) {
    if (appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length) {
      return false;
    }
    final List<GameSprite> sprites =
        appData.gameData.levels[appData.selectedLevel].sprites;
    final Set<int> selection = _validatedSpriteSelection(
      appData,
      _selectedSpriteIndices,
    );
    if (selection.isEmpty) {
      return false;
    }

    final Offset worldPos = LayoutUtils.translateCoords(
      localPosition,
      appData.imageOffset,
      appData.scaleFactor,
    );
    final Map<int, Offset> offsets = <int, Offset>{};
    for (final int spriteIndex in selection) {
      if (spriteIndex < 0 || spriteIndex >= sprites.length) {
        continue;
      }
      final GameSprite sprite = sprites[spriteIndex];
      offsets[spriteIndex] =
          worldPos - Offset(sprite.x.toDouble(), sprite.y.toDouble());
    }
    if (offsets.isEmpty) {
      return false;
    }

    appData.pushUndo();
    _spriteDragOffsetsByIndex
      ..clear()
      ..addAll(offsets);
    return true;
  }

  bool _dragSelectedSprites(AppData appData, Offset localPosition) {
    if (appData.selectedLevel < 0 ||
        appData.selectedLevel >= appData.gameData.levels.length ||
        _spriteDragOffsetsByIndex.isEmpty) {
      return false;
    }
    final Offset worldPos = LayoutUtils.translateCoords(
      localPosition,
      appData.imageOffset,
      appData.scaleFactor,
    );
    final List<GameSprite> sprites =
        appData.gameData.levels[appData.selectedLevel].sprites;
    bool changed = false;
    for (final MapEntry<int, Offset> entry
        in _spriteDragOffsetsByIndex.entries) {
      final int spriteIndex = entry.key;
      if (spriteIndex < 0 || spriteIndex >= sprites.length) {
        continue;
      }
      final GameSprite sprite = sprites[spriteIndex];
      final int newX = (worldPos.dx - entry.value.dx).round();
      final int newY = (worldPos.dy - entry.value.dy).round();
      if (newX == sprite.x && newY == sprite.y) {
        continue;
      }
      sprite.x = newX;
      sprite.y = newY;
      changed = true;
    }
    return changed;
  }

  void _queueInitialLayersViewportCenter(AppData appData, Size viewportSize) {
    if (appData.selectedSection != 'layers' &&
        appData.selectedSection != 'tilemap' &&
        appData.selectedSection != 'zones' &&
        appData.selectedSection != 'sprites') {
      return;
    }
    if (appData.layersViewScale != 1.0 ||
        appData.layersViewOffset != Offset.zero) {
      return;
    }
    if (_pendingLayersViewportCenter) return;
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return;

    _pendingLayersViewportCenter = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingLayersViewportCenter = false;
      if (!mounted) return;

      final latestAppData = Provider.of<AppData>(context, listen: false);
      if (latestAppData.selectedSection != 'layers' &&
          latestAppData.selectedSection != 'tilemap' &&
          latestAppData.selectedSection != 'zones' &&
          latestAppData.selectedSection != 'sprites') {
        return;
      }
      if (latestAppData.layersViewScale != 1.0 ||
          latestAppData.layersViewOffset != Offset.zero) {
        return;
      }

      latestAppData.layersViewOffset = Offset(
        viewportSize.width / 2,
        viewportSize.height / 2,
      );
      latestAppData.update();
    });
  }

  void _fitLevelLayersToViewport(
    AppData appData,
    int levelIndex,
    Size viewportSize,
  ) {
    if (levelIndex < 0 || levelIndex >= appData.gameData.levels.length) {
      return;
    }
    final level = appData.gameData.levels[levelIndex];

    Rect? worldBounds;
    for (final layer in level.layers) {
      final int rows = layer.tileMap.length;
      final int cols = rows == 0 ? 0 : layer.tileMap.first.length;
      if (rows <= 0 ||
          cols <= 0 ||
          layer.tilesWidth <= 0 ||
          layer.tilesHeight <= 0) {
        continue;
      }
      final Rect layerRect = Rect.fromLTWH(
        layer.x.toDouble(),
        layer.y.toDouble(),
        cols * layer.tilesWidth.toDouble(),
        rows * layer.tilesHeight.toDouble(),
      );
      worldBounds = worldBounds == null
          ? layerRect
          : worldBounds.expandToInclude(layerRect);
    }

    if (worldBounds == null ||
        worldBounds.width <= 0 ||
        worldBounds.height <= 0 ||
        viewportSize.width <= 0 ||
        viewportSize.height <= 0) {
      appData.layersViewScale = 1.0;
      appData.layersViewOffset = Offset(
        viewportSize.width / 2,
        viewportSize.height / 2,
      );
      appData.update();
      return;
    }

    const double minScale = 0.05;
    const double maxScale = 20.0;
    const double framePaddingFactor = 0.9;
    final double scaleX =
        (viewportSize.width * framePaddingFactor) / worldBounds.width;
    final double scaleY =
        (viewportSize.height * framePaddingFactor) / worldBounds.height;
    final double fittedScale =
        (scaleX < scaleY ? scaleX : scaleY).clamp(minScale, maxScale);
    final Offset viewportCenter =
        Offset(viewportSize.width / 2, viewportSize.height / 2);
    final Offset targetOffset =
        viewportCenter - worldBounds.center * fittedScale;

    appData.layersViewScale = fittedScale;
    appData.layersViewOffset = targetOffset;
    appData.update();
  }

  void _queueSelectedLevelViewportFit(AppData appData, Size viewportSize) {
    if (appData.selectedSection != 'levels') {
      return;
    }
    final int levelIndex = appData.selectedLevel;
    if (levelIndex < 0 || levelIndex >= appData.gameData.levels.length) {
      _lastAutoFramedLevelIndex = null;
      return;
    }
    if (_lastAutoFramedLevelIndex == levelIndex) {
      return;
    }
    if (_pendingLevelsViewportFitLevelIndex == levelIndex) {
      return;
    }
    if (viewportSize.width <= 0 || viewportSize.height <= 0) {
      return;
    }

    _pendingLevelsViewportFitLevelIndex = levelIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingLevelsViewportFitLevelIndex == levelIndex) {
        _pendingLevelsViewportFitLevelIndex = null;
      }
      if (!mounted) {
        return;
      }
      final AppData latestAppData =
          Provider.of<AppData>(context, listen: false);
      if (latestAppData.selectedSection != 'levels') {
        return;
      }
      if (latestAppData.selectedLevel != levelIndex) {
        _queueSelectedLevelViewportFit(latestAppData, viewportSize);
        return;
      }

      _fitLevelLayersToViewport(latestAppData, levelIndex, viewportSize);
      _lastAutoFramedLevelIndex = levelIndex;
    });
  }

  MouseCursor _tilemapCursor(AppData appData) {
    if (appData.selectedSection != 'tilemap') {
      return SystemMouseCursors.basic;
    }
    if (_layersHandToolActive) {
      return SystemMouseCursors.basic;
    }
    if (_isDragGestureActive) {
      return SystemMouseCursors.basic;
    }
    if (appData.tilemapEraserEnabled && _isHoveringSelectedTilemapLayer) {
      return SystemMouseCursors.disappearing;
    }
    if (LayoutUtils.hasTilePatternSelection(appData) &&
        _isHoveringSelectedTilemapLayer) {
      return SystemMouseCursors.copy;
    }
    return SystemMouseCursors.basic;
  }

  bool get _layersArrowToolActive =>
      _layersCanvasTool == _LayersCanvasTool.arrow;
  bool get _layersHandToolActive => _layersCanvasTool == _LayersCanvasTool.hand;

  Widget _buildLayersToolPickerOverlay() {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          width: 80,
          child: CDKPickerButtonsBar(
            selectedStates: <bool>[
              _layersArrowToolActive,
              _layersHandToolActive
            ],
            options: const [
              Icon(CupertinoIcons.cursor_rays),
              Icon(CupertinoIcons.hand_raised),
            ],
            onChanged: (states) {
              setState(() {
                _layersCanvasTool = states.length > 1 && states[1] == true
                    ? _LayersCanvasTool.hand
                    : _LayersCanvasTool.arrow;
              });
            },
          ),
        ),
      ),
    );
  }

  bool _usesWorldViewportSection(String section) {
    return section == 'levels' ||
        section == 'layers' ||
        section == 'tilemap' ||
        section == 'zones' ||
        section == 'sprites' ||
        section == 'viewport';
  }

  void _resetWorldViewport(AppData appData, Size viewportSize) {
    if (!_usesWorldViewportSection(appData.selectedSection)) {
      return;
    }
    final int levelIndex = appData.selectedLevel;
    if (levelIndex < 0 || levelIndex >= appData.gameData.levels.length) {
      return;
    }
    _fitLevelLayersToViewport(appData, levelIndex, viewportSize);
    _lastAutoFramedLevelIndex = levelIndex;
  }

  Widget _buildWorldResetOverlay(AppData appData, Size viewportSize) {
    final bool canReset = _usesWorldViewportSection(appData.selectedSection) &&
        appData.selectedLevel >= 0 &&
        appData.selectedLevel < appData.gameData.levels.length;
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: CDKButton(
          style: CDKButtonStyle.normal,
          onPressed: canReset
              ? () => _resetWorldViewport(appData, viewportSize)
              : null,
          child: const Icon(CupertinoIcons.viewfinder),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    _syncLayerSelectionState(appData);
    _syncZoneSelectionState(appData);
    _syncSpriteSelectionState(appData);

    if (appData.selectedSection != 'projects') {
      _drawCanvasImage(appData);
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: CDKPickerButtonsSegmented(
            selectedIndex: _selectedSectionIndex(appData.selectedSection),
            options: _buildSegmentedOptions(context),
            onSelected: (index) => unawaited(
              _onTabSelected(appData, sections[index]),
            ),
          ),
        ),
        trailing: appData.autosaveInlineMessage.isEmpty
            ? null
            : SizedBox(
                width: 220,
                child: CDKText(
                  appData.autosaveInlineMessage,
                  role: CDKTextRole.caption,
                  color: appData.autosaveHasError
                      ? CupertinoColors.systemRed
                      : cdkColors.colorTextSecondary,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
      ),
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final AppData appData = Provider.of<AppData>(context, listen: false);
          final bool isDeleteKey =
              event.logicalKey == LogicalKeyboardKey.backspace ||
                  event.logicalKey == LogicalKeyboardKey.delete;
          if (isDeleteKey && appData.selectedSection == 'layers') {
            unawaited(_confirmAndDeleteSelectedLayers(appData));
            return KeyEventResult.handled;
          }
          final bool meta = HardwareKeyboard.instance.isMetaPressed;
          final bool ctrl = HardwareKeyboard.instance.isControlPressed;
          final bool shift = HardwareKeyboard.instance.isShiftPressed;
          final bool isZ = event.logicalKey == LogicalKeyboardKey.keyZ;
          if (!(meta || ctrl) || !isZ) return KeyEventResult.ignored;
          if (shift) {
            appData.redo();
          } else {
            appData.undo();
          }
          return KeyEventResult.handled;
        },
        child: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: appData.selectedSection == 'projects'
                        ? Container(
                            color: cdkColors.backgroundSecondary1,
                            child: const LayoutProjectsMain(),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final Size viewportSize = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              _queueSelectedLevelViewportFit(
                                appData,
                                viewportSize,
                              );
                              _queueInitialLayersViewportCenter(
                                appData,
                                viewportSize,
                              );
                              return Container(
                                color: cdkColors.backgroundSecondary1,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Listener(
                                        onPointerDown: (_) =>
                                            _isPointerDown = true,
                                        onPointerUp: (_) =>
                                            _isPointerDown = false,
                                        onPointerCancel: (_) =>
                                            _isPointerDown = false,
                                        // macOS trackpad: two-finger scroll → PointerScrollEvent
                                        onPointerSignal: (event) {
                                          if (event is! PointerScrollEvent) {
                                            return;
                                          }
                                          if (appData.selectedSection != "levels" &&
                                              appData.selectedSection !=
                                                  "layers" &&
                                              appData.selectedSection !=
                                                  "tilemap" &&
                                              appData.selectedSection !=
                                                  "zones" &&
                                              appData.selectedSection !=
                                                  "sprites" &&
                                              appData.selectedSection !=
                                                  "viewport") {
                                            return;
                                          }
                                          _applyLayersZoom(
                                              appData,
                                              event.localPosition,
                                              event.scrollDelta.dy);
                                        },
                                        // macOS trackpad: two-finger pan-zoom → PointerPanZoomUpdateEvent
                                        onPointerPanZoomUpdate: (event) {
                                          if (appData.selectedSection != "levels" &&
                                              appData.selectedSection !=
                                                  "layers" &&
                                              appData.selectedSection !=
                                                  "tilemap" &&
                                              appData.selectedSection !=
                                                  "zones" &&
                                              appData.selectedSection !=
                                                  "sprites" &&
                                              appData.selectedSection !=
                                                  "viewport") {
                                            return;
                                          }
                                          // pan delta from trackpad scroll
                                          final double dy = -event.panDelta.dy;
                                          if (dy == 0) return;
                                          _applyLayersZoom(
                                              appData, event.localPosition, dy);
                                        },
                                        child: MouseRegion(
                                          cursor: _tilemapCursor(appData),
                                          onHover: (event) {
                                            final bool hoveringTilemapLayer =
                                                appData.selectedSection ==
                                                        'tilemap' &&
                                                    LayoutUtils.getTilemapCoords(
                                                            appData,
                                                            event
                                                                .localPosition) !=
                                                        null;
                                            if (hoveringTilemapLayer !=
                                                _isHoveringSelectedTilemapLayer) {
                                              setState(() {
                                                _isHoveringSelectedTilemapLayer =
                                                    hoveringTilemapLayer;
                                              });
                                            }
                                          },
                                          onExit: (_) {
                                            if (_isHoveringSelectedTilemapLayer) {
                                              setState(() {
                                                _isHoveringSelectedTilemapLayer =
                                                    false;
                                              });
                                            }
                                          },
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onPanStart: (details) async {
                                              if (!_isPointerDown) {
                                                return;
                                              }
                                              if (!_isDragGestureActive) {
                                                setState(() {
                                                  _isDragGestureActive = true;
                                                });
                                              }
                                              appData.dragging = true;
                                              appData.dragStartDetails =
                                                  details;
                                              if (appData.selectedSection ==
                                                  "levels") {
                                                // Levels section is preview-only: always pan.
                                              } else if (appData
                                                      .selectedSection ==
                                                  "viewport") {
                                                _isDraggingViewport = false;
                                                _isResizingViewport = false;
                                                LayoutUtils
                                                    .ensureViewportPreviewInitialized(
                                                  appData,
                                                );
                                                if (LayoutUtils
                                                    .isPointInViewportResizeHandle(
                                                        appData,
                                                        details
                                                            .localPosition)) {
                                                  _isResizingViewport = true;
                                                  LayoutUtils
                                                      .startResizeViewportFromPosition(
                                                    appData,
                                                    details.localPosition,
                                                  );
                                                } else if (LayoutUtils
                                                    .isPointInViewportRect(
                                                        appData,
                                                        details
                                                            .localPosition)) {
                                                  _isDraggingViewport = true;
                                                  LayoutUtils
                                                      .startDragViewportFromPosition(
                                                    appData,
                                                    details.localPosition,
                                                  );
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "layers") {
                                                _isDraggingLayer = false;
                                                _didModifyLayerDuringGesture =
                                                    false;
                                                _layerDragOffsetsByIndex
                                                    .clear();
                                                if (_layersHandToolActive) {
                                                  return;
                                                }
                                                final int hitLayerIndex =
                                                    LayoutUtils
                                                        .selectLayerFromPosition(
                                                  appData,
                                                  details.localPosition,
                                                );
                                                final bool additiveSelection =
                                                    _isLayerSelectionModifierPressed();
                                                if (hitLayerIndex == -1) {
                                                  _isMarqueeSelectingLayers =
                                                      true;
                                                  _marqueeSelectionAdditive =
                                                      additiveSelection;
                                                  _layersMarqueeStartLocal =
                                                      details.localPosition;
                                                  _layersMarqueeCurrentLocal =
                                                      details.localPosition;
                                                  _marqueeBaseLayerSelection =
                                                      additiveSelection
                                                          ? <int>{
                                                              ..._selectedLayerIndices,
                                                            }
                                                          : <int>{};
                                                  final bool selectionChanged =
                                                      _applyMarqueeSelection(
                                                          appData);
                                                  setState(() {});
                                                  if (selectionChanged) {
                                                    appData.update();
                                                  }
                                                  return;
                                                }
                                                if (additiveSelection) {
                                                  return;
                                                }
                                                bool selectionChanged = false;
                                                if (!_selectedLayerIndices
                                                    .contains(hitLayerIndex)) {
                                                  selectionChanged =
                                                      _setLayerSelection(
                                                    appData,
                                                    <int>{hitLayerIndex},
                                                    preferredPrimary:
                                                        hitLayerIndex,
                                                  );
                                                }
                                                if (_startDraggingSelectedLayers(
                                                  appData,
                                                  details.localPosition,
                                                )) {
                                                  _isDraggingLayer = true;
                                                }
                                                if (selectionChanged) {
                                                  appData.update();
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "tilemap") {
                                                if (_layersHandToolActive) {
                                                  _isPaintingTilemap = false;
                                                  _didModifyTilemapDuringGesture =
                                                      false;
                                                  return;
                                                }
                                                if (_hasMultipleLayersSelected(
                                                  appData,
                                                )) {
                                                  _isPaintingTilemap = false;
                                                  _didModifyTilemapDuringGesture =
                                                      false;
                                                  return;
                                                }
                                                final bool useEraser = appData
                                                    .tilemapEraserEnabled;
                                                final bool hasTileSelection =
                                                    LayoutUtils
                                                        .hasTilePatternSelection(
                                                            appData);
                                                final bool startsInsideLayer =
                                                    LayoutUtils.getTilemapCoords(
                                                            appData,
                                                            details
                                                                .localPosition) !=
                                                        null;
                                                _isPaintingTilemap =
                                                    startsInsideLayer &&
                                                        (useEraser ||
                                                            hasTileSelection);
                                                _didModifyTilemapDuringGesture =
                                                    false;
                                                if (_isPaintingTilemap) {
                                                  final bool changed = useEraser
                                                      ? LayoutUtils
                                                          .eraseTileAtTilemap(
                                                          appData,
                                                          details.localPosition,
                                                          pushUndo: true,
                                                        )
                                                      : LayoutUtils
                                                          .pasteSelectedTilePatternAtTilemap(
                                                          appData,
                                                          details.localPosition,
                                                          pushUndo: true,
                                                        );
                                                  if (changed) {
                                                    _didModifyTilemapDuringGesture =
                                                        true;
                                                    appData.update();
                                                  }
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "zones") {
                                                _didModifyZoneDuringGesture =
                                                    false;
                                                _isDraggingZone = false;
                                                _isResizingZone = false;
                                                _zoneDragOffsetsByIndex.clear();
                                                if (_layersHandToolActive) {
                                                  return;
                                                }
                                                final bool additiveSelection =
                                                    _isLayerSelectionModifierPressed();
                                                final int selectedZone =
                                                    appData.selectedZone;
                                                final bool
                                                    startsOnResizeHandle =
                                                    !additiveSelection &&
                                                        _selectedZoneIndices
                                                                .length ==
                                                            1 &&
                                                        selectedZone != -1 &&
                                                        LayoutUtils
                                                            .isPointInZoneResizeHandle(
                                                          appData,
                                                          selectedZone,
                                                          details.localPosition,
                                                        );
                                                if (startsOnResizeHandle) {
                                                  _isResizingZone = true;
                                                  LayoutUtils
                                                      .startResizeZoneFromPosition(
                                                    appData,
                                                    details.localPosition,
                                                  );
                                                  layoutZonesKey.currentState
                                                      ?.updateForm(appData);
                                                  return;
                                                }
                                                final int hitZone = LayoutUtils
                                                    .zoneIndexFromPosition(
                                                  appData,
                                                  details.localPosition,
                                                );
                                                if (hitZone == -1) {
                                                  _isMarqueeSelectingZones =
                                                      true;
                                                  _zoneMarqueeSelectionAdditive =
                                                      additiveSelection;
                                                  _zonesMarqueeStartLocal =
                                                      details.localPosition;
                                                  _zonesMarqueeCurrentLocal =
                                                      details.localPosition;
                                                  _marqueeBaseZoneSelection =
                                                      additiveSelection
                                                          ? <int>{
                                                              ..._selectedZoneIndices,
                                                            }
                                                          : <int>{};
                                                  final bool selectionChanged =
                                                      _applyZoneMarqueeSelection(
                                                          appData);
                                                  setState(() {});
                                                  if (selectionChanged) {
                                                    appData.update();
                                                    layoutZonesKey.currentState
                                                        ?.updateForm(appData);
                                                  }
                                                  return;
                                                }
                                                if (additiveSelection) {
                                                  return;
                                                }
                                                bool selectionChanged = false;
                                                if (!_selectedZoneIndices
                                                    .contains(hitZone)) {
                                                  selectionChanged =
                                                      _setZoneSelection(
                                                    appData,
                                                    <int>{hitZone},
                                                    preferredPrimary: hitZone,
                                                  );
                                                }
                                                if (_startDraggingSelectedZones(
                                                  appData,
                                                  details.localPosition,
                                                )) {
                                                  _isDraggingZone = true;
                                                }
                                                if (selectionChanged) {
                                                  appData.update();
                                                  layoutZonesKey.currentState
                                                      ?.updateForm(appData);
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "sprites") {
                                                _didModifySpriteDuringGesture =
                                                    false;
                                                _isDraggingSprite = false;
                                                _spriteDragOffsetsByIndex
                                                    .clear();
                                                if (_layersHandToolActive) {
                                                  return;
                                                }
                                                final int hitSpriteIndex =
                                                    LayoutUtils
                                                        .spriteIndexFromPosition(
                                                  appData,
                                                  details.localPosition,
                                                );
                                                final bool additiveSelection =
                                                    _isLayerSelectionModifierPressed();
                                                if (hitSpriteIndex == -1) {
                                                  _isMarqueeSelectingSprites =
                                                      true;
                                                  _spriteMarqueeSelectionAdditive =
                                                      additiveSelection;
                                                  _spritesMarqueeStartLocal =
                                                      details.localPosition;
                                                  _spritesMarqueeCurrentLocal =
                                                      details.localPosition;
                                                  _marqueeBaseSpriteSelection =
                                                      additiveSelection
                                                          ? <int>{
                                                              ..._selectedSpriteIndices,
                                                            }
                                                          : <int>{};
                                                  final bool selectionChanged =
                                                      _applySpriteMarqueeSelection(
                                                    appData,
                                                  );
                                                  setState(() {});
                                                  if (selectionChanged) {
                                                    appData.update();
                                                    layoutSpritesKey
                                                        .currentState
                                                        ?.updateForm(appData);
                                                  }
                                                  return;
                                                }
                                                if (additiveSelection) {
                                                  return;
                                                }
                                                bool selectionChanged = false;
                                                if (!_selectedSpriteIndices
                                                    .contains(hitSpriteIndex)) {
                                                  selectionChanged =
                                                      _setSpriteSelection(
                                                    appData,
                                                    <int>{hitSpriteIndex},
                                                    preferredPrimary:
                                                        hitSpriteIndex,
                                                  );
                                                }
                                                if (_startDraggingSelectedSprites(
                                                  appData,
                                                  details.localPosition,
                                                )) {
                                                  _isDraggingSprite = true;
                                                }
                                                if (selectionChanged) {
                                                  appData.update();
                                                  layoutSpritesKey.currentState
                                                      ?.updateForm(appData);
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "animations") {
                                                _isSelectingAnimationFrames =
                                                    false;
                                                _didModifyAnimationDuringGesture =
                                                    false;
                                                _animationDragStartFrame = null;
                                                final int frame = await LayoutUtils
                                                    .animationFrameIndexFromCanvas(
                                                  appData,
                                                  details.localPosition,
                                                );
                                                if (frame != -1) {
                                                  _isSelectingAnimationFrames =
                                                      true;
                                                  _animationDragStartFrame =
                                                      frame;
                                                  final bool changed =
                                                      await LayoutUtils
                                                          .setAnimationSelectionFromEndpoints(
                                                    appData: appData,
                                                    startFrame: frame,
                                                    endFrame: frame,
                                                  );
                                                  if (changed) {
                                                    _didModifyAnimationDuringGesture =
                                                        true;
                                                    appData.update();
                                                  }
                                                }
                                              }
                                            },
                                            onPanUpdate: (details) async {
                                              if (appData.selectedSection ==
                                                  "levels") {
                                                if (_isPointerDown) {
                                                  appData.layersViewOffset +=
                                                      details.delta;
                                                  appData.update();
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "viewport") {
                                                if (!_isPointerDown) {
                                                  // scroll-triggered pan — ignore
                                                } else if (_isResizingViewport) {
                                                  LayoutUtils
                                                      .resizeViewportFromCanvas(
                                                          appData,
                                                          details
                                                              .localPosition);
                                                  appData.update();
                                                } else if (_isDraggingViewport) {
                                                  LayoutUtils
                                                      .dragViewportFromCanvas(
                                                          appData,
                                                          details
                                                              .localPosition);
                                                  appData.update();
                                                } else {
                                                  appData.layersViewOffset +=
                                                      details.delta;
                                                  appData.update();
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "layers") {
                                                if (!_isPointerDown) {
                                                  // scroll-triggered pan — ignore
                                                } else if (_isMarqueeSelectingLayers) {
                                                  _layersMarqueeCurrentLocal =
                                                      details.localPosition;
                                                  final bool selectionChanged =
                                                      _applyMarqueeSelection(
                                                    appData,
                                                  );
                                                  setState(() {});
                                                  if (selectionChanged) {
                                                    appData.update();
                                                  }
                                                } else if (_isDraggingLayer) {
                                                  final bool changed =
                                                      _dragSelectedLayers(
                                                    appData,
                                                    details.localPosition,
                                                  );
                                                  if (changed) {
                                                    _didModifyLayerDuringGesture =
                                                        true;
                                                    appData.update();
                                                  }
                                                } else if (_layersHandToolActive) {
                                                  appData.layersViewOffset +=
                                                      details.delta;
                                                  appData.update();
                                                } else {
                                                  // Arrow tool: no world navigation.
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "tilemap") {
                                                if (_layersHandToolActive) {
                                                  appData.layersViewOffset +=
                                                      details.delta;
                                                  appData.update();
                                                  return;
                                                }
                                                if (_hasMultipleLayersSelected(
                                                  appData,
                                                )) {
                                                  _isPaintingTilemap = false;
                                                  return;
                                                }
                                                if (!_isPointerDown) {
                                                  // scroll-triggered pan — ignore
                                                } else if (_isPaintingTilemap) {
                                                  final bool useEraser = appData
                                                      .tilemapEraserEnabled;
                                                  final bool isInsideLayer =
                                                      LayoutUtils.getTilemapCoords(
                                                              appData,
                                                              details
                                                                  .localPosition) !=
                                                          null;
                                                  if (!isInsideLayer) {
                                                    _isPaintingTilemap = false;
                                                    return;
                                                  }
                                                  final bool changed = useEraser
                                                      ? LayoutUtils
                                                          .eraseTileAtTilemap(
                                                          appData,
                                                          details.localPosition,
                                                          pushUndo:
                                                              !_didModifyTilemapDuringGesture,
                                                        )
                                                      : LayoutUtils
                                                          .pasteSelectedTilePatternAtTilemap(
                                                          appData,
                                                          details.localPosition,
                                                          pushUndo:
                                                              !_didModifyTilemapDuringGesture,
                                                        );
                                                  if (changed) {
                                                    _didModifyTilemapDuringGesture =
                                                        true;
                                                    appData.update();
                                                  }
                                                } else {
                                                  // Arrow tool: no world navigation.
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "zones") {
                                                if (!_isPointerDown) {
                                                  // scroll-triggered pan — ignore
                                                } else if (_isMarqueeSelectingZones) {
                                                  _zonesMarqueeCurrentLocal =
                                                      details.localPosition;
                                                  final bool selectionChanged =
                                                      _applyZoneMarqueeSelection(
                                                    appData,
                                                  );
                                                  setState(() {});
                                                  if (selectionChanged) {
                                                    appData.update();
                                                    layoutZonesKey.currentState
                                                        ?.updateForm(appData);
                                                  }
                                                } else if (_isResizingZone &&
                                                    appData.selectedZone !=
                                                        -1) {
                                                  LayoutUtils
                                                      .resizeZoneFromCanvas(
                                                          appData,
                                                          details
                                                              .localPosition);
                                                  _didModifyZoneDuringGesture =
                                                      true;
                                                  appData.update();
                                                  layoutZonesKey.currentState
                                                      ?.updateForm(appData);
                                                } else if (_isDraggingZone &&
                                                    _selectedZoneIndices
                                                        .isNotEmpty) {
                                                  final bool changed =
                                                      _dragSelectedZones(
                                                    appData,
                                                    details.localPosition,
                                                  );
                                                  if (changed) {
                                                    _didModifyZoneDuringGesture =
                                                        true;
                                                    appData.update();
                                                    layoutZonesKey.currentState
                                                        ?.updateForm(appData);
                                                  }
                                                } else if (_layersHandToolActive) {
                                                  appData.layersViewOffset +=
                                                      details.delta;
                                                  appData.update();
                                                } else {
                                                  // Arrow tool: no world navigation.
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "sprites") {
                                                if (!_isPointerDown) {
                                                  // scroll-triggered pan — ignore
                                                } else if (_isMarqueeSelectingSprites) {
                                                  _spritesMarqueeCurrentLocal =
                                                      details.localPosition;
                                                  final bool selectionChanged =
                                                      _applySpriteMarqueeSelection(
                                                    appData,
                                                  );
                                                  setState(() {});
                                                  if (selectionChanged) {
                                                    appData.update();
                                                    layoutSpritesKey
                                                        .currentState
                                                        ?.updateForm(appData);
                                                  }
                                                } else if (_isDraggingSprite &&
                                                    _selectedSpriteIndices
                                                        .isNotEmpty) {
                                                  final bool changed =
                                                      _dragSelectedSprites(
                                                    appData,
                                                    details.localPosition,
                                                  );
                                                  if (changed) {
                                                    _didModifySpriteDuringGesture =
                                                        true;
                                                    appData.update();
                                                    layoutSpritesKey
                                                        .currentState
                                                        ?.updateForm(appData);
                                                  }
                                                } else if (_layersHandToolActive) {
                                                  appData.layersViewOffset +=
                                                      details.delta;
                                                  appData.update();
                                                } else {
                                                  // Arrow tool: no world navigation.
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "animations") {
                                                if (!_isPointerDown) {
                                                  // scroll-triggered pan — ignore
                                                } else if (_isSelectingAnimationFrames &&
                                                    _animationDragStartFrame !=
                                                        null) {
                                                  final int frame =
                                                      await LayoutUtils
                                                          .animationFrameIndexFromCanvas(
                                                    appData,
                                                    details.localPosition,
                                                  );
                                                  if (frame == -1) {
                                                    return;
                                                  }
                                                  final bool changed =
                                                      await LayoutUtils
                                                          .setAnimationSelectionFromEndpoints(
                                                    appData: appData,
                                                    startFrame:
                                                        _animationDragStartFrame!,
                                                    endFrame: frame,
                                                  );
                                                  if (changed) {
                                                    _didModifyAnimationDuringGesture =
                                                        true;
                                                    appData.update();
                                                  }
                                                }
                                              }
                                            },
                                            onPanEnd: (details) async {
                                              if (_isDragGestureActive) {
                                                setState(() {
                                                  _isDragGestureActive = false;
                                                });
                                              }
                                              if (appData.selectedSection ==
                                                  "viewport") {
                                                if (_isDraggingViewport ||
                                                    _isResizingViewport) {
                                                  _isDraggingViewport = false;
                                                  _isResizingViewport = false;
                                                  LayoutUtils.endViewportDrag(
                                                      appData);
                                                  appData.update();
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "layers") {
                                                if (_isMarqueeSelectingLayers) {
                                                  _isMarqueeSelectingLayers =
                                                      false;
                                                  _marqueeSelectionAdditive =
                                                      false;
                                                  _layersMarqueeStartLocal =
                                                      null;
                                                  _layersMarqueeCurrentLocal =
                                                      null;
                                                  _marqueeBaseLayerSelection =
                                                      <int>{};
                                                  setState(() {});
                                                }
                                                if (_isDraggingLayer) {
                                                  _isDraggingLayer = false;
                                                }
                                                _layerDragOffsetsByIndex
                                                    .clear();
                                                if (_didModifyLayerDuringGesture) {
                                                  _didModifyLayerDuringGesture =
                                                      false;
                                                  unawaited(_autoSaveIfPossible(
                                                      appData));
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "tilemap") {
                                                _isPaintingTilemap = false;
                                                if (_didModifyTilemapDuringGesture) {
                                                  _didModifyTilemapDuringGesture =
                                                      false;
                                                  unawaited(_autoSaveIfPossible(
                                                      appData));
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "zones") {
                                                if (_isMarqueeSelectingZones) {
                                                  _isMarqueeSelectingZones =
                                                      false;
                                                  _zoneMarqueeSelectionAdditive =
                                                      false;
                                                  _zonesMarqueeStartLocal =
                                                      null;
                                                  _zonesMarqueeCurrentLocal =
                                                      null;
                                                  _marqueeBaseZoneSelection =
                                                      <int>{};
                                                  setState(() {});
                                                }
                                                appData.zoneDragOffset =
                                                    Offset.zero;
                                                if (_isDraggingZone) {
                                                  _isDraggingZone = false;
                                                }
                                                _zoneDragOffsetsByIndex.clear();
                                                if (_isResizingZone) {
                                                  _isResizingZone = false;
                                                }
                                                if (_didModifyZoneDuringGesture) {
                                                  _didModifyZoneDuringGesture =
                                                      false;
                                                  unawaited(_autoSaveIfPossible(
                                                      appData));
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "sprites") {
                                                if (_isMarqueeSelectingSprites) {
                                                  _isMarqueeSelectingSprites =
                                                      false;
                                                  _spriteMarqueeSelectionAdditive =
                                                      false;
                                                  _spritesMarqueeStartLocal =
                                                      null;
                                                  _spritesMarqueeCurrentLocal =
                                                      null;
                                                  _marqueeBaseSpriteSelection =
                                                      <int>{};
                                                  setState(() {});
                                                }
                                                appData.spriteDragOffset =
                                                    Offset.zero;
                                                if (_isDraggingSprite) {
                                                  _isDraggingSprite = false;
                                                }
                                                _spriteDragOffsetsByIndex
                                                    .clear();
                                                if (_didModifySpriteDuringGesture) {
                                                  _didModifySpriteDuringGesture =
                                                      false;
                                                  unawaited(
                                                    _autoSaveIfPossible(
                                                        appData),
                                                  );
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "animations") {
                                                _isSelectingAnimationFrames =
                                                    false;
                                                _animationDragStartFrame = null;
                                                if (_didModifyAnimationDuringGesture) {
                                                  final bool applied =
                                                      await LayoutUtils
                                                          .applyAnimationFrameSelectionToCurrentAnimation(
                                                    appData,
                                                    pushUndo: true,
                                                  );
                                                  _didModifyAnimationDuringGesture =
                                                      false;
                                                  if (applied) {
                                                    appData.update();
                                                    unawaited(
                                                      _autoSaveIfPossible(
                                                          appData),
                                                    );
                                                  }
                                                }
                                              }

                                              appData.dragging = false;
                                              appData.draggingTileIndex = -1;
                                            },
                                            onTapDown:
                                                (TapDownDetails details) {
                                              if (appData.selectedSection ==
                                                  "layers") {
                                                if (_layersHandToolActive) {
                                                  return;
                                                }
                                                final int hitLayerIndex =
                                                    LayoutUtils
                                                        .selectLayerFromPosition(
                                                  appData,
                                                  details.localPosition,
                                                );
                                                final bool additiveSelection =
                                                    _isLayerSelectionModifierPressed();
                                                bool selectionChanged = false;
                                                if (additiveSelection) {
                                                  if (hitLayerIndex != -1) {
                                                    final Set<int>
                                                        nextSelection = <int>{
                                                      ..._selectedLayerIndices,
                                                    };
                                                    if (!nextSelection.remove(
                                                        hitLayerIndex)) {
                                                      nextSelection
                                                          .add(hitLayerIndex);
                                                    }
                                                    selectionChanged =
                                                        _setLayerSelection(
                                                      appData,
                                                      nextSelection,
                                                      preferredPrimary:
                                                          hitLayerIndex,
                                                    );
                                                  }
                                                } else if (hitLayerIndex ==
                                                    -1) {
                                                  selectionChanged =
                                                      _setLayerSelection(
                                                    appData,
                                                    <int>{},
                                                  );
                                                } else {
                                                  selectionChanged =
                                                      _setLayerSelection(
                                                    appData,
                                                    <int>{hitLayerIndex},
                                                    preferredPrimary:
                                                        hitLayerIndex,
                                                  );
                                                }
                                                if (selectionChanged) {
                                                  appData.update();
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "zones") {
                                                if (_layersHandToolActive) {
                                                  return;
                                                }
                                                if (appData.selectedZone !=
                                                        -1 &&
                                                    _selectedZoneIndices
                                                            .length ==
                                                        1 &&
                                                    LayoutUtils
                                                        .isPointInZoneResizeHandle(
                                                      appData,
                                                      appData.selectedZone,
                                                      details.localPosition,
                                                    )) {
                                                  return;
                                                }
                                                final int hitZone = LayoutUtils
                                                    .zoneIndexFromPosition(
                                                  appData,
                                                  details.localPosition,
                                                );
                                                final bool additiveSelection =
                                                    _isLayerSelectionModifierPressed();
                                                bool selectionChanged = false;
                                                if (additiveSelection) {
                                                  if (hitZone != -1) {
                                                    final Set<int>
                                                        nextSelection = <int>{
                                                      ..._selectedZoneIndices,
                                                    };
                                                    if (!nextSelection
                                                        .remove(hitZone)) {
                                                      nextSelection
                                                          .add(hitZone);
                                                    }
                                                    selectionChanged =
                                                        _setZoneSelection(
                                                      appData,
                                                      nextSelection,
                                                      preferredPrimary: hitZone,
                                                    );
                                                  }
                                                } else if (hitZone == -1) {
                                                  selectionChanged =
                                                      _setZoneSelection(
                                                    appData,
                                                    <int>{},
                                                  );
                                                } else {
                                                  selectionChanged =
                                                      _setZoneSelection(
                                                    appData,
                                                    <int>{hitZone},
                                                    preferredPrimary: hitZone,
                                                  );
                                                }
                                                if (selectionChanged) {
                                                  appData.update();
                                                  layoutZonesKey.currentState
                                                      ?.updateForm(appData);
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "sprites") {
                                                if (_layersHandToolActive) {
                                                  return;
                                                }
                                                final int hitSpriteIndex =
                                                    LayoutUtils
                                                        .spriteIndexFromPosition(
                                                  appData,
                                                  details.localPosition,
                                                );
                                                final bool additiveSelection =
                                                    _isLayerSelectionModifierPressed();
                                                bool selectionChanged = false;
                                                if (additiveSelection) {
                                                  if (hitSpriteIndex != -1) {
                                                    final Set<int>
                                                        nextSelection = <int>{
                                                      ..._selectedSpriteIndices,
                                                    };
                                                    if (!nextSelection.remove(
                                                        hitSpriteIndex)) {
                                                      nextSelection
                                                          .add(hitSpriteIndex);
                                                    }
                                                    selectionChanged =
                                                        _setSpriteSelection(
                                                      appData,
                                                      nextSelection,
                                                      preferredPrimary:
                                                          hitSpriteIndex,
                                                    );
                                                  }
                                                } else if (hitSpriteIndex ==
                                                    -1) {
                                                  selectionChanged =
                                                      _setSpriteSelection(
                                                    appData,
                                                    <int>{},
                                                  );
                                                } else {
                                                  selectionChanged =
                                                      _setSpriteSelection(
                                                    appData,
                                                    <int>{hitSpriteIndex},
                                                    preferredPrimary:
                                                        hitSpriteIndex,
                                                  );
                                                }
                                                if (selectionChanged) {
                                                  appData.update();
                                                  layoutSpritesKey.currentState
                                                      ?.updateForm(appData);
                                                }
                                              } else if (appData
                                                      .selectedSection ==
                                                  "animations") {
                                                unawaited(() async {
                                                  final int frame =
                                                      await LayoutUtils
                                                          .animationFrameIndexFromCanvas(
                                                    appData,
                                                    details.localPosition,
                                                  );
                                                  if (frame == -1) {
                                                    if (LayoutUtils
                                                        .hasAnimationFrameSelection(
                                                            appData)) {
                                                      LayoutUtils
                                                          .clearAnimationFrameSelection(
                                                              appData);
                                                      appData.update();
                                                    }
                                                    return;
                                                  }
                                                  final bool
                                                      singleFrameAlreadySelected =
                                                      appData.animationSelectionStartFrame ==
                                                              frame &&
                                                          appData.animationSelectionEndFrame ==
                                                              frame;
                                                  if (singleFrameAlreadySelected) {
                                                    LayoutUtils
                                                        .clearAnimationFrameSelection(
                                                            appData);
                                                    appData.update();
                                                    return;
                                                  }
                                                  final bool changed =
                                                      await LayoutUtils
                                                          .setAnimationSelectionFromEndpoints(
                                                    appData: appData,
                                                    startFrame: frame,
                                                    endFrame: frame,
                                                  );
                                                  if (!changed) {
                                                    return;
                                                  }
                                                  final bool applied =
                                                      await LayoutUtils
                                                          .applyAnimationFrameSelectionToCurrentAnimation(
                                                    appData,
                                                    pushUndo: true,
                                                  );
                                                  appData.update();
                                                  if (applied) {
                                                    await _autoSaveIfPossible(
                                                        appData);
                                                  }
                                                }());
                                              }
                                            },
                                            onTapUp: (TapUpDetails details) {
                                              if (appData.selectedSection ==
                                                  "tilemap") {
                                                if (_layersHandToolActive) {
                                                  return;
                                                }
                                                if (_hasMultipleLayersSelected(
                                                  appData,
                                                )) {
                                                  return;
                                                }
                                                final bool changed = appData
                                                        .tilemapEraserEnabled
                                                    ? LayoutUtils
                                                        .eraseTileAtTilemap(
                                                        appData,
                                                        details.localPosition,
                                                        pushUndo: true,
                                                      )
                                                    : LayoutUtils
                                                        .pasteSelectedTilePatternAtTilemap(
                                                        appData,
                                                        details.localPosition,
                                                        pushUndo: true,
                                                      );
                                                if (changed) {
                                                  appData.update();
                                                  unawaited(_autoSaveIfPossible(
                                                      appData));
                                                }
                                              }
                                            },
                                            child: CustomPaint(
                                              painter: _layerImage != null
                                                  ? CanvasPainter(
                                                      _layerImage!,
                                                      appData,
                                                      selectedLayerIndices:
                                                          _selectedLayerIndices,
                                                    )
                                                  : null,
                                              child: Container(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (appData.selectedSection == "layers")
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _LayersMarqueePainter(
                                              rect: _layersMarqueeRect,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (appData.selectedSection == "zones")
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _LayersMarqueePainter(
                                              rect: _zonesMarqueeRect,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (appData.selectedSection == "sprites")
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _LayersMarqueePainter(
                                              rect: _spritesMarqueeRect,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (appData.selectedSection == "layers" ||
                                        appData.selectedSection == "zones" ||
                                        appData.selectedSection == "tilemap" ||
                                        appData.selectedSection == "sprites")
                                      _buildLayersToolPickerOverlay(),
                                    if (_usesWorldViewportSection(
                                      appData.selectedSection,
                                    ))
                                      _buildWorldResetOverlay(
                                        appData,
                                        viewportSize,
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 350, minWidth: 350),
                    child: Container(
                      color: cdkColors.background,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                            child: _buildBreadcrumb(appData, context),
                          ),
                          Expanded(
                            child: _getSelectedLayout(appData),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayersMarqueePainter extends CustomPainter {
  const _LayersMarqueePainter({required this.rect});

  final Rect? rect;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect? selectionRect = rect;
    if (selectionRect == null ||
        selectionRect.width <= 0 ||
        selectionRect.height <= 0) {
      return;
    }

    final Paint fillPaint = Paint()
      ..color = const Color(0x552196F3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(selectionRect, fillPaint);

    final Paint borderPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    _drawDashedLine(
      canvas,
      selectionRect.topLeft,
      selectionRect.topRight,
      borderPaint,
    );
    _drawDashedLine(
      canvas,
      selectionRect.topRight,
      selectionRect.bottomRight,
      borderPaint,
    );
    _drawDashedLine(
      canvas,
      selectionRect.bottomRight,
      selectionRect.bottomLeft,
      borderPaint,
    );
    _drawDashedLine(
      canvas,
      selectionRect.bottomLeft,
      selectionRect.topLeft,
      borderPaint,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const double dashLength = 6;
    const double gapLength = 4;
    final Offset delta = end - start;
    final double totalLength = delta.distance;
    if (totalLength == 0) {
      return;
    }
    final Offset direction = delta / totalLength;
    double distance = 0;
    while (distance < totalLength) {
      final double nextDistance = (distance + dashLength).clamp(0, totalLength);
      canvas.drawLine(
        start + direction * distance,
        start + direction * nextDistance,
        paint,
      );
      distance += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _LayersMarqueePainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
