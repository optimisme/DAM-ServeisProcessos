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
import 'layout_sprites.dart';
import 'layout_layers.dart';
import 'layout_levels.dart';
import 'layout_media.dart';
import 'layout_projects.dart';
import 'layout_projects_main.dart';
import 'layout_tilemaps.dart';
import 'layout_zones.dart';
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

  // ignore: unused_field
  Timer? _timer;
  ui.Image? _layerImage;
  bool _isDraggingLayer = false;
  bool _isPointerDown = false;
  final FocusNode _focusNode = FocusNode();
  List<String> sections = [
    'projects',
    'levels',
    'layers',
    'tilemap',
    'zones',
    'sprites',
    'media'
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
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTabSelected(AppData appData, String value) {
    setState(() {
      appData.selectedSection = value;
    });
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

    if (appData.selectedLevel >= 0 &&
        appData.selectedLevel < appData.gameData.levels.length) {
      final level = appData.gameData.levels[appData.selectedLevel];
      parts.add(
        MapEntry(
          'Level',
          level.name.trim().isEmpty
              ? 'Level ${appData.selectedLevel + 1}'
              : level.name.trim(),
        ),
      );

      if (appData.selectedLayer >= 0 &&
          appData.selectedLayer < level.layers.length) {
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

      if (appData.selectedZone >= 0 &&
          appData.selectedZone < level.zones.length) {
        final zone = level.zones[appData.selectedZone];
        parts.add(
          MapEntry(
            'Zone',
            zone.type.trim().isEmpty
                ? 'Zone ${appData.selectedZone + 1}'
                : zone.type.trim(),
          ),
        );
      }

      if (appData.selectedSprite >= 0 &&
          appData.selectedSprite < level.sprites.length) {
        final sprite = level.sprites[appData.selectedSprite];
        parts.add(
          MapEntry(
            'Sprite',
            sprite.type.trim().isEmpty
                ? 'Sprite ${appData.selectedSprite + 1}'
                : sprite.type.trim(),
          ),
        );
      }
    }

    if (appData.selectedMedia >= 0 &&
        appData.selectedMedia < appData.gameData.mediaAssets.length) {
      final mediaAsset = appData.gameData.mediaAssets[appData.selectedMedia];
      parts.add(MapEntry('Media', mediaAsset.fileName));
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
            style: typography.caption.copyWith(
              color: breadcrumbLabelColor,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: '${parts[i].key}: ',
          style: typography.caption.copyWith(
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
      case 'sprites':
        return LayoutSprites(key: layoutSpritesKey);
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
        image = await LayoutUtils.drawCanvasImageLayers(appData, false);
      case 'layers':
        // Layers section renders directly in world space via CanvasPainter.
        // Just ensure tileset images are loaded into the cache.
        await LayoutUtils.preloadLayerImages(appData);
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'tilemap':
        image = await LayoutUtils.drawCanvasImageTilemap(appData);
      case 'zones':
        image = await LayoutUtils.drawCanvasImageLayers(appData, true);
      case 'sprites':
        image = await LayoutUtils.drawCanvasImageLayers(appData, true);
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
    final double newScale =
        (oldScale * (1.0 - scrollDy * zoomSensitivity)).clamp(minScale, maxScale);
    appData.layersViewOffset =
        cursor + (appData.layersViewOffset - cursor) * (newScale / oldScale);
    appData.layersViewScale = newScale;
    appData.update();
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);

    if (appData.selectedSection != 'projects') {
      _drawCanvasImage(appData);
    }

    final media = MediaQuery.of(context);

    return MediaQuery(
      data: media.copyWith(textScaler: const TextScaler.linear(0.9)),
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildBreadcrumb(appData, context),
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: CDKPickerButtonsSegmented(
                  selectedIndex: _selectedSectionIndex(appData.selectedSection),
                  options: _buildSegmentedOptions(context),
                  onSelected: (index) =>
                      _onTabSelected(appData, sections[index]),
                ),
              ),
            ],
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
            final bool isZ =
                event.logicalKey == LogicalKeyboardKey.keyZ;
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
                        : Container(
                            color: cdkColors.backgroundSecondary1,
                            child: Listener(
                              onPointerDown: (_) => _isPointerDown = true,
                              onPointerUp: (_) => _isPointerDown = false,
                              onPointerCancel: (_) => _isPointerDown = false,
                              // macOS trackpad: two-finger scroll → PointerScrollEvent
                              onPointerSignal: (event) {
                                if (event is! PointerScrollEvent) return;
                                if (appData.selectedSection != "layers") return;
                                _applyLayersZoom(appData,
                                    event.localPosition, event.scrollDelta.dy);
                              },
                              // macOS trackpad: two-finger pan-zoom → PointerPanZoomUpdateEvent
                              onPointerPanZoomUpdate: (event) {
                                if (appData.selectedSection != "layers") return;
                                // pan delta from trackpad scroll
                                final double dy = -event.panDelta.dy;
                                if (dy == 0) return;
                                _applyLayersZoom(
                                    appData, event.localPosition, dy);
                              },
                              child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (details) async {
                                appData.dragging = true;
                                appData.dragStartDetails = details;
                                if (appData.selectedSection == "layers") {
                                  if (appData.selectedLayer != -1 &&
                                      LayoutUtils.hitTestSelectedLayer(
                                          appData, details.localPosition)) {
                                    _isDraggingLayer = true;
                                    LayoutUtils.startDragLayerFromPosition(
                                        appData, details.localPosition);
                                  } else {
                                    // Clicked outside selected layer — pan world, keep selection
                                    _isDraggingLayer = false;
                                  }
                                } else if (appData.selectedSection == "tilemap") {
                                  await LayoutUtils.dragTileIndexFromTileset(
                                      appData, details.localPosition);
                                } else if (appData.selectedSection == "zones") {
                                  LayoutUtils.selectZoneFromPosition(appData,
                                      details.localPosition, layoutZonesKey);
                                  if (appData.selectedZone != -1) {
                                    LayoutUtils.startDragZoneFromPosition(
                                        appData,
                                        details.localPosition,
                                        layoutZonesKey);
                                    layoutZonesKey.currentState
                                        ?.updateForm(appData);
                                  }
                                } else if (appData.selectedSection ==
                                    "sprites") {
                                  LayoutUtils.selectSpriteFromPosition(appData,
                                      details.localPosition, layoutSpritesKey);
                                  if (appData.selectedSprite != -1) {
                                    LayoutUtils.startDragSpriteFromPosition(
                                        appData,
                                        details.localPosition,
                                        layoutSpritesKey);
                                    layoutSpritesKey.currentState
                                        ?.updateForm(appData);
                                  }
                                }
                              },
                              onPanUpdate: (details) async {
                                if (appData.selectedSection == "layers") {
                                  if (!_isPointerDown) {
                                    // scroll-triggered pan — ignore
                                  } else if (_isDraggingLayer &&
                                      appData.selectedLayer != -1) {
                                    LayoutUtils.dragLayerFromCanvas(
                                        appData, details.localPosition);
                                    appData.update();
                                  } else {
                                    appData.layersViewOffset += details.delta;
                                    appData.update();
                                  }
                                } else if (appData.selectedSection == "tilemap" &&
                                    appData.draggingTileIndex != -1) {
                                  appData.draggingOffset += details.delta;
                                } else if (appData.selectedSection == "zones" &&
                                    appData.selectedZone != -1) {
                                  if (appData.selectedZone != -1) {
                                    LayoutUtils.dragZoneFromCanvas(
                                        appData, details.localPosition);
                                    layoutZonesKey.currentState
                                        ?.updateForm(appData);
                                  }
                                } else if (appData.selectedSection ==
                                        "sprites" &&
                                    appData.selectedSprite != -1) {
                                  if (appData.selectedSprite != -1) {
                                    LayoutUtils.dragSpriteFromCanvas(
                                        appData, details.localPosition);
                                    layoutSpritesKey.currentState
                                        ?.updateForm(appData);
                                  }
                                }
                              },
                              onPanEnd: (details) {
                                if (appData.selectedSection == "layers") {
                                  if (_isDraggingLayer) {
                                    _isDraggingLayer = false;
                                  }
                                } else if (appData.selectedSection == "tilemap" &&
                                    appData.draggingTileIndex != -1) {
                                  LayoutUtils.dropTileIndexFromTileset(
                                      appData, details.localPosition);
                                } else if (appData.selectedSection == "zones") {
                                  appData.zoneDragOffset = Offset.zero;
                                } else if (appData.selectedSection ==
                                    "sprites") {
                                  appData.zoneDragOffset = Offset.zero;
                                }

                                appData.dragging = false;
                                appData.draggingTileIndex = -1;
                              },
                              onTapDown: (TapDownDetails details) {
                                if (appData.selectedSection == "layers") {
                                  final int hit = LayoutUtils
                                      .selectLayerFromPosition(
                                          appData, details.localPosition);
                                  if (hit == -1) {
                                    if (appData.selectedLayer != -1) {
                                      appData.selectedLayer = -1;
                                      appData.update();
                                    }
                                  } else if (hit != appData.selectedLayer) {
                                    appData.selectedLayer = hit;
                                    appData.update();
                                  }
                                } else if (appData.selectedSection == "tilemap") {
                                  LayoutUtils.selectTileIndexFromTileset(
                                      appData, details.localPosition);
                                } else if (appData.selectedSection == "zones") {
                                  LayoutUtils.selectZoneFromPosition(appData,
                                      details.localPosition, layoutZonesKey);
                                } else if (appData.selectedSection ==
                                    "sprites") {
                                  LayoutUtils.selectSpriteFromPosition(appData,
                                      details.localPosition, layoutSpritesKey);
                                }
                              },
                              onTapUp: (TapUpDetails details) {
                                if (appData.selectedSection == "tilemap") {
                                  if (appData.selectedTileIndex == -1) {
                                    LayoutUtils.removeTileIndexFromTileset(
                                        appData, details.localPosition);
                                  } else {
                                    LayoutUtils.setSelectedTileIndexFromTileset(
                                        appData, details.localPosition);
                                  }
                                  if (appData.selectedZone != -1) {
                                    layoutZonesKey.currentState
                                        ?.updateForm(appData);
                                  } else if (appData.selectedSprite != -1) {
                                    layoutSpritesKey.currentState
                                        ?.updateForm(appData);
                                  }
                                }
                              },
                              child: CustomPaint(
                                painter: _layerImage != null
                                    ? CanvasPainter(_layerImage!, appData)
                                    : null,
                                child: Container(),
                              ),
                            ),
                          ),
                        ),
                  ),
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 350, minWidth: 350),
                    child: Container(
                      color: cdkColors.background,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
      ),
    );
  }
}
