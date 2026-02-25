import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_zone.dart';
import 'game_zone_type.dart';
import 'layout_utils.dart';

const List<String> _zoneTypeColorPalette = [
  'red',
  'deepOrange',
  'orange',
  'amber',
  'yellow',
  'lime',
  'lightGreen',
  'green',
  'teal',
  'cyan',
  'lightBlue',
  'blue',
  'indigo',
  'purple',
  'pink',
];

const GameZoneType _defaultZoneType = GameZoneType(
  name: 'Default',
  color: 'blue',
);

class LayoutZones extends StatefulWidget {
  const LayoutZones({super.key});

  @override
  LayoutZonesState createState() => LayoutZonesState();
}

class LayoutZonesState extends State<LayoutZones> {
  final ScrollController scrollController = ScrollController();
  final GlobalKey _selectedEditAnchorKey = GlobalKey();
  final GlobalKey _zoneTypesAnchorKey = GlobalKey();

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

  List<GameZoneType> _zoneTypes(AppData appData) {
    return appData.gameData.zoneTypes;
  }

  String _normalizeZoneTypeColor(String color) {
    if (_zoneTypeColorPalette.contains(color)) {
      return color;
    }
    return _defaultZoneType.color;
  }

  String _zoneColorForTypeName(AppData appData, String typeName) {
    for (final type in _zoneTypes(appData)) {
      if (type.name == typeName) {
        return type.color;
      }
    }
    return _defaultZoneType.color;
  }

  String _zoneColorName(AppData appData, GameZone zone) {
    final String fromType = _zoneColorForTypeName(appData, zone.type);
    if (fromType.isNotEmpty) {
      return fromType;
    }
    return _normalizeZoneTypeColor(zone.color);
  }

  Set<String> _usedZoneTypeNames(AppData appData) {
    final Set<String> used = {};
    for (final level in appData.gameData.levels) {
      for (final zone in level.zones) {
        final String typeName = zone.type.trim();
        if (typeName.isNotEmpty) {
          used.add(typeName);
        }
      }
    }
    return used;
  }

  void _applyZoneTypeDrafts(AppData appData, List<_ZoneTypeDraft> drafts) {
    final List<_ZoneTypeDraft> cleaned = [];
    final Set<String> seenNames = {};
    for (final draft in drafts) {
      final String trimmedName = draft.name.trim();
      if (trimmedName.isEmpty || seenNames.contains(trimmedName)) {
        continue;
      }
      cleaned.add(
        _ZoneTypeDraft(
          key: draft.key,
          name: trimmedName,
          color: _normalizeZoneTypeColor(draft.color),
        ),
      );
      seenNames.add(trimmedName);
    }

    final List<GameZoneType> nextTypes = cleaned
        .map(
          (draft) => GameZoneType(
            name: draft.name,
            color: draft.color,
          ),
        )
        .toList(growable: false);

    if (cleaned.isNotEmpty) {
      final Map<String, _ZoneTypeDraft> byKey = {
        for (final draft in cleaned) draft.key: draft
      };
      final Map<String, _ZoneTypeDraft> byName = {
        for (final draft in cleaned) draft.name: draft
      };
      final _ZoneTypeDraft fallback = cleaned.first;

      for (final level in appData.gameData.levels) {
        for (final zone in level.zones) {
          final _ZoneTypeDraft? renamedType = byKey[zone.type];
          if (renamedType != null) {
            zone.type = renamedType.name;
            zone.color = renamedType.color;
            continue;
          }
          final _ZoneTypeDraft? existingType = byName[zone.type];
          if (existingType != null) {
            zone.color = existingType.color;
            continue;
          }
          zone.type = fallback.name;
          zone.color = fallback.color;
        }
      }
    }

    appData.gameData.zoneTypes
      ..clear()
      ..addAll(nextTypes);
  }

  Future<void> _persistZoneTypeDrafts(
      AppData appData, List<_ZoneTypeDraft> drafts) async {
    appData.pushUndo();
    _applyZoneTypeDrafts(appData, drafts);
    appData.update();
    await _autoSaveIfPossible(appData);
  }

  Future<void> _showZoneTypesPopover(AppData appData) async {
    if (Overlay.maybeOf(context) == null) {
      return;
    }
    final CDKDialogController controller = CDKDialogController();

    final List<_ZoneTypeDraft> initialDrafts = _zoneTypes(appData)
        .map(
          (type) => _ZoneTypeDraft(
            key: type.name,
            name: type.name,
            color: _normalizeZoneTypeColor(type.color),
          ),
        )
        .toList(growable: false);

    CDKDialogsManager.showPopoverArrowed(
      context: context,
      anchorKey: _zoneTypesAnchorKey,
      isAnimated: true,
      animateContentResize: false,
      dismissOnEscape: true,
      dismissOnOutsideTap: true,
      showBackgroundShade: false,
      controller: controller,
      child: _ZoneTypesPopover(
        initialTypes: initialDrafts,
        colorPalette: _zoneTypeColorPalette,
        usedTypeKeys: _usedZoneTypeNames(appData),
        onTypesChanged: (nextDrafts) {
          unawaited(_persistZoneTypeDrafts(appData, nextDrafts));
        },
      ),
    );
  }

  void _addZone({
    required AppData appData,
    required _ZoneDialogData data,
  }) {
    if (appData.selectedLevel == -1) {
      return;
    }
    appData.gameData.levels[appData.selectedLevel].zones.add(
      GameZone(
        type: data.type,
        x: data.x,
        y: data.y,
        width: data.width,
        height: data.height,
        color: _zoneColorForTypeName(appData, data.type),
      ),
    );
    appData.selectedZone = -1;
    appData.update();
  }

  void _updateZone({
    required AppData appData,
    required int index,
    required _ZoneDialogData data,
  }) {
    if (appData.selectedLevel == -1) {
      return;
    }
    final zones = appData.gameData.levels[appData.selectedLevel].zones;
    if (index < 0 || index >= zones.length) {
      return;
    }
    zones[index] = GameZone(
      type: data.type,
      x: data.x,
      y: data.y,
      width: data.width,
      height: data.height,
      color: _zoneColorForTypeName(appData, data.type),
    );
    appData.selectedZone = index;
    appData.update();
  }

  Future<_ZoneDialogData?> _promptZoneData({
    required String title,
    required String confirmLabel,
    required _ZoneDialogData initialData,
    required List<GameZoneType> zoneTypes,
    GlobalKey? anchorKey,
    bool useArrowedPopover = false,
    VoidCallback? onDelete,
  }) async {
    if (Overlay.maybeOf(context) == null) {
      return null;
    }

    final CDKDialogController controller = CDKDialogController();
    final Completer<_ZoneDialogData?> completer = Completer<_ZoneDialogData?>();
    _ZoneDialogData? result;

    final dialogChild = _ZoneFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialData: initialData,
      zoneTypes: zoneTypes,
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

  Future<void> _promptAndAddZone() async {
    final appData = Provider.of<AppData>(context, listen: false);
    final List<GameZoneType> zoneTypes = _zoneTypes(appData);
    if (zoneTypes.isEmpty) {
      return;
    }
    final data = await _promptZoneData(
      title: "New zone",
      confirmLabel: "Add",
      initialData: _ZoneDialogData(
        type: zoneTypes.first.name,
        x: 0,
        y: 0,
        width: 50,
        height: 50,
      ),
      zoneTypes: zoneTypes,
    );
    if (!mounted || data == null) {
      return;
    }
    appData.pushUndo();
    _addZone(appData: appData, data: data);
    await _autoSaveIfPossible(appData);
  }

  Future<void> _confirmAndDeleteZone(int index) async {
    if (!mounted) return;
    final AppData appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1) return;
    final zones = appData.gameData.levels[appData.selectedLevel].zones;
    if (index < 0 || index >= zones.length) return;
    final String zoneName = zones[index].type;

    final bool? confirmed = await CDKDialogsManager.showConfirm(
      context: context,
      title: 'Delete zone',
      message: 'Delete "$zoneName"? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
      showBackgroundShade: true,
    );

    if (confirmed != true || !mounted) return;
    appData.pushUndo();
    zones.removeAt(index);
    appData.selectedZone = -1;
    appData.update();
    await _autoSaveIfPossible(appData);
  }

  Future<void> _promptAndEditZone(int index, GlobalKey anchorKey) async {
    final appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1) {
      return;
    }
    final zones = appData.gameData.levels[appData.selectedLevel].zones;
    final List<GameZoneType> zoneTypes = _zoneTypes(appData);
    if (index < 0 || index >= zones.length || zoneTypes.isEmpty) {
      return;
    }
    final zone = zones[index];
    final bool typeExists = zoneTypes.any((type) => type.name == zone.type);
    final data = await _promptZoneData(
      title: "Edit zone",
      confirmLabel: "Save",
      initialData: _ZoneDialogData(
        type: typeExists ? zone.type : zoneTypes.first.name,
        x: zone.x,
        y: zone.y,
        width: zone.width,
        height: zone.height,
      ),
      zoneTypes: zoneTypes,
      anchorKey: anchorKey,
      useArrowedPopover: true,
      onDelete: () => _confirmAndDeleteZone(index),
    );
    if (!mounted || data == null) {
      return;
    }
    appData.pushUndo();
    _updateZone(appData: appData, index: index, data: data);
    await _autoSaveIfPossible(appData);
  }

  void _selectZone(AppData appData, int index, bool isSelected) {
    if (isSelected) {
      appData.selectedZone = -1;
      appData.update();
      return;
    }
    appData.selectedZone = index;
    appData.update();
  }

  void selectZone(AppData appData, int index, bool isSelected) {
    _selectZone(appData, index, isSelected);
  }

  void _onReorder(AppData appData, int oldIndex, int newIndex) {
    if (appData.selectedLevel == -1) {
      return;
    }
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final zones = appData.gameData.levels[appData.selectedLevel].zones;
    final selectedIndex = appData.selectedZone;
    appData.pushUndo();
    final item = zones.removeAt(oldIndex);
    zones.insert(newIndex, item);

    if (selectedIndex == oldIndex) {
      appData.selectedZone = newIndex;
    } else if (selectedIndex > oldIndex && selectedIndex <= newIndex) {
      appData.selectedZone -= 1;
    } else if (selectedIndex < oldIndex && selectedIndex >= newIndex) {
      appData.selectedZone += 1;
    }

    appData.update();
    unawaited(_autoSaveIfPossible(appData));
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

    if (appData.selectedLevel == -1) {
      return const Center(
        child: CDKText(
          'Select a level to edit zones.',
          role: CDKTextRole.body,
          secondary: true,
        ),
      );
    }

    final level = appData.gameData.levels[appData.selectedLevel];
    final zones = level.zones;
    final zoneTypes = _zoneTypes(appData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Row(
            children: [
              const CDKText(
                'Zones',
                role: CDKTextRole.title,
              ),
              const Spacer(),
              CDKButton(
                key: _zoneTypesAnchorKey,
                style: CDKButtonStyle.normal,
                onPressed: () async {
                  await _showZoneTypesPopover(appData);
                },
                child: const Text('Edit types'),
              ),
              const SizedBox(width: 8),
              CDKButton(
                style: CDKButtonStyle.action,
                onPressed: zoneTypes.isEmpty
                    ? null
                    : () async {
                        await _promptAndAddZone();
                      },
                child: const Text('+ Add Zone'),
              ),
            ],
          ),
        ),
        Expanded(
          child: zones.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: CDKText(
                    '(No zones defined)',
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
                      itemCount: zones.length,
                      onReorder: (oldIndex, newIndex) =>
                          _onReorder(appData, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final isSelected = (index == appData.selectedZone);
                        final zone = zones[index];
                        final String zoneColorName =
                            _zoneColorName(appData, zone);
                        return GestureDetector(
                          key: ValueKey(zone),
                          onTap: () => _selectZone(appData, index, isSelected),
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
                                Container(
                                  width: 15,
                                  height: 15,
                                  decoration: BoxDecoration(
                                    color: LayoutUtils.getColorFromName(
                                      zoneColorName,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CDKText(
                                        zone.type,
                                        role: isSelected
                                            ? CDKTextRole.bodyStrong
                                            : CDKTextRole.body,
                                        style: listItemTitleStyle,
                                      ),
                                      const SizedBox(height: 2),
                                      CDKText(
                                        'x: ${zone.x}, y: ${zone.y}',
                                        role: CDKTextRole.body,
                                        color: cdkColors.colorText,
                                      ),
                                      const SizedBox(height: 2),
                                      CDKText(
                                        'width: ${zone.width}, height: ${zone.height}',
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
                                        await _promptAndEditZone(
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

class _ZoneDialogData {
  const _ZoneDialogData({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String type;
  final int x;
  final int y;
  final int width;
  final int height;
}

class _ZoneFormDialog extends StatefulWidget {
  const _ZoneFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialData,
    required this.zoneTypes,
    required this.onConfirm,
    required this.onCancel,
    this.onDelete,
  });

  final String title;
  final String confirmLabel;
  final _ZoneDialogData initialData;
  final List<GameZoneType> zoneTypes;
  final ValueChanged<_ZoneDialogData> onConfirm;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  State<_ZoneFormDialog> createState() => _ZoneFormDialogState();
}

class _ZoneFormDialogState extends State<_ZoneFormDialog> {
  final GlobalKey _typePickerAnchorKey = GlobalKey();
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
  late String _selectedType = _resolveInitialType();

  String _resolveInitialType() {
    if (widget.zoneTypes.any((type) => type.name == widget.initialData.type)) {
      return widget.initialData.type;
    }
    if (widget.zoneTypes.isNotEmpty) {
      return widget.zoneTypes.first.name;
    }
    return '';
  }

  bool get _isValid =>
      _selectedType.trim().isNotEmpty && widget.zoneTypes.isNotEmpty;

  GameZoneType? _selectedZoneType() {
    for (final type in widget.zoneTypes) {
      if (type.name == _selectedType) {
        return type;
      }
    }
    return null;
  }

  Future<void> _showTypePickerPopover() async {
    if (widget.zoneTypes.isEmpty || Overlay.maybeOf(context) == null) {
      return;
    }
    final CDKDialogController controller = CDKDialogController();
    CDKDialogsManager.showPopoverArrowed(
      context: context,
      anchorKey: _typePickerAnchorKey,
      isAnimated: true,
      animateContentResize: false,
      dismissOnEscape: true,
      dismissOnOutsideTap: true,
      showBackgroundShade: false,
      controller: controller,
      child: _ZoneTypePickerPopover(
        zoneTypes: widget.zoneTypes,
        selectedType: _selectedType,
        onSelected: (typeName) {
          setState(() {
            _selectedType = typeName;
          });
          controller.close();
        },
      ),
    );
  }

  void _confirm() {
    if (!_isValid) {
      return;
    }
    widget.onConfirm(
      _ZoneDialogData(
        type: _selectedType,
        x: int.tryParse(_xController.text.trim()) ?? 0,
        y: int.tryParse(_yController.text.trim()) ?? 0,
        width: int.tryParse(_widthController.text.trim()) ?? 50,
        height: int.tryParse(_heightController.text.trim()) ?? 50,
      ),
    );
  }

  @override
  void dispose() {
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
    final GameZoneType? selectedType = _selectedZoneType();
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

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 500),
        child: Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CDKText(widget.title, role: CDKTextRole.title),
              SizedBox(height: spacing.md),
              const CDKText('Configure zone details.', role: CDKTextRole.body),
              SizedBox(height: spacing.md),
              CDKText(
                'Zone Type',
                role: CDKTextRole.caption,
                color: cdkColors.colorText,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: CDKButton(
                  key: _typePickerAnchorKey,
                  style: CDKButtonStyle.normal,
                  enabled: widget.zoneTypes.isNotEmpty,
                  onPressed: _showTypePickerPopover,
                  child: Row(
                    children: [
                      if (selectedType != null) ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: LayoutUtils.getColorFromName(
                              selectedType.color,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            selectedType?.name ?? 'Select a type',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.chevron_down,
                        size: 14,
                        color: cdkColors.colorText,
                      ),
                    ],
                  ),
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
                ],
              ),
              SizedBox(height: spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: labeledField(
                      'Width (px)',
                      CDKFieldText(
                        placeholder: 'Width (px)',
                        controller: _widthController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: labeledField(
                      'Height (px)',
                      CDKFieldText(
                        placeholder: 'Height (px)',
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                      ),
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

class _ZoneTypePickerPopover extends StatelessWidget {
  const _ZoneTypePickerPopover({
    required this.zoneTypes,
    required this.selectedType,
    required this.onSelected,
  });

  final List<GameZoneType> zoneTypes;
  final String selectedType;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: Padding(
        padding: EdgeInsets.all(spacing.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: zoneTypes.length,
            itemBuilder: (context, index) {
              final type = zoneTypes[index];
              final bool isSelected = type.name == selectedType;
              return GestureDetector(
                onTap: () => onSelected(type.name),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  color: isSelected
                      ? CupertinoColors.systemBlue.withValues(alpha: 0.18)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: LayoutUtils.getColorFromName(type.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CDKText(
                          type.name,
                          role: isSelected
                              ? CDKTextRole.bodyStrong
                              : CDKTextRole.body,
                          color: cdkColors.colorText,
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
    );
  }
}

class _ZoneTypeDraft {
  const _ZoneTypeDraft({
    required this.key,
    required this.name,
    required this.color,
  });

  final String key;
  final String name;
  final String color;

  _ZoneTypeDraft copyWith({
    String? key,
    String? name,
    String? color,
  }) {
    return _ZoneTypeDraft(
      key: key ?? this.key,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}

class _ZoneTypesPopover extends StatefulWidget {
  const _ZoneTypesPopover({
    required this.initialTypes,
    required this.colorPalette,
    required this.usedTypeKeys,
    required this.onTypesChanged,
  });

  final List<_ZoneTypeDraft> initialTypes;
  final List<String> colorPalette;
  final Set<String> usedTypeKeys;
  final ValueChanged<List<_ZoneTypeDraft>> onTypesChanged;

  @override
  State<_ZoneTypesPopover> createState() => _ZoneTypesPopoverState();
}

class _ZoneTypesPopoverState extends State<_ZoneTypesPopover> {
  late final List<_ZoneTypeDraft> _drafts =
      widget.initialTypes.map((item) => item.copyWith()).toList(growable: true);
  final GlobalKey<AnimatedListState> _typesListKey =
      GlobalKey<AnimatedListState>();
  static const Duration _rowAnimationDuration = Duration(milliseconds: 220);
  int _selectedIndex = -1;
  int _newKeyCounter = 0;
  late final TextEditingController _nameController = TextEditingController();
  late String _selectedColor = widget.colorPalette.first;
  String? _nameError;

  Widget _buildDraftRow({
    required BuildContext context,
    required int index,
    required _ZoneTypeDraft draft,
    Animation<double>? animation,
  }) {
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final bool selected = index == _selectedIndex;
    final Widget row = GestureDetector(
      onTap: () => _selectIndex(index),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 6,
          horizontal: 8,
        ),
        color: selected
            ? CupertinoColors.systemBlue.withValues(alpha: 0.18)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: LayoutUtils.getColorFromName(draft.color),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CDKText(
                draft.name,
                role: selected ? CDKTextRole.bodyStrong : CDKTextRole.body,
                color: cdkColors.colorText,
              ),
            ),
          ],
        ),
      ),
    );

    if (animation == null) {
      return row;
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SizeTransition(
      sizeFactor: curved,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: curved,
        child: row,
      ),
    );
  }

  void _selectIndex(int index) {
    if (index < 0 || index >= _drafts.length) {
      return;
    }
    setState(() {
      if (_selectedIndex == index) {
        _selectedIndex = -1;
        _nameController.clear();
        _selectedColor = widget.colorPalette.first;
      } else {
        _selectedIndex = index;
        _nameController.text = _drafts[index].name;
        _selectedColor = _drafts[index].color;
      }
      _nameError = null;
    });
  }

  void _emitChanged() {
    widget.onTypesChanged(
      _drafts.map((item) => item.copyWith()).toList(growable: false),
    );
  }

  bool _isNameDuplicated(String name, {required int excludingIndex}) {
    for (int i = 0; i < _drafts.length; i++) {
      if (i == excludingIndex) continue;
      if (_drafts[i].name.trim() == name) {
        return true;
      }
    }
    return false;
  }

  void _upsertDraft() {
    final String nextName = _nameController.text.trim();
    if (nextName.isEmpty) {
      setState(() {
        _nameError = 'Type name is required.';
      });
      return;
    }
    if (_isNameDuplicated(nextName, excludingIndex: _selectedIndex)) {
      setState(() {
        _nameError = 'A type with this name already exists.';
      });
      return;
    }

    setState(() {
      if (_selectedIndex >= 0 && _selectedIndex < _drafts.length) {
        _drafts[_selectedIndex] = _drafts[_selectedIndex].copyWith(
          name: nextName,
          color: _selectedColor,
        );
      } else {
        final int insertIndex = _drafts.length;
        _drafts.add(
          _ZoneTypeDraft(
            key: '__new_${_newKeyCounter++}',
            name: nextName,
            color: _selectedColor,
          ),
        );
        _typesListKey.currentState?.insertItem(
          insertIndex,
          duration: _rowAnimationDuration,
        );
        _selectedIndex = -1;
        _nameController.clear();
        _selectedColor = widget.colorPalette.first;
      }
      _nameError = null;
    });
    _emitChanged();
  }

  void _deleteSelected() {
    if (_selectedIndex < 0 || _selectedIndex >= _drafts.length) {
      return;
    }
    final int removedIndex = _selectedIndex;
    final _ZoneTypeDraft removedDraft = _drafts[removedIndex];
    setState(() {
      _drafts.removeAt(removedIndex);
      _selectedIndex = -1;
      _nameController.clear();
      _selectedColor = widget.colorPalette.first;
      _nameError = null;
    });
    _typesListKey.currentState?.removeItem(
      removedIndex,
      (context, animation) => _buildDraftRow(
        context: context,
        index: removedIndex,
        draft: removedDraft,
        animation: animation,
      ),
      duration: _rowAnimationDuration,
    );
    _emitChanged();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final bool hasSelection =
        _selectedIndex >= 0 && _selectedIndex < _drafts.length;
    final bool selectedTypeIsUsed = hasSelection &&
        widget.usedTypeKeys.contains(_drafts[_selectedIndex].key);
    final bool canDelete = hasSelection && !selectedTypeIsUsed;
    final bool isUpdateMode = hasSelection;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420, maxWidth: 460),
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CDKText('Zone Types', role: CDKTextRole.title),
              SizedBox(height: spacing.sm),
              if (_drafts.isEmpty)
                const CDKText(
                  'No zone types yet. Create one below.',
                  role: CDKTextRole.caption,
                  secondary: true,
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: AnimatedList(
                  key: _typesListKey,
                  shrinkWrap: true,
                  initialItemCount: _drafts.length,
                  itemBuilder: (context, index, animation) {
                    final _ZoneTypeDraft draft = _drafts[index];
                    return _buildDraftRow(
                      context: context,
                      index: index,
                      draft: draft,
                      animation: animation,
                    );
                  },
                ),
              ),
              SizedBox(height: spacing.md),
              CDKText(
                'Name',
                role: CDKTextRole.caption,
                color: cdkColors.colorText,
              ),
              const SizedBox(height: 4),
              CDKFieldText(
                placeholder: 'Type name',
                controller: _nameController,
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() {
                      _nameError = null;
                    });
                  }
                },
                onSubmitted: (_) => _upsertDraft(),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 18,
                child: _nameError == null
                    ? const SizedBox.shrink()
                    : CDKText(
                        _nameError!,
                        role: CDKTextRole.caption,
                        color: CDKTheme.red,
                      ),
              ),
              SizedBox(height: spacing.sm),
              CDKText(
                'Color',
                role: CDKTextRole.caption,
                color: cdkColors.colorText,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: spacing.xs,
                runSpacing: spacing.xs,
                children: widget.colorPalette.map((colorName) {
                  return _ZoneTypeColorSwatch(
                    color: LayoutUtils.getColorFromName(colorName),
                    selected: _selectedColor == colorName,
                    onTap: () {
                      setState(() {
                        _selectedColor = colorName;
                      });
                    },
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 18,
                child: selectedTypeIsUsed
                    ? const CDKText(
                        'Type is in use and cannot be deleted.',
                        role: CDKTextRole.caption,
                        secondary: true,
                      )
                    : const SizedBox.shrink(),
              ),
              SizedBox(height: spacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CDKButton(
                    style: CDKButtonStyle.normal,
                    enabled: canDelete,
                    onPressed: _deleteSelected,
                    child: const Text('Delete type'),
                  ),
                  CDKButton(
                    style: CDKButtonStyle.action,
                    onPressed: _upsertDraft,
                    child: Text(isUpdateMode ? 'Update' : 'Add type'),
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

class _ZoneTypeColorSwatch extends StatelessWidget {
  const _ZoneTypeColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    const double swatchSize = 20;
    const double selectionGap = 1.5;
    const double selectionStroke = 2;
    const double slotSize = swatchSize + (selectionGap + selectionStroke) * 2;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: slotSize,
        height: slotSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (selected)
              Container(
                width: slotSize,
                height: slotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cdkColors.accent,
                    width: selectionStroke,
                  ),
                ),
              ),
            Container(
              width: swatchSize,
              height: swatchSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: CupertinoColors.systemGrey.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
