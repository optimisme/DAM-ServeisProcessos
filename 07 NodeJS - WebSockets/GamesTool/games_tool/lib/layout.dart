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
  bool _didModifyAnimationDuringGesture = false;
  bool _didModifyTilemapDuringGesture = false;
  int? _animationDragStartFrame;
  bool _isPointerDown = false;
  bool _isHoveringSelectedTilemapLayer = false;
  bool _isDragGestureActive = false;
  bool _pendingLayersViewportCenter = false;
  final FocusNode _focusNode = FocusNode();
  List<String> sections = [
    'projects',
    'media',
    'levels',
    'layers',
    'tilemap',
    'zones',
    'animations',
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

  MouseCursor _tilemapCursor(AppData appData) {
    if (appData.selectedSection != 'tilemap') {
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

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);

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
          final bool meta = HardwareKeyboard.instance.isMetaPressed;
          final bool ctrl = HardwareKeyboard.instance.isControlPressed;
          final bool shift = HardwareKeyboard.instance.isShiftPressed;
          final bool isZ = event.logicalKey == LogicalKeyboardKey.keyZ;
          if (!(meta || ctrl) || !isZ) return KeyEventResult.ignored;
          final appData = Provider.of<AppData>(context, listen: false);
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
                              _queueInitialLayersViewportCenter(
                                appData,
                                Size(constraints.maxWidth,
                                    constraints.maxHeight),
                              );
                              return Container(
                                color: cdkColors.backgroundSecondary1,
                                child: Listener(
                                  onPointerDown: (_) => _isPointerDown = true,
                                  onPointerUp: (_) => _isPointerDown = false,
                                  onPointerCancel: (_) =>
                                      _isPointerDown = false,
                                  // macOS trackpad: two-finger scroll → PointerScrollEvent
                                  onPointerSignal: (event) {
                                    if (event is! PointerScrollEvent) return;
                                    if (appData.selectedSection != "levels" &&
                                        appData.selectedSection != "layers" &&
                                        appData.selectedSection != "tilemap" &&
                                        appData.selectedSection != "zones" &&
                                        appData.selectedSection != "sprites" &&
                                        appData.selectedSection != "viewport") {
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
                                        appData.selectedSection != "layers" &&
                                        appData.selectedSection != "tilemap" &&
                                        appData.selectedSection != "zones" &&
                                        appData.selectedSection != "sprites" &&
                                        appData.selectedSection != "viewport") {
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
                                                      event.localPosition) !=
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
                                        appData.dragStartDetails = details;
                                        if (appData.selectedSection ==
                                            "levels") {
                                          // Levels section is preview-only: always pan.
                                        } else if (appData.selectedSection ==
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
                                                  details.localPosition)) {
                                            _isResizingViewport = true;
                                            LayoutUtils
                                                .startResizeViewportFromPosition(
                                              appData,
                                              details.localPosition,
                                            );
                                          } else if (LayoutUtils
                                              .isPointInViewportRect(appData,
                                                  details.localPosition)) {
                                            _isDraggingViewport = true;
                                            LayoutUtils
                                                .startDragViewportFromPosition(
                                              appData,
                                              details.localPosition,
                                            );
                                          }
                                        } else if (appData.selectedSection ==
                                            "layers") {
                                          // Layers section is preview-only: always pan, never drag a layer.
                                          _isDraggingLayer = false;
                                        } else if (appData.selectedSection ==
                                            "tilemap") {
                                          final bool useEraser =
                                              appData.tilemapEraserEnabled;
                                          final bool hasTileSelection =
                                              LayoutUtils
                                                  .hasTilePatternSelection(
                                                      appData);
                                          final bool startsInsideLayer =
                                              LayoutUtils.getTilemapCoords(
                                                      appData,
                                                      details.localPosition) !=
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
                                        } else if (appData.selectedSection ==
                                            "zones") {
                                          _didModifyZoneDuringGesture = false;
                                          _isDraggingZone = false;
                                          _isResizingZone = false;
                                          final int selectedZone =
                                              appData.selectedZone;
                                          final bool startsOnResizeHandle =
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
                                          final int hitZone =
                                              LayoutUtils.zoneIndexFromPosition(
                                            appData,
                                            details.localPosition,
                                          );
                                          if (hitZone != -1) {
                                            if (appData.selectedZone !=
                                                hitZone) {
                                              appData.selectedZone = hitZone;
                                              appData.update();
                                            }
                                            _isDraggingZone = true;
                                            LayoutUtils
                                                .startDragZoneFromPosition(
                                              appData,
                                              details.localPosition,
                                            );
                                            layoutZonesKey.currentState
                                                ?.updateForm(appData);
                                          } else {
                                            _isDraggingZone = false;
                                          }
                                        } else if (appData.selectedSection ==
                                            "sprites") {
                                          _didModifySpriteDuringGesture = false;
                                          _isDraggingSprite = false;
                                          final int hitSpriteIndex = LayoutUtils
                                              .spriteIndexFromPosition(
                                            appData,
                                            details.localPosition,
                                          );
                                          if (hitSpriteIndex != -1) {
                                            if (appData.selectedSprite !=
                                                hitSpriteIndex) {
                                              appData.selectedSprite =
                                                  hitSpriteIndex;
                                              appData.update();
                                            }
                                            _isDraggingSprite = true;
                                            LayoutUtils
                                                .startDragSpriteFromPosition(
                                              appData,
                                              details.localPosition,
                                            );
                                            layoutSpritesKey.currentState
                                                ?.updateForm(appData);
                                          }
                                        } else if (appData.selectedSection ==
                                            "animations") {
                                          _isSelectingAnimationFrames = false;
                                          _didModifyAnimationDuringGesture =
                                              false;
                                          _animationDragStartFrame = null;
                                          final int frame = await LayoutUtils
                                              .animationFrameIndexFromCanvas(
                                            appData,
                                            details.localPosition,
                                          );
                                          if (frame != -1) {
                                            _isSelectingAnimationFrames = true;
                                            _animationDragStartFrame = frame;
                                            final bool changed = await LayoutUtils
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
                                        } else if (appData.selectedSection ==
                                            "viewport") {
                                          if (!_isPointerDown) {
                                            // scroll-triggered pan — ignore
                                          } else if (_isResizingViewport) {
                                            LayoutUtils
                                                .resizeViewportFromCanvas(
                                                    appData,
                                                    details.localPosition);
                                            appData.update();
                                          } else if (_isDraggingViewport) {
                                            LayoutUtils.dragViewportFromCanvas(
                                                appData, details.localPosition);
                                            appData.update();
                                          } else {
                                            appData.layersViewOffset +=
                                                details.delta;
                                            appData.update();
                                          }
                                        } else if (appData.selectedSection ==
                                            "layers") {
                                          if (!_isPointerDown) {
                                            // scroll-triggered pan — ignore
                                          } else if (_isDraggingLayer &&
                                              appData.selectedLayer != -1) {
                                            LayoutUtils.dragLayerFromCanvas(
                                                appData, details.localPosition);
                                            appData.update();
                                          } else {
                                            appData.layersViewOffset +=
                                                details.delta;
                                            appData.update();
                                          }
                                        } else if (appData.selectedSection ==
                                            "tilemap") {
                                          final bool useEraser =
                                              appData.tilemapEraserEnabled;
                                          if (!_isPointerDown) {
                                            // scroll-triggered pan — ignore
                                          } else if (_isPaintingTilemap) {
                                            final bool isInsideLayer =
                                                LayoutUtils.getTilemapCoords(
                                                        appData,
                                                        details
                                                            .localPosition) !=
                                                    null;
                                            if (!isInsideLayer) {
                                              _isPaintingTilemap = false;
                                              appData.layersViewOffset +=
                                                  details.delta;
                                              appData.update();
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
                                            appData.layersViewOffset +=
                                                details.delta;
                                            appData.update();
                                          }
                                        } else if (appData.selectedSection ==
                                            "zones") {
                                          if (!_isPointerDown) {
                                            // scroll-triggered pan — ignore
                                          } else if (_isResizingZone &&
                                              appData.selectedZone != -1) {
                                            LayoutUtils.resizeZoneFromCanvas(
                                                appData, details.localPosition);
                                            _didModifyZoneDuringGesture = true;
                                            appData.update();
                                            layoutZonesKey.currentState
                                                ?.updateForm(appData);
                                          } else if (_isDraggingZone &&
                                              appData.selectedZone != -1) {
                                            LayoutUtils.dragZoneFromCanvas(
                                                appData, details.localPosition);
                                            _didModifyZoneDuringGesture = true;
                                            appData.update();
                                            layoutZonesKey.currentState
                                                ?.updateForm(appData);
                                          } else {
                                            appData.layersViewOffset +=
                                                details.delta;
                                            appData.update();
                                          }
                                        } else if (appData.selectedSection ==
                                            "sprites") {
                                          if (!_isPointerDown) {
                                            // scroll-triggered pan — ignore
                                          } else if (_isDraggingSprite &&
                                              appData.selectedSprite != -1) {
                                            LayoutUtils.dragSpriteFromCanvas(
                                              appData,
                                              details.localPosition,
                                            );
                                            _didModifySpriteDuringGesture =
                                                true;
                                            appData.update();
                                            layoutSpritesKey.currentState
                                                ?.updateForm(appData);
                                          } else {
                                            appData.layersViewOffset +=
                                                details.delta;
                                            appData.update();
                                          }
                                        } else if (appData.selectedSection ==
                                            "animations") {
                                          if (!_isPointerDown) {
                                            // scroll-triggered pan — ignore
                                          } else if (_isSelectingAnimationFrames &&
                                              _animationDragStartFrame !=
                                                  null) {
                                            final int frame = await LayoutUtils
                                                .animationFrameIndexFromCanvas(
                                              appData,
                                              details.localPosition,
                                            );
                                            if (frame == -1) {
                                              return;
                                            }
                                            final bool changed = await LayoutUtils
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
                                        } else if (appData.selectedSection ==
                                            "layers") {
                                          if (_isDraggingLayer) {
                                            _isDraggingLayer = false;
                                          }
                                        } else if (appData.selectedSection ==
                                            "tilemap") {
                                          _isPaintingTilemap = false;
                                          if (_didModifyTilemapDuringGesture) {
                                            _didModifyTilemapDuringGesture =
                                                false;
                                            unawaited(
                                                _autoSaveIfPossible(appData));
                                          }
                                        } else if (appData.selectedSection ==
                                            "zones") {
                                          appData.zoneDragOffset = Offset.zero;
                                          if (_isDraggingZone) {
                                            _isDraggingZone = false;
                                          }
                                          if (_isResizingZone) {
                                            _isResizingZone = false;
                                          }
                                          if (_didModifyZoneDuringGesture) {
                                            _didModifyZoneDuringGesture = false;
                                            unawaited(
                                                _autoSaveIfPossible(appData));
                                          }
                                        } else if (appData.selectedSection ==
                                            "sprites") {
                                          appData.spriteDragOffset =
                                              Offset.zero;
                                          if (_isDraggingSprite) {
                                            _isDraggingSprite = false;
                                          }
                                          if (_didModifySpriteDuringGesture) {
                                            _didModifySpriteDuringGesture =
                                                false;
                                            unawaited(
                                              _autoSaveIfPossible(appData),
                                            );
                                          }
                                        } else if (appData.selectedSection ==
                                            "animations") {
                                          _isSelectingAnimationFrames = false;
                                          _animationDragStartFrame = null;
                                          if (_didModifyAnimationDuringGesture) {
                                            final bool applied = await LayoutUtils
                                                .applyAnimationFrameSelectionToCurrentAnimation(
                                              appData,
                                              pushUndo: true,
                                            );
                                            _didModifyAnimationDuringGesture =
                                                false;
                                            if (applied) {
                                              appData.update();
                                              unawaited(
                                                _autoSaveIfPossible(appData),
                                              );
                                            }
                                          }
                                        }

                                        appData.dragging = false;
                                        appData.draggingTileIndex = -1;
                                      },
                                      onTapDown: (TapDownDetails details) {
                                        if (appData.selectedSection ==
                                            "layers") {
                                          // Layers section is preview-only: no selection via canvas tap.
                                        } else if (appData.selectedSection ==
                                            "zones") {
                                          if (appData.selectedZone != -1 &&
                                              LayoutUtils
                                                  .isPointInZoneResizeHandle(
                                                appData,
                                                appData.selectedZone,
                                                details.localPosition,
                                              )) {
                                            return;
                                          }
                                          LayoutUtils.selectZoneFromPosition(
                                            appData,
                                            details.localPosition,
                                            layoutZonesKey,
                                          );
                                        } else if (appData.selectedSection ==
                                            "sprites") {
                                          final int hitSpriteIndex = LayoutUtils
                                              .spriteIndexFromPosition(
                                            appData,
                                            details.localPosition,
                                          );
                                          layoutSpritesKey.currentState
                                              ?.selectSprite(
                                            appData,
                                            hitSpriteIndex,
                                            false,
                                          );
                                        } else if (appData.selectedSection ==
                                            "animations") {
                                          unawaited(() async {
                                            final int frame = await LayoutUtils
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
                                            final bool changed = await LayoutUtils
                                                .setAnimationSelectionFromEndpoints(
                                              appData: appData,
                                              startFrame: frame,
                                              endFrame: frame,
                                            );
                                            if (!changed) {
                                              return;
                                            }
                                            final bool applied = await LayoutUtils
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
                                          final bool changed = appData
                                                  .tilemapEraserEnabled
                                              ? LayoutUtils.eraseTileAtTilemap(
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
                                            unawaited(
                                                _autoSaveIfPossible(appData));
                                          }
                                        }
                                      },
                                      child: CustomPaint(
                                        painter: _layerImage != null
                                            ? CanvasPainter(
                                                _layerImage!, appData)
                                            : null,
                                        child: Container(),
                                      ),
                                    ),
                                  ),
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
