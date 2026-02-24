import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_layer.dart';

class LayoutLayers extends StatefulWidget {
  const LayoutLayers({super.key});

  @override
  LayoutLayersState createState() => LayoutLayersState();
}

class LayoutLayersState extends State<LayoutLayers> {
  final ScrollController scrollController = ScrollController();
  final GlobalKey _selectedEditAnchorKey = GlobalKey();

  Future<void> _autoSaveIfPossible(AppData appData) async {
    if (appData.selectedProject == null) {
      return;
    }
    await appData.saveGame();
  }

  void _addLayer({
    required AppData appData,
    required _LayerDialogData data,
  }) {
    if (appData.selectedLevel == -1) {
      return;
    }

    final int mapWidth = data.tilemapWidth < 1 ? 1 : data.tilemapWidth;
    final int mapHeight = data.tilemapHeight < 1 ? 1 : data.tilemapHeight;

    appData.gameData.levels[appData.selectedLevel].layers.add(
      GameLayer(
        name: data.name,
        x: data.x,
        y: data.y,
        depth: data.depth,
        tilesSheetFile: data.tilesSheetFile,
        tilesWidth: data.tileWidth,
        tilesHeight: data.tileHeight,
        tileMap: List.generate(
          mapHeight,
          (_) => List.filled(mapWidth, -1),
        ),
        visible: data.visible,
      ),
    );

    appData.selectedLayer = -1;
    appData.update();
  }

  void _updateLayer({
    required AppData appData,
    required int index,
    required _LayerDialogData data,
  }) {
    if (appData.selectedLevel == -1) {
      return;
    }

    final List<GameLayer> layers =
        appData.gameData.levels[appData.selectedLevel].layers;
    if (index < 0 || index >= layers.length) {
      return;
    }

    final GameLayer oldLayer = layers[index];
    final int newWidth = data.tilemapWidth < 1 ? 1 : data.tilemapWidth;
    final int newHeight = data.tilemapHeight < 1 ? 1 : data.tilemapHeight;

    final int oldHeight = oldLayer.tileMap.length;
    final int oldWidth = oldHeight == 0 ? 0 : oldLayer.tileMap.first.length;

    final List<List<int>> resizedTileMap = List.generate(newHeight, (y) {
      return List.generate(newWidth, (x) {
        if (y < oldHeight && x < oldWidth) {
          return oldLayer.tileMap[y][x];
        }
        return -1;
      });
    });

    layers[index] = GameLayer(
      name: data.name,
      x: data.x,
      y: data.y,
      depth: data.depth,
      tilesSheetFile: data.tilesSheetFile,
      tilesWidth: data.tileWidth,
      tilesHeight: data.tileHeight,
      tileMap: resizedTileMap,
      visible: data.visible,
    );

    appData.selectedLayer = index;
    appData.update();
  }

  Future<_LayerDialogData?> _promptLayerData({
    required String title,
    required String confirmLabel,
    required _LayerDialogData initialData,
    GlobalKey? anchorKey,
    bool useArrowedPopover = false,
  }) async {
    if (Overlay.maybeOf(context) == null) {
      return null;
    }

    final AppData appData = Provider.of<AppData>(context, listen: false);
    final CDKDialogController controller = CDKDialogController();
    final Completer<_LayerDialogData?> completer =
        Completer<_LayerDialogData?>();
    _LayerDialogData? result;

    final dialogChild = _LayerFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialData: initialData,
      onPickTilesSheet: appData.pickImageFile,
      onConfirm: (value) {
        result = value;
        controller.close();
      },
      onCancel: controller.close,
    );

    if (useArrowedPopover && anchorKey != null) {
      CDKDialogsManager.showPopoverArrowed(
        context: context,
        anchorKey: anchorKey,
        isAnimated: true,
        dismissOnEscape: true,
        dismissOnOutsideTap: true,
        showBackgroundShade: false,
        controller: controller,
        onHide: () {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        },
        child: dialogChild,
      );
    } else {
      CDKDialogsManager.showModal(
        context: context,
        dismissOnEscape: true,
        dismissOnOutsideTap: false,
        showBackgroundShade: true,
        controller: controller,
        onHide: () {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        },
        child: dialogChild,
      );
    }

    return completer.future;
  }

  Future<void> _promptAndAddLayer() async {
    final _LayerDialogData? data = await _promptLayerData(
      title: 'New layer',
      confirmLabel: 'Add',
      initialData: const _LayerDialogData(
        name: '',
        x: 0,
        y: 0,
        depth: 0,
        tilesSheetFile: '',
        tileWidth: 32,
        tileHeight: 32,
        tilemapWidth: 32,
        tilemapHeight: 16,
        visible: true,
      ),
    );
    if (!mounted || data == null) {
      return;
    }
    final AppData appData = Provider.of<AppData>(context, listen: false);
    _addLayer(appData: appData, data: data);
    await _autoSaveIfPossible(appData);
  }

  Future<void> _promptAndEditLayer(int index, GlobalKey anchorKey) async {
    final AppData appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1) {
      return;
    }

    final List<GameLayer> layers =
        appData.gameData.levels[appData.selectedLevel].layers;
    if (index < 0 || index >= layers.length) {
      return;
    }

    final GameLayer layer = layers[index];
    final int mapWidth = layer.tileMap.isEmpty ? 0 : layer.tileMap.first.length;
    final int mapHeight = layer.tileMap.length;

    final _LayerDialogData? data = await _promptLayerData(
      title: 'Edit layer',
      confirmLabel: 'Save',
      initialData: _LayerDialogData(
        name: layer.name,
        x: layer.x,
        y: layer.y,
        depth: layer.depth,
        tilesSheetFile: layer.tilesSheetFile,
        tileWidth: layer.tilesWidth,
        tileHeight: layer.tilesHeight,
        tilemapWidth: mapWidth,
        tilemapHeight: mapHeight,
        visible: layer.visible,
      ),
      anchorKey: anchorKey,
      useArrowedPopover: true,
    );

    if (!mounted || data == null) {
      return;
    }

    _updateLayer(appData: appData, index: index, data: data);
    await _autoSaveIfPossible(appData);
  }

  void _selectLayer(AppData appData, int index, bool isSelected) {
    if (isSelected) {
      appData.selectedLayer = -1;
      appData.update();
      return;
    }
    appData.selectedLayer = index;
    appData.update();
  }

  void _onReorder(AppData appData, int oldIndex, int newIndex) {
    if (appData.selectedLevel == -1) {
      return;
    }

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final List<GameLayer> layers =
        appData.gameData.levels[appData.selectedLevel].layers;
    final int selectedIndex = appData.selectedLayer;

    final GameLayer layer = layers.removeAt(oldIndex);
    layers.insert(newIndex, layer);

    if (selectedIndex == oldIndex) {
      appData.selectedLayer = newIndex;
    } else if (selectedIndex > oldIndex && selectedIndex <= newIndex) {
      appData.selectedLayer -= 1;
    } else if (selectedIndex < oldIndex && selectedIndex >= newIndex) {
      appData.selectedLayer += 1;
    }

    appData.update();
    unawaited(_autoSaveIfPossible(appData));
  }

  @override
  Widget build(BuildContext context) {
    final AppData appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);

    if (appData.selectedLevel == -1) {
      return const Center(
        child: CDKText(
          'Select a level to edit layers.',
          role: CDKTextRole.body,
          secondary: true,
        ),
      );
    }

    final level = appData.gameData.levels[appData.selectedLevel];
    final layers = level.layers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Row(
            children: [
              CDKText(
                'Layers',
                role: CDKTextRole.title,
                style: typography.title.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              CDKButton(
                style: CDKButtonStyle.action,
                onPressed: () async {
                  await _promptAndAddLayer();
                },
                child: const Text('+ Add Layer'),
              ),
            ],
          ),
        ),
        Expanded(
          child: layers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: CDKText(
                    '(No layers defined)',
                    role: CDKTextRole.caption,
                    secondary: true,
                  ),
                )
              : CupertinoScrollbar(
                  controller: scrollController,
                  child: Localizations.override(
                    context: context,
                    delegates: [
                      DefaultMaterialLocalizations.delegate,
                      DefaultWidgetsLocalizations.delegate,
                    ],
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: layers.length,
                      onReorder: (oldIndex, newIndex) =>
                          _onReorder(appData, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final bool isSelected = index == appData.selectedLayer;
                        final GameLayer layer = layers[index];
                        final int mapWidth = layer.tileMap.isEmpty
                            ? 0
                            : layer.tileMap.first.length;
                        final int mapHeight = layer.tileMap.length;
                        final String subtitle =
                            'Depth ${layer.depth} | ${mapWidth}x$mapHeight tiles';
                        final String details =
                            '${layer.tilesWidth}x${layer.tilesHeight} px | ${layer.visible ? 'Visible' : 'Hidden'}';

                        return GestureDetector(
                          key: ValueKey(layer),
                          onTap: () => _selectLayer(appData, index, isSelected),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 8,
                            ),
                            color: isSelected
                                ? CupertinoColors.systemBlue
                                    .withValues(alpha: 0.2)
                                : cdkColors.backgroundSecondary0,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CDKText(
                                        layer.name,
                                        role: isSelected
                                            ? CDKTextRole.bodyStrong
                                            : CDKTextRole.body,
                                        style: TextStyle(
                                          fontSize: isSelected ? 17 : 16,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      CDKText(
                                        subtitle,
                                        role: CDKTextRole.caption,
                                        color: cdkColors.colorText,
                                      ),
                                      const SizedBox(height: 2),
                                      CDKText(
                                        details,
                                        role: CDKTextRole.caption,
                                        color: cdkColors.colorText,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: CupertinoButton(
                                      key: _selectedEditAnchorKey,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      minimumSize: const Size(20, 20),
                                      onPressed: () async {
                                        await _promptAndEditLayer(
                                          index,
                                          _selectedEditAnchorKey,
                                        );
                                      },
                                      child: Icon(
                                        CupertinoIcons.pencil,
                                        size: 16,
                                        color: cdkColors.colorText,
                                      ),
                                    ),
                                  ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.bars,
                                      size: 16,
                                      color: cdkColors.colorText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _LayerDialogData {
  const _LayerDialogData({
    required this.name,
    required this.x,
    required this.y,
    required this.depth,
    required this.tilesSheetFile,
    required this.tileWidth,
    required this.tileHeight,
    required this.tilemapWidth,
    required this.tilemapHeight,
    required this.visible,
  });

  final String name;
  final int x;
  final int y;
  final int depth;
  final String tilesSheetFile;
  final int tileWidth;
  final int tileHeight;
  final int tilemapWidth;
  final int tilemapHeight;
  final bool visible;
}

class _LayerFormDialog extends StatefulWidget {
  const _LayerFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialData,
    required this.onPickTilesSheet,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final String confirmLabel;
  final _LayerDialogData initialData;
  final Future<String> Function() onPickTilesSheet;
  final ValueChanged<_LayerDialogData> onConfirm;
  final VoidCallback onCancel;

  @override
  State<_LayerFormDialog> createState() => _LayerFormDialogState();
}

class _LayerFormDialogState extends State<_LayerFormDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialData.name,
  );
  late final TextEditingController _xController = TextEditingController(
    text: widget.initialData.x.toString(),
  );
  late final TextEditingController _yController = TextEditingController(
    text: widget.initialData.y.toString(),
  );
  late final TextEditingController _depthController = TextEditingController(
    text: widget.initialData.depth.toString(),
  );
  late final TextEditingController _tileWidthController = TextEditingController(
    text: widget.initialData.tileWidth.toString(),
  );
  late final TextEditingController _tileHeightController =
      TextEditingController(
    text: widget.initialData.tileHeight.toString(),
  );
  late final TextEditingController _tilemapWidthController =
      TextEditingController(
    text: widget.initialData.tilemapWidth.toString(),
  );
  late final TextEditingController _tilemapHeightController =
      TextEditingController(
    text: widget.initialData.tilemapHeight.toString(),
  );

  late String _tilesSheetFile = widget.initialData.tilesSheetFile;
  late bool _visible = widget.initialData.visible;

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      _tilesSheetFile.trim().isNotEmpty;

  Future<void> _pickTilesSheet() async {
    final String picked = await widget.onPickTilesSheet();
    if (!mounted || picked.isEmpty) {
      return;
    }
    setState(() {
      _tilesSheetFile = picked;
    });
  }

  void _confirm() {
    if (!_isValid) {
      return;
    }

    widget.onConfirm(
      _LayerDialogData(
        name: _nameController.text.trim(),
        x: int.tryParse(_xController.text.trim()) ?? 0,
        y: int.tryParse(_yController.text.trim()) ?? 0,
        depth: int.tryParse(_depthController.text.trim()) ?? 0,
        tilesSheetFile: _tilesSheetFile,
        tileWidth: int.tryParse(_tileWidthController.text.trim()) ?? 32,
        tileHeight: int.tryParse(_tileHeightController.text.trim()) ?? 32,
        tilemapWidth: int.tryParse(_tilemapWidthController.text.trim()) ?? 32,
        tilemapHeight: int.tryParse(_tilemapHeightController.text.trim()) ?? 16,
        visible: _visible,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _xController.dispose();
    _yController.dispose();
    _depthController.dispose();
    _tileWidthController.dispose();
    _tileHeightController.dispose();
    _tilemapWidthController.dispose();
    _tilemapHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    Widget labeledField(String label, Widget field) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CDKText(
            label,
            role: CDKTextRole.caption,
            color: cdkColors.colorText,
          ),
          const SizedBox(height: 4),
          field,
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 380, maxWidth: 520),
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CDKText(widget.title, role: CDKTextRole.title),
            SizedBox(height: spacing.md),
            const CDKText('Configure layer details.', role: CDKTextRole.body),
            SizedBox(height: spacing.md),
            labeledField(
              'Layer Name',
              CDKFieldText(
                placeholder: 'Layer name',
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _confirm(),
              ),
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Expanded(
                  child: labeledField(
                    'X (px)',
                    CDKFieldText(
                      placeholder: 'X (px)',
                      controller: _xController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: labeledField(
                    'Y (px)',
                    CDKFieldText(
                      placeholder: 'Y (px)',
                      controller: _yController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: labeledField(
                    'Depth (z-index)',
                    CDKFieldText(
                      placeholder: 'Depth (z-index)',
                      controller: _depthController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Expanded(
                  child: labeledField(
                    'Tile Width (px)',
                    CDKFieldText(
                      placeholder: 'Tile width (px)',
                      controller: _tileWidthController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: labeledField(
                    'Tile Height (px)',
                    CDKFieldText(
                      placeholder: 'Tile height (px)',
                      controller: _tileHeightController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Expanded(
                  child: labeledField(
                    'Tilemap Width (tiles)',
                    CDKFieldText(
                      placeholder: 'Tilemap width (tiles)',
                      controller: _tilemapWidthController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: labeledField(
                    'Tilemap Height (tiles)',
                    CDKFieldText(
                      placeholder: 'Tilemap height (tiles)',
                      controller: _tilemapHeightController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.md),
            CDKText(
              'Tilesheet Image',
              role: CDKTextRole.caption,
              color: cdkColors.colorText,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: CDKText(
                    _tilesSheetFile.isEmpty
                        ? 'No file selected'
                        : _tilesSheetFile,
                    role: CDKTextRole.caption,
                    color: cdkColors.colorText,
                  ),
                ),
                CDKButton(
                  style: CDKButtonStyle.action,
                  onPressed: _pickTilesSheet,
                  child: const Text('Choose File'),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                const CDKText('Visible', role: CDKTextRole.body),
                SizedBox(width: spacing.sm),
                CupertinoSwitch(
                  value: _visible,
                  onChanged: (bool value) {
                    setState(() {
                      _visible = value;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: spacing.lg + spacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CDKButton(
                  style: CDKButtonStyle.normal,
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                SizedBox(width: spacing.md),
                CDKButton(
                  style: CDKButtonStyle.action,
                  enabled: _isValid,
                  onPressed: _confirm,
                  child: Text(widget.confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
