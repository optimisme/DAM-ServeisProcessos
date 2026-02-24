import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_level.dart';

class LayoutLevels extends StatefulWidget {
  const LayoutLevels({super.key});

  @override
  LayoutLevelsState createState() => LayoutLevelsState();
}

class LayoutLevelsState extends State<LayoutLevels> {
  final ScrollController scrollController = ScrollController();
  final GlobalKey _selectedEditAnchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _autoSaveIfPossible(AppData appData) async {
    if (appData.selectedProject == null) {
      return;
    }
    await appData.saveGame();
  }

  void _addLevel({
    required AppData appData,
    required String name,
    required String description,
  }) {
    final newLevel = GameLevel(
      name: name,
      description: description,
      layers: [],
      zones: [],
      sprites: [],
    );

    appData.gameData.levels.add(newLevel);
    appData.selectedLevel = -1;
    appData.update();
  }

  Future<_LevelDialogData?> _promptLevelData({
    required String title,
    required String confirmLabel,
    String initialName = "",
    String initialDescription = "",
    int? editingIndex,
    GlobalKey? anchorKey,
    bool useArrowedPopover = false,
    VoidCallback? onDelete,
  }) async {
    if (Overlay.maybeOf(context) == null) {
      return null;
    }

    final appData = Provider.of<AppData>(context, listen: false);
    final Set<String> existingNames = appData.gameData.levels
        .asMap()
        .entries
        .where((entry) => entry.key != editingIndex)
        .map((entry) => entry.value)
        .map((level) => level.name.trim().toLowerCase())
        .toSet();
    final CDKDialogController controller = CDKDialogController();
    final Completer<_LevelDialogData?> completer =
        Completer<_LevelDialogData?>();
    _LevelDialogData? result;

    final dialogChild = _LevelFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
      initialDescription: initialDescription,
      existingNames: existingNames,
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

  Future<void> _promptAndAddLevel() async {
    final _LevelDialogData? levelData = await _promptLevelData(
      title: "New level",
      confirmLabel: "Add",
    );
    if (levelData == null || !mounted) {
      return;
    }
    final appData = Provider.of<AppData>(context, listen: false);
    appData.pushUndo();
    _addLevel(
      appData: appData,
      name: levelData.name,
      description: levelData.description,
    );
    await _autoSaveIfPossible(appData);
  }

  Future<void> _confirmAndDeleteLevel(int index) async {
    if (!mounted) return;
    final AppData appData = Provider.of<AppData>(context, listen: false);
    if (index < 0 || index >= appData.gameData.levels.length) return;
    final String levelName = appData.gameData.levels[index].name;

    final bool? confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete level'),
        content: Text('Delete "$levelName"? This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    appData.pushUndo();
    appData.gameData.levels.removeAt(index);
    appData.selectedLevel = -1;
    appData.selectedLayer = -1;
    appData.selectedZone = -1;
    appData.selectedSprite = -1;
    appData.update();
    await _autoSaveIfPossible(appData);
  }

  Future<void> _promptAndEditLevel(int index, GlobalKey anchorKey) async {
    final appData = Provider.of<AppData>(context, listen: false);
    if (index < 0 || index >= appData.gameData.levels.length) {
      return;
    }
    final GameLevel selected = appData.gameData.levels[index];
    final _LevelDialogData? updated = await _promptLevelData(
      title: "Edit level",
      confirmLabel: "Save",
      initialName: selected.name,
      initialDescription: selected.description,
      editingIndex: index,
      anchorKey: anchorKey,
      useArrowedPopover: true,
      onDelete: () => _confirmAndDeleteLevel(index),
    );
    if (updated == null || !mounted) {
      return;
    }
    appData.pushUndo();
    _updateLevel(
      appData: appData,
      index: index,
      name: updated.name,
      description: updated.description,
    );
    await _autoSaveIfPossible(appData);
  }

  void _updateLevel({
    required AppData appData,
    required int index,
    required String name,
    required String description,
  }) {
    if (index >= 0 && index < appData.gameData.levels.length) {
      final previous = appData.gameData.levels[index];
      appData.gameData.levels[index] = GameLevel(
        name: name,
        description: description,
        layers: previous.layers,
        zones: previous.zones,
        sprites: previous.sprites,
      );
      appData.selectedLevel = index;
      appData.update();
    }
  }

  void _selectLevel(AppData appData, int index, bool isSelected) {
    if (isSelected) {
      appData.selectedLevel = -1;
      appData.selectedLayer = -1;
      appData.selectedZone = -1;
      appData.selectedSprite = -1;
      appData.update();
      return;
    }
    appData.selectedLevel = index;
    appData.selectedLayer = -1;
    appData.selectedZone = -1;
    appData.selectedSprite = -1;
    appData.update();
  }

  void _onReorder(AppData appData, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final levels = appData.gameData.levels;
    final int selectedIndex = appData.selectedLevel;

    appData.pushUndo();
    final item = levels.removeAt(oldIndex);
    levels.insert(newIndex, item);

    if (selectedIndex == oldIndex) {
      appData.selectedLevel = newIndex;
    } else if (selectedIndex > oldIndex && selectedIndex <= newIndex) {
      appData.selectedLevel -= 1;
    } else if (selectedIndex < oldIndex && selectedIndex >= newIndex) {
      appData.selectedLevel += 1;
    } else {
      appData.selectedLevel = selectedIndex;
    }

    appData.update();
    unawaited(_autoSaveIfPossible(appData));

    if (kDebugMode) {
      print(
          "Updated level order: ${appData.gameData.levels.map((level) => level.name).join(', ')}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    final levels = appData.gameData.levels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Row(
            children: [
              CDKText(
                'Game Levels',
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
                  await _promptAndAddLevel();
                },
                child: const Text('+ Add Level'),
              ),
            ],
          ),
        ),
        Expanded(
            child: levels.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: const CDKText(
                      '(No levels defined)',
                      role: CDKTextRole.caption,
                      secondary: true,
                    ),
                  )
                : CupertinoScrollbar(
                    controller: scrollController,
                    child: Localizations.override(
                      context: context,
                      delegates: [
                        DefaultMaterialLocalizations
                            .delegate, // Add Material Localizations
                        DefaultWidgetsLocalizations.delegate,
                      ],
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: levels.length,
                        onReorder: (oldIndex, newIndex) =>
                            _onReorder(appData, oldIndex, newIndex),
                        itemBuilder: (context, index) {
                          final isSelected = (index == appData.selectedLevel);
                          return GestureDetector(
                            key: ValueKey(levels[index]), // Reorder value key
                            onTap: () {
                              _selectLevel(appData, index, isSelected);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
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
                                          levels[index].name,
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
                                          levels[index].description,
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
                                          await _promptAndEditLevel(
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
                  )),
      ],
    );
  }
}

class _LevelDialogData {
  const _LevelDialogData({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;
}

class _LevelFormDialog extends StatefulWidget {
  const _LevelFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
    required this.initialDescription,
    required this.existingNames,
    required this.onConfirm,
    required this.onCancel,
    this.onDelete,
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final String initialDescription;
  final Set<String> existingNames;
  final ValueChanged<_LevelDialogData> onConfirm;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  State<_LevelFormDialog> createState() => _LevelFormDialogState();
}

class _LevelFormDialogState extends State<_LevelFormDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.initialDescription);
  final FocusNode _nameFocusNode = FocusNode();
  String? _errorText;

  bool get _isValid {
    final String cleaned = _nameController.text.trim();
    return cleaned.isNotEmpty &&
        !widget.existingNames.contains(cleaned.toLowerCase());
  }

  void _validate(String value) {
    final String cleaned = value.trim();
    final String? error;
    if (cleaned.isNotEmpty &&
        widget.existingNames.contains(cleaned.toLowerCase())) {
      error = "Another level is named like that.";
    } else {
      error = null;
    }
    setState(() {
      _errorText = error;
    });
  }

  void _confirm() {
    final String cleanedName = _nameController.text.trim();
    _validate(cleanedName);
    if (cleanedName.isEmpty ||
        widget.existingNames.contains(cleanedName.toLowerCase())) {
      return;
    }
    widget.onConfirm(
      _LevelDialogData(
        name: cleanedName,
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _nameFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CDKText(widget.title, role: CDKTextRole.title),
              SizedBox(height: spacing.md),
              const CDKText("Enter level details.", role: CDKTextRole.body),
              SizedBox(height: spacing.md),
              CDKText(
                "Name",
                role: CDKTextRole.caption,
                color: cdkColors.colorText,
              ),
              const SizedBox(height: 4),
              CDKFieldText(
                placeholder: "Level name",
                controller: _nameController,
                focusNode: _nameFocusNode,
                onChanged: _validate,
                onSubmitted: (_) => _confirm(),
              ),
              SizedBox(height: spacing.sm),
              CDKText(
                "Description",
                role: CDKTextRole.caption,
                color: cdkColors.colorText,
              ),
              const SizedBox(height: 4),
              CDKFieldText(
                placeholder: "Level description (optional)",
                controller: _descriptionController,
                onSubmitted: (_) => _confirm(),
              ),
              if (_errorText != null) ...[
                SizedBox(height: spacing.sm),
                Text(
                  _errorText!,
                  style: typography.caption.copyWith(color: CDKTheme.red),
                ),
              ],
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
                        child: const Text("Cancel"),
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
