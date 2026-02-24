import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
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
        image = await LayoutUtils.drawCanvasImageLayers(appData, true);
      case 'tilemap':
        image = await LayoutUtils.drawCanvasImageTilemap(appData);
      case 'zones':
        image = await LayoutUtils.drawCanvasImageLayers(appData, true);
      case 'sprites':
        image = await LayoutUtils.drawCanvasImageLayers(appData, true);
      case 'media':
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      default:
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
    }

    setState(() {
      _layerImage = image;
    });
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
          middle: FittedBox(
            fit: BoxFit.scaleDown,
            child: CDKPickerButtonsSegmented(
              selectedIndex: _selectedSectionIndex(appData.selectedSection),
              options: _buildSegmentedOptions(context),
              onSelected: (index) => _onTabSelected(appData, sections[index]),
            ),
          ),
        ),
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
                            child: GestureDetector(
                              onPanStart: (details) async {
                                appData.dragging = true;
                                appData.dragStartDetails = details;
                                if (appData.selectedSection == "tilemap") {
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
                                if (appData.selectedSection == "tilemap" &&
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
                                if (appData.selectedSection == "tilemap" &&
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
                                if (appData.selectedSection == "tilemap") {
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
    );
  }
}
