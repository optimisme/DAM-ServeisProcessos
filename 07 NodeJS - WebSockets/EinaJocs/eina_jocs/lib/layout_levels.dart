import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_level.dart';
import 'widgets/edit_session.dart';
import 'widgets/editor_form_dialog_scaffold.dart';
import 'widgets/editor_labeled_field.dart';

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
    appData.queueAutosave();
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
    bool liveEdit = false,
    Future<void> Function(_LevelDialogData value)? onLiveChanged,
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

    final bool? confirmed = await CDKDialogsManager.showConfirm(
      context: context,
      title: 'Delete level',
      message: 'Delete "$levelName"? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
      showBackgroundShade: true,
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
    final String undoGroupKey =
        'level-live-$index-${DateTime.now().microsecondsSinceEpoch}';
    await _promptLevelData(
      title: "Edit level",
      confirmLabel: "Save",
      initialName: selected.name,
      initialDescription: selected.description,
      editingIndex: index,
      anchorKey: anchorKey,
      useArrowedPopover: true,
      liveEdit: true,
      onLiveChanged: (value) async {
        await appData.runProjectMutation(
          debugLabel: 'level-live-edit',
          undoGroupKey: undoGroupKey,
          mutate: () {
            _updateLevel(
              appData: appData,
              index: index,
              name: value.name,
              description: value.description,
            );
          },
        );
      },
      onDelete: () => _confirmAndDeleteLevel(index),
    );
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
    final TextStyle sectionTitleStyle = typography.title.copyWith(
      fontSize: (typography.title.fontSize ?? 17) + 2,
    );
    final TextStyle listItemTitleStyle = typography.body.copyWith(
      fontSize: (typography.body.fontSize ?? 14) + 2,
      fontWeight: FontWeight.w700,
    );
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
                style: sectionTitleStyle,
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
                                          style: listItemTitleStyle,
                                        ),
                                        const SizedBox(height: 2),
                                        CDKText(
                                          levels[index].description,
                                          role: CDKTextRole.body,
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
    this.liveEdit = false,
    this.onLiveChanged,
    this.onClose,
    required this.onConfirm,
    required this.onCancel,
    this.onDelete,
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final String initialDescription;
  final Set<String> existingNames;
  final bool liveEdit;
  final Future<void> Function(_LevelDialogData value)? onLiveChanged;
  final VoidCallback? onClose;
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
  EditSession<_LevelDialogData>? _editSession;

  _LevelDialogData _currentData() {
    return _LevelDialogData(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
    );
  }

  String? _validateData(_LevelDialogData data) {
    final String cleaned = data.name.trim();
    if (cleaned.isEmpty) {
      return 'Name is required.';
    }
    if (widget.existingNames.contains(cleaned.toLowerCase())) {
      return 'Another level is named like that.';
    }
    return null;
  }

  bool get _isValid {
    return _validateData(_currentData()) == null;
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

  void _onInputChanged() {
    if (widget.liveEdit) {
      _editSession?.update(_currentData());
    }
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
    if (widget.liveEdit && widget.onLiveChanged != null) {
      _editSession = EditSession<_LevelDialogData>(
        initialValue: _currentData(),
        validate: _validateData,
        onPersist: widget.onLiveChanged!,
        areEqual: (a, b) => a.name == b.name && a.description == b.description,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _nameFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    if (_editSession != null) {
      unawaited(_editSession!.flush());
      _editSession!.dispose();
    }
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    return EditorFormDialogScaffold(
      title: widget.title,
      description: 'Enter level details.',
      confirmLabel: widget.confirmLabel,
      confirmEnabled: _isValid,
      onConfirm: _confirm,
      onCancel: widget.onCancel,
      liveEditMode: widget.liveEdit,
      onClose: widget.onClose,
      onDelete: widget.onDelete,
      minWidth: 320,
      maxWidth: 420,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorLabeledField(
            label: 'Name',
            child: CDKFieldText(
              placeholder: 'Level name',
              controller: _nameController,
              focusNode: _nameFocusNode,
              onChanged: (value) {
                _validate(value);
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
            label: 'Description',
            child: CDKFieldText(
              placeholder: 'Level description (optional)',
              controller: _descriptionController,
              onChanged: (_) => _onInputChanged(),
              onSubmitted: (_) {
                if (widget.liveEdit) {
                  _onInputChanged();
                  return;
                }
                _confirm();
              },
            ),
          ),
          if (_errorText != null) ...[
            SizedBox(height: spacing.sm),
            Text(
              _errorText!,
              style: typography.caption.copyWith(color: CDKTheme.red),
            ),
          ],
        ],
      ),
    );
  }
}
