import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'canvas_painter.dart';
import 'layout_game.dart';
import 'layout_sprites.dart';
import 'layout_layers.dart';
import 'layout_levels.dart';
import 'layout_media.dart';
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
  final GlobalKey<LayoutSpritesState> layoutSpritesKey = GlobalKey<LayoutSpritesState>();
  final GlobalKey<LayoutZonesState> layoutZonesKey = GlobalKey<LayoutZonesState>();

  // ignore: unused_field
  Timer? _timer;
  ui.Image? _layerImage;
  List<String> sections = [
    'game',
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
      appData.selectedSection = 'game';
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

  void _onTabSelected(AppData appData, String value) {
    setState(() {
      appData.selectedSection = value;
    });
  }

  Map<String, Widget> _buildSegmentedChildren() {
    return {
      for (var segment in sections)
        segment: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            segment[0].toUpperCase() +
                segment.substring(1), // Capitalitza la primera lletra
            style: const TextStyle(fontSize: 12.0),
          ),
        ),
    };
  }

  Widget _getSelectedLayout(AppData appData) {
    switch (appData.selectedSection) {
      case 'game':
        return const LayoutGame();
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
        return const Center(child: Text('Unknown Layout'));
    }
  }

  Future<void> _drawCanvasImage(AppData appData) async {
    ui.Image image;
    switch (appData.selectedSection) {
      case 'game':
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
    final level = appData.selectedLevel != -1
        ? appData.gameData.levels[appData.selectedLevel].name
        : "";
    final layer = appData.selectedLayer != -1
        ? appData.gameData.levels[appData.selectedLevel]
            .layers[appData.selectedLayer].name
        : "";

    final location = Text.rich(
      overflow: TextOverflow.ellipsis,
      TextSpan(
        children: [
          if (level != "") ...[
            TextSpan(
              text: "Level: ",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            TextSpan(
              text: "$level ",
              style: TextStyle(fontSize: 14, color: Colors.black),
            ),
          ],
          if (layer != "") ...[
            TextSpan(
              text: "Layer: ",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            TextSpan(
              text: "$layer ",
              style: TextStyle(fontSize: 14, color: Colors.black),
            )
          ]
        ],
      ),
    );

    _drawCanvasImage(appData);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
                width: 250,
                child: Align(alignment: Alignment.centerLeft, child: location)),
            Spacer(),
            CupertinoSegmentedControl<String>(
              onValueChanged: (value) => _onTabSelected(appData, value),
              groupValue: appData.selectedSection,
              children: _buildSegmentedChildren(),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Container(
                        color: CupertinoColors.systemGrey5,
                        child: GestureDetector(
                          onPanStart: (details) async {
                            appData.dragging = true;
                            appData.dragStartDetails = details;
                            if (appData.selectedSection == "tilemap") {
                              await LayoutUtils.dragTileIndexFromTileset(
                                  appData, details.localPosition);
                            } else if (appData.selectedSection == "zones") {
                              LayoutUtils.selectZoneFromPosition(appData, details.localPosition, layoutZonesKey);
                              if (appData.selectedZone != -1) {
                                LayoutUtils.startDragZoneFromPosition(appData, details.localPosition, layoutZonesKey);
                                layoutZonesKey.currentState?.updateForm(appData);
                              } 
                            } else if (appData.selectedSection == "sprites") {
                              LayoutUtils.selectSpriteFromPosition(appData, details.localPosition, layoutSpritesKey);
                              if (appData.selectedSprite != -1) {
                                LayoutUtils.startDragSpriteFromPosition(appData, details.localPosition, layoutSpritesKey);
                                layoutSpritesKey.currentState?.updateForm(appData);
                              } 
                            }
                          },
                          onPanUpdate: (details) async {
                            if (appData.selectedSection == "tilemap" &&
                              appData.draggingTileIndex != -1) {
                              appData.draggingOffset += details.delta;
                            } else if (appData.selectedSection == "zones" && appData.selectedZone != -1) {
                              if (appData.selectedZone != -1) {
                                LayoutUtils.dragZoneFromCanvas(appData, details.localPosition);
                                layoutZonesKey.currentState?.updateForm(appData);
                              } 
                            } else if (appData.selectedSection == "sprites" && appData.selectedSprite != -1) {
                              if (appData.selectedSprite != -1) {
                                LayoutUtils.dragSpriteFromCanvas(appData, details.localPosition);
                                layoutSpritesKey.currentState?.updateForm(appData);
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
                            } else if (appData.selectedSection == "sprites") {
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
                              LayoutUtils.selectZoneFromPosition(appData, details.localPosition, layoutZonesKey);
                            } else if (appData.selectedSection == "sprites") {
                              LayoutUtils.selectSpriteFromPosition(appData, details.localPosition, layoutSpritesKey);
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
                                layoutZonesKey.currentState?.updateForm(appData);
                              } else if (appData.selectedSprite != -1) {
                                layoutSpritesKey.currentState?.updateForm(appData);
                              }
                            }
                          },
                          child: CustomPaint(
                            painter: _layerImage != null
                                ? CanvasPainter(_layerImage!, appData)
                                : null,
                            child: Container(),
                          ),
                        ))),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 350, minWidth: 350),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _getSelectedLayout(appData),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
