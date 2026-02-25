import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_media_asset.dart';
import 'widgets/edit_session.dart';
import 'widgets/editor_form_dialog_scaffold.dart';
import 'widgets/editor_labeled_field.dart';

class LayoutMedia extends StatefulWidget {
  const LayoutMedia({super.key});

  @override
  State<LayoutMedia> createState() => _LayoutMediaState();
}

class _LayoutMediaState extends State<LayoutMedia> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _selectedEditAnchorKey = GlobalKey();

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

  Future<Size?> _readImageSize(String path) async {
    if (path.isEmpty) {
      return null;
    }
    try {
      final File file = File(path);
      if (!file.existsSync()) {
        return null;
      }
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;
      final Size size = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );
      image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  void _addMedia({
    required AppData appData,
    required _MediaDialogData data,
  }) {
    appData.gameData.mediaAssets.add(
      GameMediaAsset(
        name: data.name,
        fileName: data.fileName,
        mediaType: data.mediaType,
        tileWidth: data.tileWidth,
        tileHeight: data.tileHeight,
      ),
    );
    appData.selectedMedia = appData.gameData.mediaAssets.length - 1;
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
      name: data.name,
      fileName: data.fileName,
      mediaType: data.mediaType,
      tileWidth: data.tileWidth,
      tileHeight: data.tileHeight,
      selectionColorHex: assets[index].selectionColorHex,
    );
    appData.selectedMedia = index;
  }

  Future<_MediaDialogData?> _promptMediaData({
    required String title,
    required String confirmLabel,
    required _MediaDialogData initialData,
    GlobalKey? anchorKey,
    bool useArrowedPopover = false,
    bool liveEdit = false,
    Future<void> Function(_MediaDialogData value)? onLiveChanged,
    VoidCallback? onDelete,
  }) async {
    if (Overlay.maybeOf(context) == null) {
      return null;
    }

    final AppData appData = Provider.of<AppData>(context, listen: false);
    final CDKDialogController controller = CDKDialogController();
    final Completer<_MediaDialogData?> completer =
        Completer<_MediaDialogData?>();
    _MediaDialogData? result;

    final dialogChild = _MediaFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialData: initialData,
      liveEdit: liveEdit,
      onLiveChanged: onLiveChanged,
      onClose: () {
        unawaited(() async {
          await appData.flushPendingAutosave();
          controller.close();
        }());
      },
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

  Future<void> _pickAndPromptAddMedia() async {
    final appData = Provider.of<AppData>(context, listen: false);
    final String fileName = await appData.pickImageFile();
    if (!mounted || fileName.isEmpty) {
      return;
    }

    final String previewPath = _resolveMediaPreviewPath(appData, fileName);
    final Size? imageSize = await _readImageSize(previewPath);
    if (!mounted) {
      return;
    }
    final int defaultWidth = (() {
      final int value = imageSize?.width.toInt() ?? 32;
      return value < 1 ? 1 : value;
    })();
    final int defaultHeight = (() {
      final int value = imageSize?.height.toInt() ?? 32;
      return value < 1 ? 1 : value;
    })();

    final _MediaDialogData? data = await _promptMediaData(
      title: 'New media',
      confirmLabel: 'Add',
      initialData: _MediaDialogData(
        name: GameMediaAsset.inferNameFromFileName(fileName),
        fileName: fileName,
        mediaType: 'tileset',
        tileWidth: defaultWidth,
        tileHeight: defaultHeight,
        previewPath: previewPath,
      ),
    );

    if (!mounted || data == null) {
      return;
    }

    await appData.runProjectMutation(
      debugLabel: 'media-add',
      mutate: () {
        _addMedia(appData: appData, data: data);
      },
    );
  }

  Future<void> _confirmAndDeleteMedia(int index) async {
    if (!mounted) return;
    final AppData appData = Provider.of<AppData>(context, listen: false);
    final assets = appData.gameData.mediaAssets;
    if (index < 0 || index >= assets.length) return;
    final GameMediaAsset asset = assets[index];
    final String label =
        asset.name.trim().isNotEmpty ? asset.name : asset.fileName;

    final bool? confirmed = await CDKDialogsManager.showConfirm(
      context: context,
      title: 'Delete media',
      message: 'Delete "$label"? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
      showBackgroundShade: true,
    );

    if (confirmed != true || !mounted) return;
    await appData.runProjectMutation(
      debugLabel: 'media-delete',
      mutate: () {
        assets.removeAt(index);
        appData.selectedMedia = -1;
      },
    );
  }

  Future<void> _promptAndEditMedia(int index, GlobalKey anchorKey) async {
    final appData = Provider.of<AppData>(context, listen: false);
    final assets = appData.gameData.mediaAssets;
    if (index < 0 || index >= assets.length) {
      return;
    }

    final asset = assets[index];
    final String undoGroupKey =
        'media-live-$index-${DateTime.now().microsecondsSinceEpoch}';
    await _promptMediaData(
      title: 'Edit media',
      confirmLabel: 'Save',
      initialData: _MediaDialogData(
        name: asset.name,
        fileName: asset.fileName,
        mediaType: asset.mediaType,
        tileWidth: asset.tileWidth,
        tileHeight: asset.tileHeight,
        previewPath: _resolveMediaPreviewPath(appData, asset.fileName),
      ),
      anchorKey: anchorKey,
      useArrowedPopover: true,
      liveEdit: true,
      onLiveChanged: (value) async {
        await appData.runProjectMutation(
          debugLabel: 'media-live-edit',
          undoGroupKey: undoGroupKey,
          mutate: () {
            _updateMedia(appData: appData, index: index, data: value);
          },
        );
      },
      onDelete: () => _confirmAndDeleteMedia(index),
    );
  }

  void _selectMedia(AppData appData, int index, bool isSelected) {
    appData.selectedMedia = isSelected ? -1 : index;
    appData.update();
  }

  void _onReorder(AppData appData, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    unawaited(
      appData.runProjectMutation(
        debugLabel: 'media-reorder',
        mutate: () {
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
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    final TextStyle listItemTitleStyle = typography.body.copyWith(
      fontSize: (typography.body.fontSize ?? 14) + 2,
      fontWeight: FontWeight.w700,
    );

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
                        final String subtitle = switch (asset.mediaType) {
                          'tileset' =>
                            'Tileset (Tile ${asset.tileWidth}x${asset.tileHeight})',
                          'spritesheet' =>
                            'Spritesheet (Frame ${asset.tileWidth}x${asset.tileHeight})',
                          'atlas' =>
                            'Atlas (Tile/Frame ${asset.tileWidth}x${asset.tileHeight})',
                          _ => 'Image',
                        };

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
                                  switch (asset.mediaType) {
                                    'tileset' => CupertinoIcons.square_grid_2x2,
                                    'spritesheet' => CupertinoIcons.film,
                                    'atlas' =>
                                      CupertinoIcons.rectangle_grid_2x2,
                                    _ => CupertinoIcons.photo,
                                  },
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
                                        asset.name,
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
                                        asset.fileName,
                                        role: CDKTextRole.caption,
                                        color: cdkColors.colorText,
                                        secondary: true,
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
    required this.name,
    required this.fileName,
    required this.mediaType,
    required this.tileWidth,
    required this.tileHeight,
    required this.previewPath,
  });

  final String name;
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
    this.liveEdit = false,
    this.onLiveChanged,
    this.onClose,
    required this.onConfirm,
    required this.onCancel,
    this.onDelete,
  });

  final String title;
  final String confirmLabel;
  final _MediaDialogData initialData;
  final bool liveEdit;
  final Future<void> Function(_MediaDialogData value)? onLiveChanged;
  final VoidCallback? onClose;
  final ValueChanged<_MediaDialogData> onConfirm;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  State<_MediaFormDialog> createState() => _MediaFormDialogState();
}

class _MediaFormDialogState extends State<_MediaFormDialog> {
  static const List<String> _typeValues = [
    'tileset',
    'spritesheet',
    'atlas',
  ];

  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialData.name);
  late final TextEditingController _tileWidthController =
      TextEditingController(text: widget.initialData.tileWidth.toString());
  late final TextEditingController _tileHeightController =
      TextEditingController(text: widget.initialData.tileHeight.toString());
  late String _mediaType = _typeValues.contains(widget.initialData.mediaType)
      ? widget.initialData.mediaType
      : 'tileset';
  String? _sizeError;
  EditSession<_MediaDialogData>? _editSession;

  bool get _hasTileGrid => _typeValues.contains(_mediaType);

  String get _sizeLabelPrefix {
    switch (_mediaType) {
      case 'spritesheet':
        return 'Frame';
      case 'atlas':
        return 'Tile/Frame';
      default:
        return 'Tile';
    }
  }

  bool get _isValid {
    if (_nameController.text.trim().isEmpty) {
      return false;
    }
    if (!_hasTileGrid) {
      return true;
    }
    final int? width = int.tryParse(_tileWidthController.text.trim());
    final int? height = int.tryParse(_tileHeightController.text.trim());
    return width != null && height != null && width > 0 && height > 0;
  }

  _MediaDialogData _currentData() {
    return _MediaDialogData(
      name: _nameController.text.trim(),
      fileName: widget.initialData.fileName,
      mediaType: _mediaType,
      tileWidth: int.tryParse(_tileWidthController.text.trim()) ?? 32,
      tileHeight: int.tryParse(_tileHeightController.text.trim()) ?? 32,
      previewPath: widget.initialData.previewPath,
    );
  }

  String? _validateData(_MediaDialogData value) {
    if (_nameController.text.trim().isEmpty) {
      return 'Name is required.';
    }
    if (!_hasTileGrid) {
      return null;
    }
    final int? width = int.tryParse(_tileWidthController.text.trim());
    final int? height = int.tryParse(_tileHeightController.text.trim());
    if (width == null || height == null || width <= 0 || height <= 0) {
      return '$_sizeLabelPrefix width and height must be positive integers.';
    }
    return null;
  }

  void _onInputChanged() {
    if (widget.liveEdit) {
      _editSession?.update(_currentData());
    }
  }

  void _validateTileFields() {
    if (!_hasTileGrid || _isValid) {
      setState(() {
        _sizeError = null;
      });
      _onInputChanged();
      return;
    }
    setState(() {
      _sizeError =
          '$_sizeLabelPrefix width and height must be positive integers.';
    });
    _onInputChanged();
  }

  void _confirm() {
    _validateTileFields();
    if (!_isValid) {
      return;
    }

    widget.onConfirm(
      _MediaDialogData(
        name: _nameController.text.trim(),
        fileName: widget.initialData.fileName,
        mediaType: _mediaType,
        tileWidth: int.tryParse(_tileWidthController.text.trim()) ?? 32,
        tileHeight: int.tryParse(_tileHeightController.text.trim()) ?? 32,
        previewPath: widget.initialData.previewPath,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.liveEdit && widget.onLiveChanged != null) {
      _editSession = EditSession<_MediaDialogData>(
        initialValue: _currentData(),
        validate: _validateData,
        onPersist: widget.onLiveChanged!,
        areEqual: (a, b) =>
            a.name == b.name &&
            a.mediaType == b.mediaType &&
            a.tileWidth == b.tileWidth &&
            a.tileHeight == b.tileHeight,
      );
    }
  }

  @override
  void dispose() {
    if (_editSession != null) {
      unawaited(_editSession!.flush());
      _editSession!.dispose();
    }
    _nameController.dispose();
    _tileWidthController.dispose();
    _tileHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    final String sizeLabelPrefix = _sizeLabelPrefix;

    return EditorFormDialogScaffold(
      title: widget.title,
      description: 'Configure media metadata.',
      confirmLabel: widget.confirmLabel,
      confirmEnabled: _isValid,
      onConfirm: _confirm,
      onCancel: widget.onCancel,
      liveEditMode: widget.liveEdit,
      onClose: widget.onClose,
      onDelete: widget.onDelete,
      minWidth: 420,
      maxWidth: 540,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorLabeledField(
            label: 'Name',
            child: CDKFieldText(
              placeholder: 'Media name',
              controller: _nameController,
              onChanged: (_) {
                setState(() {});
                _onInputChanged();
              },
              onSubmitted: (_) {
                if (widget.liveEdit) {
                  _onInputChanged();
                  return;
                }
                _confirm();
              },
            ),
          ),
          SizedBox(height: spacing.sm),
          EditorLabeledField(
            label: 'File',
            child: CDKText(
              widget.initialData.fileName,
              role: CDKTextRole.body,
            ),
          ),
          SizedBox(height: spacing.md),
          EditorLabeledField(
            label: 'Kind',
            child: CDKPickerButtonsSegmented(
              selectedIndex: _typeValues
                  .indexOf(_mediaType)
                  .clamp(0, _typeValues.length - 1),
              options: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: CDKText('Tileset', role: CDKTextRole.caption),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: CDKText('Spritesheet', role: CDKTextRole.caption),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: CDKText('Atlas', role: CDKTextRole.caption),
                ),
              ],
              onSelected: (selectedIndex) {
                setState(() {
                  _mediaType = _typeValues[selectedIndex];
                  if (!_hasTileGrid) {
                    _sizeError = null;
                  }
                });
                _onInputChanged();
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            child: _hasTileGrid
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: spacing.sm),
                      EditorLabeledField(
                        label: '$sizeLabelPrefix Width (px)',
                        child: CDKFieldText(
                          placeholder:
                              '${sizeLabelPrefix.toLowerCase()} width (px)',
                          controller: _tileWidthController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _validateTileFields(),
                          onSubmitted: (_) {
                            if (widget.liveEdit) {
                              _onInputChanged();
                              return;
                            }
                            _confirm();
                          },
                        ),
                      ),
                      SizedBox(height: spacing.sm),
                      EditorLabeledField(
                        label: '$sizeLabelPrefix Height (px)',
                        child: CDKFieldText(
                          placeholder:
                              '${sizeLabelPrefix.toLowerCase()} height (px)',
                          controller: _tileHeightController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _validateTileFields(),
                          onSubmitted: (_) {
                            if (widget.liveEdit) {
                              _onInputChanged();
                              return;
                            }
                            _confirm();
                          },
                        ),
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
        ],
      ),
    );
  }
}
