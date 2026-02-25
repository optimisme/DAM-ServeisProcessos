import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_layer.dart';
import 'game_media_asset.dart';

class LayoutLayers extends StatefulWidget {
  const LayoutLayers({super.key});

  @override
  LayoutLayersState createState() => LayoutLayersState();
}

class LayoutLayersState extends State<LayoutLayers> {
  final ScrollController scrollController = ScrollController();
  final GlobalKey _selectedEditAnchorKey = GlobalKey();

  String _formatDepthDisplacement(double depth) {
    if (depth == depth.roundToDouble()) {
      return depth.toInt().toString();
    }
    final String fixed = depth.toStringAsFixed(2);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

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
    required List<GameMediaAsset> tilesetAssets,
    GlobalKey? anchorKey,
    bool useArrowedPopover = false,
    VoidCallback? onDelete,
  }) async {
    if (Overlay.maybeOf(context) == null) {
      return null;
    }

    final CDKDialogController controller = CDKDialogController();
    final Completer<_LayerDialogData?> completer =
        Completer<_LayerDialogData?>();
    _LayerDialogData? result;

    final dialogChild = _LayerFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialData: initialData,
      tilesetAssets: tilesetAssets,
      onConfirm: (value) {
        result = value;
        controller.close();
      },
      onCancel: controller.close,
      onDelete: onDelete != null
          ? () {
              controller.close();
              onDelete();
            }
          : null,
    );

    if (useArrowedPopover && anchorKey != null) {
      CDKDialogsManager.showPopoverArrowed(
        context: context,
        anchorKey: anchorKey,
        isAnimated: true,
        animateContentResize: false,
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

  Future<void> _promptAndAddLayer(List<GameMediaAsset> tilesetAssets) async {
    final GameMediaAsset first = tilesetAssets.first;
    final _LayerDialogData? data = await _promptLayerData(
      title: 'New layer',
      confirmLabel: 'Add',
      initialData: _LayerDialogData(
        name: '',
        x: 0,
        y: 0,
        depth: 0.0,
        tilesSheetFile: first.fileName,
        tileWidth: first.tileWidth,
        tileHeight: first.tileHeight,
        tilemapWidth: 32,
        tilemapHeight: 16,
        visible: true,
      ),
      tilesetAssets: tilesetAssets,
    );
    if (!mounted || data == null) {
      return;
    }
    final AppData appData = Provider.of<AppData>(context, listen: false);
    appData.pushUndo();
    _addLayer(appData: appData, data: data);
    await _autoSaveIfPossible(appData);
  }

  Future<void> _promptAndEditLayer(
    int index,
    GlobalKey anchorKey,
    List<GameMediaAsset> tilesetAssets,
  ) async {
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
      tilesetAssets: tilesetAssets,
      anchorKey: anchorKey,
      useArrowedPopover: true,
      onDelete: () => _confirmAndDeleteLayer(index),
    );

    if (!mounted || data == null) {
      return;
    }

    appData.pushUndo();
    _updateLayer(appData: appData, index: index, data: data);
    await _autoSaveIfPossible(appData);
  }

  Future<void> _confirmAndDeleteLayer(int index) async {
    if (!mounted) return;
    final AppData appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1) return;
    final layers = appData.gameData.levels[appData.selectedLevel].layers;
    if (index < 0 || index >= layers.length) return;
    final String layerName = layers[index].name;

    final bool? confirmed = await CDKDialogsManager.showConfirm(
      context: context,
      title: 'Delete layer',
      message: 'Delete "$layerName"? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
      showBackgroundShade: true,
    );

    if (confirmed != true || !mounted) return;
    appData.pushUndo();
    layers.removeAt(index);
    appData.selectedLayer = -1;
    appData.update();
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

    appData.pushUndo();
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
    final TextStyle listItemTitleStyle = typography.body.copyWith(
      fontSize: (typography.body.fontSize ?? 14) + 2,
      fontWeight: FontWeight.w700,
    );

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
    final List<GameMediaAsset> tilesetAssets = appData.gameData.mediaAssets
        .where((a) => a.hasTileGrid)
        .toList(growable: false);
    final bool hasTilesets = tilesetAssets.isNotEmpty;

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
              ),
              const Spacer(),
              if (hasTilesets)
                CDKButton(
                  style: CDKButtonStyle.action,
                  onPressed: () async {
                    await _promptAndAddLayer(tilesetAssets);
                  },
                  child: const Text('+ Add Layer'),
                )
              else
                CDKText(
                  'Add a tileset in Media first.',
                  role: CDKTextRole.caption,
                  secondary: true,
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
                            'Depth displacement ${_formatDepthDisplacement(layer.depth)} | ${mapWidth}x$mapHeight tiles';
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
                                        style: listItemTitleStyle,
                                      ),
                                      const SizedBox(height: 2),
                                      CDKText(
                                        subtitle,
                                        role: CDKTextRole.body,
                                        color: cdkColors.colorText,
                                      ),
                                      const SizedBox(height: 2),
                                      CDKText(
                                        details,
                                        role: CDKTextRole.body,
                                        color: cdkColors.colorText,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected && hasTilesets)
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
                                          tilesetAssets,
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
  final double depth;
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
    required this.tilesetAssets,
    required this.onConfirm,
    required this.onCancel,
    this.onDelete,
  });

  final String title;
  final String confirmLabel;
  final _LayerDialogData initialData;
  final List<GameMediaAsset> tilesetAssets;
  final ValueChanged<_LayerDialogData> onConfirm;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

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
  late final TextEditingController _tilemapWidthController =
      TextEditingController(
    text: widget.initialData.tilemapWidth.toString(),
  );
  late final TextEditingController _tilemapHeightController =
      TextEditingController(
    text: widget.initialData.tilemapHeight.toString(),
  );

  late bool _visible = widget.initialData.visible;
  late int _selectedAssetIndex = _resolveInitialAssetIndex();

  int _resolveInitialAssetIndex() {
    final String current = widget.initialData.tilesSheetFile;
    if (current.isNotEmpty) {
      final int found =
          widget.tilesetAssets.indexWhere((a) => a.fileName == current);
      if (found != -1) return found;
    }
    return 0;
  }

  GameMediaAsset get _selectedAsset =>
      widget.tilesetAssets[_selectedAssetIndex];

  double? _parseDepthValue(String raw) {
    final String cleaned = raw.trim();
    if (cleaned.isEmpty) {
      return 0.0;
    }
    final String normalized = cleaned.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String? get _depthErrorText {
    if (_parseDepthValue(_depthController.text) == null) {
      return 'Enter a valid decimal number (for example: -0.5 or 1.25).';
    }
    return null;
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty && _depthErrorText == null;

  void _confirm() {
    final double? parsedDepth = _parseDepthValue(_depthController.text);
    if (!_isValid || parsedDepth == null) {
      return;
    }

    final GameMediaAsset asset = _selectedAsset;
    widget.onConfirm(
      _LayerDialogData(
        name: _nameController.text.trim(),
        x: int.tryParse(_xController.text.trim()) ?? 0,
        y: int.tryParse(_yController.text.trim()) ?? 0,
        depth: parsedDepth,
        tilesSheetFile: asset.fileName,
        tileWidth: asset.tileWidth,
        tileHeight: asset.tileHeight,
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

    final GameMediaAsset asset = _selectedAsset;
    final List<String> assetOptions =
        widget.tilesetAssets.map((a) => a.fileName).toList(growable: false);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: ConstrainedBox(
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
                      'Depth displacement',
                      CDKFieldText(
                        placeholder: 'Depth displacement',
                        controller: _depthController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                ],
              ),
              if (_depthErrorText != null) ...[
                const SizedBox(height: 4),
                CDKText(
                  _depthErrorText!,
                  role: CDKTextRole.caption,
                  color: CupertinoColors.systemRed.resolveFrom(context),
                ),
              ],
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CDKText(
                          'Tilesheet',
                          role: CDKTextRole.caption,
                          color: cdkColors.colorText,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CDKButtonSelect(
                              selectedIndex: _selectedAssetIndex,
                              options: assetOptions,
                              onSelected: (int index) {
                                setState(() {
                                  _selectedAssetIndex = index;
                                });
                              },
                            ),
                            SizedBox(width: spacing.md),
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CDKText(
                                  'Visible',
                                  role: CDKTextRole.caption,
                                  color: cdkColors.colorText,
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 39,
                                  height: 24,
                                  child: FittedBox(
                                    fit: BoxFit.fill,
                                    child: CupertinoSwitch(
                                      value: _visible,
                                      onChanged: (bool value) {
                                        setState(() {
                                          _visible = value;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        CDKText(
                          'Tile size: ${asset.tileWidth}×${asset.tileHeight} px',
                          role: CDKTextRole.caption,
                          secondary: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.lg + spacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.onDelete != null)
                    CDKButton(
                      style: CDKButtonStyle.destructive,
                      onPressed: widget.onDelete,
                      child: const Text('Delete'),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
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
            ],
          ),
        ),
      ),
    );
  }
}
