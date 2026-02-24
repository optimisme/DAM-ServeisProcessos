import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_media_asset.dart';

class LayoutMedia extends StatefulWidget {
  const LayoutMedia({super.key});

  @override
  State<LayoutMedia> createState() => _LayoutMediaState();
}

class _LayoutMediaState extends State<LayoutMedia> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _selectedEditAnchorKey = GlobalKey();

  Future<void> _autoSaveIfPossible(AppData appData) async {
    if (appData.selectedProject == null) {
      return;
    }
    await appData.saveGame();
  }

  String _resolveMediaPreviewPath(AppData appData, String fileName) {
    if (fileName.isEmpty) {
      return '';
    }
    if (fileName.contains(Platform.pathSeparator) || fileName.startsWith('/')) {
      return fileName;
    }
    if (appData.filePath.isEmpty) {
      return fileName;
    }
    return '${appData.filePath}${Platform.pathSeparator}$fileName';
  }

  void _addMedia({
    required AppData appData,
    required _MediaDialogData data,
  }) {
    appData.gameData.mediaAssets.add(
      GameMediaAsset(
        fileName: data.fileName,
        mediaType: data.mediaType,
        tileWidth: data.tileWidth,
        tileHeight: data.tileHeight,
      ),
    );
    appData.selectedMedia = appData.gameData.mediaAssets.length - 1;
    appData.update();
  }

  void _updateMedia({
    required AppData appData,
    required int index,
    required _MediaDialogData data,
  }) {
    final assets = appData.gameData.mediaAssets;
    if (index < 0 || index >= assets.length) {
      return;
    }

    assets[index] = GameMediaAsset(
      fileName: data.fileName,
      mediaType: data.mediaType,
      tileWidth: data.tileWidth,
      tileHeight: data.tileHeight,
    );
    appData.selectedMedia = index;
    appData.update();
  }

  Future<_MediaDialogData?> _promptMediaData({
    required String title,
    required String confirmLabel,
    required _MediaDialogData initialData,
    GlobalKey? anchorKey,
    bool useArrowedPopover = false,
  }) async {
    if (Overlay.maybeOf(context) == null) {
      return null;
    }

    final CDKDialogController controller = CDKDialogController();
    final Completer<_MediaDialogData?> completer =
        Completer<_MediaDialogData?>();
    _MediaDialogData? result;

    final dialogChild = _MediaFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialData: initialData,
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

  Future<void> _pickAndPromptAddMedia() async {
    final appData = Provider.of<AppData>(context, listen: false);
    final String fileName = await appData.pickImageFile();
    if (!mounted || fileName.isEmpty) {
      return;
    }

    final _MediaDialogData? data = await _promptMediaData(
      title: 'New media',
      confirmLabel: 'Add',
      initialData: _MediaDialogData(
        fileName: fileName,
        mediaType: 'image',
        tileWidth: 32,
        tileHeight: 32,
        previewPath: _resolveMediaPreviewPath(appData, fileName),
      ),
    );

    if (!mounted || data == null) {
      return;
    }

    _addMedia(appData: appData, data: data);
    await _autoSaveIfPossible(appData);
  }

  Future<void> _promptAndEditMedia(int index, GlobalKey anchorKey) async {
    final appData = Provider.of<AppData>(context, listen: false);
    final assets = appData.gameData.mediaAssets;
    if (index < 0 || index >= assets.length) {
      return;
    }

    final asset = assets[index];
    final _MediaDialogData? updated = await _promptMediaData(
      title: 'Edit media',
      confirmLabel: 'Save',
      initialData: _MediaDialogData(
        fileName: asset.fileName,
        mediaType: asset.mediaType,
        tileWidth: asset.tileWidth,
        tileHeight: asset.tileHeight,
        previewPath: _resolveMediaPreviewPath(appData, asset.fileName),
      ),
      anchorKey: anchorKey,
      useArrowedPopover: true,
    );

    if (!mounted || updated == null) {
      return;
    }

    _updateMedia(appData: appData, index: index, data: updated);
    await _autoSaveIfPossible(appData);
  }

  void _selectMedia(AppData appData, int index, bool isSelected) {
    appData.selectedMedia = isSelected ? -1 : index;
    appData.update();
  }

  void _onReorder(AppData appData, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final assets = appData.gameData.mediaAssets;
    final int selectedIndex = appData.selectedMedia;
    final item = assets.removeAt(oldIndex);
    assets.insert(newIndex, item);

    if (selectedIndex == oldIndex) {
      appData.selectedMedia = newIndex;
    } else if (selectedIndex > oldIndex && selectedIndex <= newIndex) {
      appData.selectedMedia -= 1;
    } else if (selectedIndex < oldIndex && selectedIndex >= newIndex) {
      appData.selectedMedia += 1;
    }

    appData.update();
    unawaited(_autoSaveIfPossible(appData));
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);

    if (appData.selectedProject == null) {
      return const Center(
        child: CDKText(
          'Select a project to manage media.',
          role: CDKTextRole.body,
          secondary: true,
        ),
      );
    }

    final assets = appData.gameData.mediaAssets;

    if (appData.selectedMedia >= assets.length) {
      appData.selectedMedia = assets.isEmpty ? -1 : assets.length - 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Row(
            children: [
              CDKText(
                'Media',
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
                  await _pickAndPromptAddMedia();
                },
                child: const Text('+ Add Media'),
              ),
            ],
          ),
        ),
        Expanded(
          child: assets.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: CDKText(
                    '(No media uploaded yet)',
                    role: CDKTextRole.caption,
                    secondary: true,
                  ),
                )
              : CupertinoScrollbar(
                  controller: _scrollController,
                  child: Localizations.override(
                    context: context,
                    delegates: [
                      DefaultMaterialLocalizations.delegate,
                      DefaultWidgetsLocalizations.delegate,
                    ],
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: assets.length,
                      onReorder: (oldIndex, newIndex) =>
                          _onReorder(appData, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final asset = assets[index];
                        final bool isSelected = index == appData.selectedMedia;
                        final String subtitle = asset.mediaType == 'tileset'
                            ? 'Tileset (${asset.tileWidth}x${asset.tileHeight})'
                            : 'Image';

                        return GestureDetector(
                          key: ValueKey(asset.fileName + index.toString()),
                          onTap: () => _selectMedia(appData, index, isSelected),
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
                                Icon(
                                  asset.mediaType == 'tileset'
                                      ? CupertinoIcons.square_grid_2x2
                                      : CupertinoIcons.photo,
                                  size: 16,
                                  color: cdkColors.colorText,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CDKText(
                                        asset.fileName,
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
                                        await _promptAndEditMedia(
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

class _MediaDialogData {
  const _MediaDialogData({
    required this.fileName,
    required this.mediaType,
    required this.tileWidth,
    required this.tileHeight,
    required this.previewPath,
  });

  final String fileName;
  final String mediaType;
  final int tileWidth;
  final int tileHeight;
  final String previewPath;
}

class _MediaFormDialog extends StatefulWidget {
  const _MediaFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialData,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final String confirmLabel;
  final _MediaDialogData initialData;
  final ValueChanged<_MediaDialogData> onConfirm;
  final VoidCallback onCancel;

  @override
  State<_MediaFormDialog> createState() => _MediaFormDialogState();
}

class _MediaFormDialogState extends State<_MediaFormDialog> {
  late final TextEditingController _tileWidthController =
      TextEditingController(text: widget.initialData.tileWidth.toString());
  late final TextEditingController _tileHeightController =
      TextEditingController(text: widget.initialData.tileHeight.toString());
  late String _mediaType =
      widget.initialData.mediaType == 'tileset' ? 'tileset' : 'image';
  String? _sizeError;

  bool get _isTileset => _mediaType == 'tileset';

  bool get _isValid {
    if (!_isTileset) {
      return true;
    }
    final int? width = int.tryParse(_tileWidthController.text.trim());
    final int? height = int.tryParse(_tileHeightController.text.trim());
    return width != null && height != null && width > 0 && height > 0;
  }

  void _validateTilesetFields() {
    if (!_isTileset || _isValid) {
      setState(() {
        _sizeError = null;
      });
      return;
    }
    setState(() {
      _sizeError = 'Tile width and height must be positive integers.';
    });
  }

  void _confirm() {
    _validateTilesetFields();
    if (!_isValid) {
      return;
    }

    widget.onConfirm(
      _MediaDialogData(
        fileName: widget.initialData.fileName,
        mediaType: _mediaType,
        tileWidth: int.tryParse(_tileWidthController.text.trim()) ?? 32,
        tileHeight: int.tryParse(_tileHeightController.text.trim()) ?? 32,
        previewPath: widget.initialData.previewPath,
      ),
    );
  }

  @override
  void dispose() {
    _tileWidthController.dispose();
    _tileHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    final File previewFile = File(widget.initialData.previewPath);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420, maxWidth: 540),
        child: Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CDKText(widget.title, role: CDKTextRole.title),
                        SizedBox(height: spacing.sm),
                        const CDKText(
                          'Configure media metadata.',
                          role: CDKTextRole.body,
                        ),
                        SizedBox(height: spacing.sm),
                        CDKText(
                          'File',
                          role: CDKTextRole.caption,
                          color: cdkColors.colorText,
                        ),
                        const SizedBox(height: 4),
                        CDKText(
                          widget.initialData.fileName,
                          role: CDKTextRole.body,
                          color: cdkColors.colorText,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 132,
                          height: 96,
                          color: cdkColors.backgroundSecondary0,
                          child: previewFile.existsSync()
                              ? Image.file(
                                  previewFile,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    CupertinoIcons.photo,
                                    color: cdkColors.colorTextSecondary,
                                  ),
                                )
                              : Icon(
                                  CupertinoIcons.photo,
                                  color: cdkColors.colorTextSecondary,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: spacing.md),
              CDKText(
                'Kind',
                role: CDKTextRole.caption,
                color: cdkColors.colorText,
              ),
              const SizedBox(height: 4),
              CDKPickerButtonsSegmented(
                selectedIndex: _isTileset ? 1 : 0,
                options: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: CDKText('Image', role: CDKTextRole.caption),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: CDKText('Tileset', role: CDKTextRole.caption),
                  ),
                ],
                onSelected: (selectedIndex) {
                  setState(() {
                    _mediaType = selectedIndex == 1 ? 'tileset' : 'image';
                    if (!_isTileset) {
                      _sizeError = null;
                    }
                  });
                },
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _isTileset
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: spacing.sm),
                            CDKText(
                              'Tile Width (px)',
                              role: CDKTextRole.caption,
                              color: cdkColors.colorText,
                            ),
                            const SizedBox(height: 4),
                            CDKFieldText(
                              placeholder: 'Tile width (px)',
                              controller: _tileWidthController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _validateTilesetFields(),
                              onSubmitted: (_) => _confirm(),
                            ),
                            SizedBox(height: spacing.sm),
                            CDKText(
                              'Tile Height (px)',
                              role: CDKTextRole.caption,
                              color: cdkColors.colorText,
                            ),
                            const SizedBox(height: 4),
                            CDKFieldText(
                              placeholder: 'Tile height (px)',
                              controller: _tileHeightController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _validateTilesetFields(),
                              onSubmitted: (_) => _confirm(),
                            ),
                            if (_sizeError != null) ...[
                              SizedBox(height: spacing.sm),
                              Text(
                                _sizeError!,
                                style: typography.caption.copyWith(
                                  color: CDKTheme.red,
                                ),
                              ),
                            ],
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
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
      ),
    );
  }
}
