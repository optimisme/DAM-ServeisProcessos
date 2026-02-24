import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_sprite.dart';

class LayoutSprites extends StatefulWidget {
  const LayoutSprites({super.key});

  @override
  LayoutSpritesState createState() => LayoutSpritesState();
}

class LayoutSpritesState extends State<LayoutSprites> {
  final ScrollController scrollController = ScrollController();
  final GlobalKey _selectedEditAnchorKey = GlobalKey();

  Future<void> _autoSaveIfPossible(AppData appData) async {
    if (appData.selectedProject == null) {
      return;
    }
    await appData.saveGame();
  }

  void updateForm(AppData appData) {
    if (mounted) {
      setState(() {});
    }
  }

  void _addSprite({
    required AppData appData,
    required _SpriteDialogData data,
  }) {
    if (appData.selectedLevel == -1) {
      return;
    }
    appData.gameData.levels[appData.selectedLevel].sprites.add(
      GameSprite(
        type: data.type,
        x: data.x,
        y: data.y,
        spriteWidth: data.width,
        spriteHeight: data.height,
        imageFile: data.imageFile,
      ),
    );
    appData.selectedSprite = -1;
    appData.update();
  }

  void _updateSprite({
    required AppData appData,
    required int index,
    required _SpriteDialogData data,
  }) {
    if (appData.selectedLevel == -1) {
      return;
    }
    final sprites = appData.gameData.levels[appData.selectedLevel].sprites;
    if (index < 0 || index >= sprites.length) {
      return;
    }
    sprites[index] = GameSprite(
      type: data.type,
      x: data.x,
      y: data.y,
      spriteWidth: data.width,
      spriteHeight: data.height,
      imageFile: data.imageFile,
    );
    appData.selectedSprite = index;
    appData.update();
  }

  Future<_SpriteDialogData?> _promptSpriteData({
    required String title,
    required String confirmLabel,
    required _SpriteDialogData initialData,
    GlobalKey? anchorKey,
    bool useArrowedPopover = false,
  }) async {
    if (Overlay.maybeOf(context) == null) {
      return null;
    }

    final AppData appData = Provider.of<AppData>(context, listen: false);
    final CDKDialogController controller = CDKDialogController();
    final Completer<_SpriteDialogData?> completer =
        Completer<_SpriteDialogData?>();
    _SpriteDialogData? result;

    final dialogChild = _SpriteFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialData: initialData,
      onPickImage: appData.pickImageFile,
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

  Future<void> _promptAndAddSprite() async {
    final data = await _promptSpriteData(
      title: 'New sprite',
      confirmLabel: 'Add',
      initialData: const _SpriteDialogData(
        type: '',
        x: 0,
        y: 0,
        width: 32,
        height: 32,
        imageFile: '',
      ),
    );
    if (!mounted || data == null) {
      return;
    }
    final appData = Provider.of<AppData>(context, listen: false);
    _addSprite(appData: appData, data: data);
    await _autoSaveIfPossible(appData);
  }

  Future<void> _promptAndEditSprite(int index, GlobalKey anchorKey) async {
    final appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1) {
      return;
    }
    final sprites = appData.gameData.levels[appData.selectedLevel].sprites;
    if (index < 0 || index >= sprites.length) {
      return;
    }
    final sprite = sprites[index];
    final data = await _promptSpriteData(
      title: 'Edit sprite',
      confirmLabel: 'Save',
      initialData: _SpriteDialogData(
        type: sprite.type,
        x: sprite.x,
        y: sprite.y,
        width: sprite.spriteWidth,
        height: sprite.spriteHeight,
        imageFile: sprite.imageFile,
      ),
      anchorKey: anchorKey,
      useArrowedPopover: true,
    );
    if (!mounted || data == null) {
      return;
    }
    _updateSprite(appData: appData, index: index, data: data);
    await _autoSaveIfPossible(appData);
  }

  void _selectSprite(AppData appData, int index, bool isSelected) {
    if (isSelected) {
      return;
    }
    appData.selectedSprite = index;
    appData.update();
  }

  void selectSprite(AppData appData, int index, bool isSelected) {
    _selectSprite(appData, index, isSelected);
  }

  void _onReorder(AppData appData, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final sprites = appData.gameData.levels[appData.selectedLevel].sprites;
    final int selectedIndex = appData.selectedSprite;
    final sprite = sprites.removeAt(oldIndex);
    sprites.insert(newIndex, sprite);

    if (selectedIndex == oldIndex) {
      appData.selectedSprite = newIndex;
    } else if (selectedIndex > oldIndex && selectedIndex <= newIndex) {
      appData.selectedSprite -= 1;
    } else if (selectedIndex < oldIndex && selectedIndex >= newIndex) {
      appData.selectedSprite += 1;
    }

    appData.update();
    unawaited(_autoSaveIfPossible(appData));
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);

    if (appData.selectedLevel == -1) {
      return const Center(
        child: CDKText(
          'No level selected',
          role: CDKTextRole.body,
          secondary: true,
        ),
      );
    }

    final level = appData.gameData.levels[appData.selectedLevel];
    final sprites = level.sprites;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Row(
            children: [
              CDKText(
                'Sprites',
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
                  await _promptAndAddSprite();
                },
                child: const Text('+ Add Sprite'),
              ),
            ],
          ),
        ),
        Expanded(
          child: sprites.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: const CDKText(
                    '(No sprites defined)',
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
                      itemCount: sprites.length,
                      onReorder: (oldIndex, newIndex) =>
                          _onReorder(appData, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final isSelected = index == appData.selectedSprite;
                        final sprite = sprites[index];
                        final subtitle =
                            '${sprite.x}, ${sprite.y} - ${sprite.imageFile}';
                        return GestureDetector(
                          key: ValueKey(sprite),
                          onTap: () =>
                              _selectSprite(appData, index, isSelected),
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
                                        sprite.type,
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
                                        await _promptAndEditSprite(
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

class _SpriteDialogData {
  const _SpriteDialogData({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.imageFile,
  });

  final String type;
  final int x;
  final int y;
  final int width;
  final int height;
  final String imageFile;
}

class _SpriteFormDialog extends StatefulWidget {
  const _SpriteFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialData,
    required this.onPickImage,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final String confirmLabel;
  final _SpriteDialogData initialData;
  final Future<String> Function() onPickImage;
  final ValueChanged<_SpriteDialogData> onConfirm;
  final VoidCallback onCancel;

  @override
  State<_SpriteFormDialog> createState() => _SpriteFormDialogState();
}

class _SpriteFormDialogState extends State<_SpriteFormDialog> {
  late final TextEditingController _typeController = TextEditingController(
    text: widget.initialData.type,
  );
  late final TextEditingController _xController = TextEditingController(
    text: widget.initialData.x.toString(),
  );
  late final TextEditingController _yController = TextEditingController(
    text: widget.initialData.y.toString(),
  );
  late final TextEditingController _widthController = TextEditingController(
    text: widget.initialData.width.toString(),
  );
  late final TextEditingController _heightController = TextEditingController(
    text: widget.initialData.height.toString(),
  );
  late String _imageFile = widget.initialData.imageFile;

  bool get _isValid =>
      _typeController.text.trim().isNotEmpty && _imageFile.trim().isNotEmpty;

  Future<void> _pickImage() async {
    final String picked = await widget.onPickImage();
    if (!mounted || picked.isEmpty) {
      return;
    }
    setState(() {
      _imageFile = picked;
    });
  }

  void _confirm() {
    if (!_isValid) {
      return;
    }
    widget.onConfirm(
      _SpriteDialogData(
        type: _typeController.text.trim(),
        x: int.tryParse(_xController.text.trim()) ?? 0,
        y: int.tryParse(_yController.text.trim()) ?? 0,
        width: int.tryParse(_widthController.text.trim()) ?? 32,
        height: int.tryParse(_heightController.text.trim()) ?? 32,
        imageFile: _imageFile,
      ),
    );
  }

  @override
  void dispose() {
    _typeController.dispose();
    _xController.dispose();
    _yController.dispose();
    _widthController.dispose();
    _heightController.dispose();
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
      constraints: const BoxConstraints(minWidth: 360, maxWidth: 460),
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CDKText(widget.title, role: CDKTextRole.title),
            SizedBox(height: spacing.md),
            const CDKText('Configure sprite details.', role: CDKTextRole.body),
            SizedBox(height: spacing.md),
            labeledField(
              'Sprite Type',
              CDKFieldText(
                placeholder: 'Sprite type',
                controller: _typeController,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _confirm(),
              ),
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Expanded(
                  child: labeledField(
                    'Start X (px)',
                    CDKFieldText(
                      placeholder: 'Start X (px)',
                      controller: _xController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: labeledField(
                    'Start Y (px)',
                    CDKFieldText(
                      placeholder: 'Start Y (px)',
                      controller: _yController,
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
                    'Sprite Width (px)',
                    CDKFieldText(
                      placeholder: 'Sprite Width (px)',
                      controller: _widthController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: labeledField(
                    'Sprite Height (px)',
                    CDKFieldText(
                      placeholder: 'Sprite Height (px)',
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.md),
            CDKText(
              'Sprite Image',
              role: CDKTextRole.caption,
              color: cdkColors.colorText,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: CDKText(
                    _imageFile.isEmpty ? 'No file selected' : _imageFile,
                    role: CDKTextRole.caption,
                    color: cdkColors.colorText,
                  ),
                ),
                CDKButton(
                  style: CDKButtonStyle.action,
                  onPressed: _pickImage,
                  child: const Text('Choose File'),
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
