import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_animation.dart';
import 'game_media_asset.dart';
import 'game_sprite.dart';
import 'widgets/edit_session.dart';
import 'widgets/editor_form_dialog_scaffold.dart';
import 'widgets/editor_labeled_field.dart';
import 'widgets/section_help_button.dart';

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
    appData.queueAutosave();
  }

  void updateForm(AppData appData) {
    if (mounted) {
      setState(() {});
    }
  }

  List<GameAnimation> _animations(AppData appData) {
    return appData.gameData.animations;
  }

  GameAnimation? _animationById(AppData appData, String animationId) {
    return appData.animationById(animationId);
  }

  GameAnimation? _defaultAnimation(
      AppData appData, List<GameAnimation> animations) {
    if (animations.isEmpty) {
      return null;
    }
    if (appData.selectedAnimation >= 0 &&
        appData.selectedAnimation < animations.length) {
      return animations[appData.selectedAnimation];
    }
    return animations.first;
  }

  _SpriteDialogData _dialogDataFromAnimation({
    required String name,
    required int x,
    required int y,
    required GameAnimation animation,
    required AppData appData,
    bool flipX = false,
    bool flipY = false,
    double depth = 0.0,
  }) {
    final GameMediaAsset? media =
        appData.mediaAssetByFileName(animation.mediaFile);
    return _SpriteDialogData(
      name: name,
      x: x,
      y: y,
      depth: depth,
      animationId: animation.id,
      width: media?.tileWidth ?? 32,
      height: media?.tileHeight ?? 32,
      imageFile: animation.mediaFile,
      flipX: flipX,
      flipY: flipY,
    );
  }

  _SpriteDialogData _dialogDataFromSprite({
    required AppData appData,
    required GameSprite sprite,
    required List<GameAnimation> animations,
  }) {
    GameAnimation? animation = _animationById(appData, sprite.animationId);
    animation ??= animations.isEmpty
        ? null
        : animations.firstWhere(
            (candidate) => candidate.mediaFile == sprite.imageFile,
            orElse: () => animations.first,
          );

    if (animation != null) {
      return _dialogDataFromAnimation(
        name: sprite.name,
        x: sprite.x,
        y: sprite.y,
        animation: animation,
        appData: appData,
        flipX: sprite.flipX,
        flipY: sprite.flipY,
        depth: sprite.depth,
      );
    }

    return _SpriteDialogData(
      name: sprite.name,
      x: sprite.x,
      y: sprite.y,
      depth: sprite.depth,
      animationId: sprite.animationId,
      width: sprite.spriteWidth,
      height: sprite.spriteHeight,
      imageFile: sprite.imageFile,
      flipX: sprite.flipX,
      flipY: sprite.flipY,
    );
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
        name: data.name,
        animationId: data.animationId,
        x: data.x,
        y: data.y,
        depth: data.depth,
        spriteWidth: data.width,
        spriteHeight: data.height,
        imageFile: data.imageFile,
        flipX: data.flipX,
        flipY: data.flipY,
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
      name: data.name,
      animationId: data.animationId,
      x: data.x,
      y: data.y,
      depth: data.depth,
      spriteWidth: data.width,
      spriteHeight: data.height,
      imageFile: data.imageFile,
      flipX: data.flipX,
      flipY: data.flipY,
    );
    appData.selectedSprite = index;
  }

  Future<_SpriteDialogData?> _promptSpriteData({
    required String title,
    required String confirmLabel,
    required _SpriteDialogData initialData,
    required List<GameAnimation> animations,
    GlobalKey? anchorKey,
    bool useArrowedPopover = false,
    bool liveEdit = false,
    Future<void> Function(_SpriteDialogData value)? onLiveChanged,
    VoidCallback? onDelete,
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
      animations: animations,
      resolveMediaByFileName: appData.mediaAssetByFileName,
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

  Future<void> _promptAndAddSprite(List<GameAnimation> animations) async {
    final AppData appData = Provider.of<AppData>(context, listen: false);
    final GameAnimation? defaultAnimation =
        _defaultAnimation(appData, animations);
    if (defaultAnimation == null) {
      return;
    }

    final _SpriteDialogData? data = await _promptSpriteData(
      title: 'New sprite',
      confirmLabel: 'Add',
      initialData: _dialogDataFromAnimation(
        name: '',
        x: 0,
        y: 0,
        animation: defaultAnimation,
        appData: appData,
      ),
      animations: animations,
    );
    if (!mounted || data == null) {
      return;
    }

    appData.pushUndo();
    _addSprite(appData: appData, data: data);
    await _autoSaveIfPossible(appData);
  }

  Future<void> _confirmAndDeleteSprite(int index) async {
    if (!mounted) return;
    final AppData appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1) return;
    final sprites = appData.gameData.levels[appData.selectedLevel].sprites;
    if (index < 0 || index >= sprites.length) return;
    final String spriteName = sprites[index].name;

    final bool? confirmed = await CDKDialogsManager.showConfirm(
      context: context,
      title: 'Delete sprite',
      message: 'Delete "$spriteName"? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
      showBackgroundShade: true,
    );

    if (confirmed != true || !mounted) return;
    appData.pushUndo();
    sprites.removeAt(index);
    appData.selectedSprite = -1;
    appData.update();
    await _autoSaveIfPossible(appData);
  }

  Future<void> _promptAndEditSprite(
    int index,
    GlobalKey anchorKey,
    List<GameAnimation> animations,
  ) async {
    final appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1) {
      return;
    }
    final sprites = appData.gameData.levels[appData.selectedLevel].sprites;
    if (index < 0 || index >= sprites.length) {
      return;
    }
    final sprite = sprites[index];
    final String undoGroupKey =
        'sprite-live-$index-${DateTime.now().microsecondsSinceEpoch}';

    await _promptSpriteData(
      title: 'Edit sprite',
      confirmLabel: 'Save',
      initialData: _dialogDataFromSprite(
        appData: appData,
        sprite: sprite,
        animations: animations,
      ),
      animations: animations,
      anchorKey: anchorKey,
      useArrowedPopover: true,
      liveEdit: true,
      onLiveChanged: (value) async {
        await appData.runProjectMutation(
          debugLabel: 'sprite-live-edit',
          undoGroupKey: undoGroupKey,
          mutate: () {
            _updateSprite(appData: appData, index: index, data: value);
          },
        );
      },
      onDelete: () => _confirmAndDeleteSprite(index),
    );
  }

  void _selectSprite(AppData appData, int index, bool isSelected) {
    if (isSelected) {
      appData.selectedSprite = -1;
      appData.update();
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
    appData.pushUndo();
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
    final TextStyle sectionTitleStyle = typography.title.copyWith(
      fontSize: (typography.title.fontSize ?? 17) + 2,
    );
    final TextStyle listItemTitleStyle = typography.body.copyWith(
      fontSize: (typography.body.fontSize ?? 14) + 2,
      fontWeight: FontWeight.w700,
    );

    final bool hasLevel = appData.selectedLevel >= 0 &&
        appData.selectedLevel < appData.gameData.levels.length;
    if (!hasLevel) {
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
                  style: sectionTitleStyle,
                ),
                const SizedBox(width: 6),
                const SectionHelpButton(
                  message:
                      'Sprites are game objects that combine animations and properties. They represent characters, items, or any animated entity placed in a level.',
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: CDKText(
                  'No level selected.\nSelect a Level to edit its sprites.',
                  role: CDKTextRole.body,
                  color: cdkColors.colorText.withValues(alpha: 0.62),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final level = appData.gameData.levels[appData.selectedLevel];
    final sprites = level.sprites;
    final List<GameAnimation> animations = _animations(appData);
    final bool hasAnimations = animations.isNotEmpty;

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
                style: sectionTitleStyle,
              ),
              const SizedBox(width: 6),
              const SectionHelpButton(
                message:
                    'Sprites are game objects that combine animations and properties. They represent characters, items, or any animated entity placed in a level.',
              ),
              const Spacer(),
              CDKButton(
                style: CDKButtonStyle.action,
                onPressed: hasAnimations
                    ? () async {
                        await _promptAndAddSprite(animations);
                      }
                    : null,
                child: const Text('+ Add Sprite'),
              ),
            ],
          ),
        ),
        Expanded(
          child: sprites.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: CDKText(
                    hasAnimations
                        ? '(No sprites defined)'
                        : 'Define at least one animation first.',
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
                        final String animationName = appData
                            .animationDisplayNameById(sprite.animationId);
                        final GameAnimation? animation =
                            _animationById(appData, sprite.animationId);
                        final String mediaName = animation == null
                            ? appData
                                .mediaDisplayNameByFileName(sprite.imageFile)
                            : appData.mediaDisplayNameByFileName(
                                animation.mediaFile,
                              );
                        final String subtitle =
                            '${sprite.x}, ${sprite.y} | Depth ${sprite.depth} - $animationName';
                        final String details =
                            '$mediaName | ${sprite.spriteWidth}x${sprite.spriteHeight} px | FlipX ${sprite.flipX ? 'on' : 'off'} | FlipY ${sprite.flipY ? 'on' : 'off'}';
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
                                        sprite.name,
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
                                if (isSelected && hasAnimations)
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
                                          animations,
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
    required this.name,
    required this.x,
    required this.y,
    required this.depth,
    required this.animationId,
    required this.width,
    required this.height,
    required this.imageFile,
    required this.flipX,
    required this.flipY,
  });

  final String name;
  final int x;
  final int y;
  final double depth;
  final String animationId;
  final int width;
  final int height;
  final String imageFile;
  final bool flipX;
  final bool flipY;
}

class _SpriteFormDialog extends StatefulWidget {
  const _SpriteFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialData,
    required this.animations,
    required this.resolveMediaByFileName,
    this.liveEdit = false,
    this.onLiveChanged,
    this.onClose,
    required this.onConfirm,
    required this.onCancel,
    this.onDelete,
  });

  final String title;
  final String confirmLabel;
  final _SpriteDialogData initialData;
  final List<GameAnimation> animations;
  final GameMediaAsset? Function(String fileName) resolveMediaByFileName;
  final bool liveEdit;
  final Future<void> Function(_SpriteDialogData value)? onLiveChanged;
  final VoidCallback? onClose;
  final ValueChanged<_SpriteDialogData> onConfirm;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  State<_SpriteFormDialog> createState() => _SpriteFormDialogState();
}

class _SpriteFormDialogState extends State<_SpriteFormDialog> {
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
  late int _selectedAnimationIndex = _resolveInitialAnimationIndex();
  late bool _flipX = widget.initialData.flipX;
  late bool _flipY = widget.initialData.flipY;
  EditSession<_SpriteDialogData>? _editSession;

  int _resolveInitialAnimationIndex() {
    final String currentAnimationId = widget.initialData.animationId;
    if (currentAnimationId.isNotEmpty) {
      final int found =
          widget.animations.indexWhere((a) => a.id == currentAnimationId);
      if (found != -1) {
        return found;
      }
    }
    final String currentImageFile = widget.initialData.imageFile;
    if (currentImageFile.isNotEmpty) {
      final int found =
          widget.animations.indexWhere((a) => a.mediaFile == currentImageFile);
      if (found != -1) {
        return found;
      }
    }
    return 0;
  }

  GameAnimation? get _selectedAnimation {
    if (widget.animations.isEmpty) {
      return null;
    }
    if (_selectedAnimationIndex < 0 ||
        _selectedAnimationIndex >= widget.animations.length) {
      _selectedAnimationIndex = 0;
    }
    return widget.animations[_selectedAnimationIndex];
  }

  GameMediaAsset? get _selectedMedia {
    final GameAnimation? animation = _selectedAnimation;
    if (animation == null) {
      return null;
    }
    return widget.resolveMediaByFileName(animation.mediaFile);
  }

  bool get _isValid {
    return _nameController.text.trim().isNotEmpty && _selectedAnimation != null;
  }

  double _parseDepth() {
    final String cleaned = _depthController.text.trim().replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  _SpriteDialogData _currentData() {
    final GameAnimation? animation = _selectedAnimation;
    final GameMediaAsset? media = _selectedMedia;
    return _SpriteDialogData(
      name: _nameController.text.trim(),
      x: int.tryParse(_xController.text.trim()) ?? 0,
      y: int.tryParse(_yController.text.trim()) ?? 0,
      depth: _parseDepth(),
      animationId: animation?.id ?? widget.initialData.animationId,
      width: media?.tileWidth ?? widget.initialData.width,
      height: media?.tileHeight ?? widget.initialData.height,
      imageFile: animation?.mediaFile ?? widget.initialData.imageFile,
      flipX: _flipX,
      flipY: _flipY,
    );
  }

  String? _validateData(_SpriteDialogData value) {
    if (value.name.trim().isEmpty) {
      return 'Sprite name is required.';
    }
    if (_selectedAnimation == null) {
      return 'Define at least one animation first.';
    }
    return null;
  }

  void _onInputChanged() {
    if (widget.liveEdit) {
      _editSession?.update(_currentData());
    }
  }

  void _confirm() {
    if (!_isValid) {
      return;
    }
    widget.onConfirm(_currentData());
  }

  @override
  void initState() {
    super.initState();
    if (widget.liveEdit && widget.onLiveChanged != null) {
      _editSession = EditSession<_SpriteDialogData>(
        initialValue: _currentData(),
        validate: _validateData,
        onPersist: widget.onLiveChanged!,
        areEqual: (a, b) =>
            a.name == b.name &&
            a.x == b.x &&
            a.y == b.y &&
            a.depth == b.depth &&
            a.animationId == b.animationId &&
            a.width == b.width &&
            a.height == b.height &&
            a.imageFile == b.imageFile &&
            a.flipX == b.flipX &&
            a.flipY == b.flipY,
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
    _xController.dispose();
    _yController.dispose();
    _depthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final GameAnimation? animation = _selectedAnimation;
    final GameMediaAsset? media = _selectedMedia;
    final List<String> animationOptions = widget.animations
        .map((a) => a.name.trim().isNotEmpty ? a.name : a.id)
        .toList(growable: false);

    return EditorFormDialogScaffold(
      title: widget.title,
      description: 'Configure sprite details.',
      confirmLabel: widget.confirmLabel,
      confirmEnabled: _isValid,
      onConfirm: _confirm,
      onCancel: widget.onCancel,
      liveEditMode: widget.liveEdit,
      onClose: widget.onClose,
      onDelete: widget.onDelete,
      minWidth: 380,
      maxWidth: 500,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorLabeledField(
            label: 'Sprite Name',
            child: CDKFieldText(
              placeholder: 'Sprite name',
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
          Row(
            children: [
              Expanded(
                child: EditorLabeledField(
                  label: 'Start X (px)',
                  child: CDKFieldText(
                    placeholder: 'Start X (px)',
                    controller: _xController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _onInputChanged(),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: EditorLabeledField(
                  label: 'Start Y (px)',
                  child: CDKFieldText(
                    placeholder: 'Start Y (px)',
                    controller: _yController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _onInputChanged(),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: EditorLabeledField(
                  label: 'Depth displacement',
                  child: CDKFieldText(
                    placeholder: 'Depth',
                    controller: _depthController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    onChanged: (_) => _onInputChanged(),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          EditorLabeledField(
            label: 'Animation',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (animationOptions.isNotEmpty)
                  CDKButtonSelect(
                    selectedIndex: _selectedAnimationIndex,
                    options: animationOptions,
                    onSelected: (int index) {
                      setState(() {
                        _selectedAnimationIndex = index;
                      });
                      _onInputChanged();
                    },
                  )
                else
                  const CDKText(
                    'No animations available',
                    role: CDKTextRole.caption,
                    secondary: true,
                  ),
                if (animation != null) ...[
                  const SizedBox(height: 4),
                  CDKText(
                    'Source: ${media?.name ?? animation.mediaFile}',
                    role: CDKTextRole.caption,
                    secondary: true,
                  ),
                  const SizedBox(height: 2),
                  CDKText(
                    'Frame size: ${(media?.tileWidth ?? widget.initialData.width)}×${(media?.tileHeight ?? widget.initialData.height)} px',
                    role: CDKTextRole.caption,
                    secondary: true,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CDKText(
                    'Flip X',
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
                        value: _flipX,
                        onChanged: (bool value) {
                          setState(() {
                            _flipX = value;
                          });
                          _onInputChanged();
                        },
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: spacing.md),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CDKText(
                    'Flip Y',
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
                        value: _flipY,
                        onChanged: (bool value) {
                          setState(() {
                            _flipY = value;
                          });
                          _onInputChanged();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
