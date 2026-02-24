import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_zone.dart';
import 'layout_utils.dart';

class LayoutZones extends StatefulWidget {
  const LayoutZones({super.key});

  @override
  LayoutZonesState createState() => LayoutZonesState();
}

class LayoutZonesState extends State<LayoutZones> {
  final ScrollController scrollController = ScrollController();
  final GlobalKey _selectedEditAnchorKey = GlobalKey();

  final List<String> colors = [
    'blue',
    'green',
    'yellow',
    'orange',
    'red',
    'purple',
    'grey',
    'black',
  ];

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
        color: data.color,
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
      color: data.color,
    );
    appData.selectedZone = index;
    appData.update();
  }

  Future<_ZoneDialogData?> _promptZoneData({
    required String title,
    required String confirmLabel,
    required _ZoneDialogData initialData,
    GlobalKey? anchorKey,
    bool useArrowedPopover = false,
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
      colors: colors,
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
    final data = await _promptZoneData(
      title: "New zone",
      confirmLabel: "Add",
      initialData: const _ZoneDialogData(
        type: '',
        x: 0,
        y: 0,
        width: 0,
        height: 0,
        color: 'blue',
      ),
    );
    if (!mounted || data == null) {
      return;
    }
    final appData = Provider.of<AppData>(context, listen: false);
    _addZone(appData: appData, data: data);
    await _autoSaveIfPossible(appData);
  }

  Future<void> _promptAndEditZone(int index, GlobalKey anchorKey) async {
    final appData = Provider.of<AppData>(context, listen: false);
    if (appData.selectedLevel == -1) {
      return;
    }
    final zones = appData.gameData.levels[appData.selectedLevel].zones;
    if (index < 0 || index >= zones.length) {
      return;
    }
    final zone = zones[index];
    final data = await _promptZoneData(
      title: "Edit zone",
      confirmLabel: "Save",
      initialData: _ZoneDialogData(
        type: zone.type,
        x: zone.x,
        y: zone.y,
        width: zone.width,
        height: zone.height,
        color: zone.color,
      ),
      anchorKey: anchorKey,
      useArrowedPopover: true,
    );
    if (!mounted || data == null) {
      return;
    }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Row(
            children: [
              CDKText(
                'Zones',
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
                  await _promptAndAddZone();
                },
                child: const Text('+ Add Zone'),
              ),
            ],
          ),
        ),
        Expanded(
          child: zones.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: const CDKText(
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
                                      zone.color,
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
                                        style: TextStyle(
                                          fontSize: isSelected ? 17 : 16,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      CDKText(
                                        'x: ${zone.x}, y: ${zone.y}',
                                        role: CDKTextRole.caption,
                                        color: cdkColors.colorText,
                                      ),
                                      const SizedBox(height: 2),
                                      CDKText(
                                        'width: ${zone.width}, height: ${zone.height}',
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
    required this.color,
  });

  final String type;
  final int x;
  final int y;
  final int width;
  final int height;
  final String color;
}

class _ZoneFormDialog extends StatefulWidget {
  const _ZoneFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialData,
    required this.colors,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final String confirmLabel;
  final _ZoneDialogData initialData;
  final List<String> colors;
  final ValueChanged<_ZoneDialogData> onConfirm;
  final VoidCallback onCancel;

  @override
  State<_ZoneFormDialog> createState() => _ZoneFormDialogState();
}

class _ZoneFormDialogState extends State<_ZoneFormDialog> {
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
  late String _selectedColor = widget.initialData.color;

  bool get _isValid => _typeController.text.trim().isNotEmpty;

  void _confirm() {
    final String type = _typeController.text.trim();
    if (type.isEmpty) {
      return;
    }
    widget.onConfirm(
      _ZoneDialogData(
        type: type,
        x: int.tryParse(_xController.text.trim()) ?? 0,
        y: int.tryParse(_yController.text.trim()) ?? 0,
        width: int.tryParse(_widthController.text.trim()) ?? 0,
        height: int.tryParse(_heightController.text.trim()) ?? 0,
        color: _selectedColor,
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

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 460),
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
              labeledField(
                'Zone Type',
                CDKFieldText(
                  placeholder: 'Zone type',
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
              SizedBox(height: spacing.md),
              CDKText(
                'Zone Color',
                role: CDKTextRole.caption,
                color: cdkColors.colorText,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: spacing.sm,
                children: widget.colors.map((colorName) {
                  return CupertinoButton(
                    padding: const EdgeInsets.all(2),
                    minimumSize: Size.zero,
                    onPressed: () {
                      setState(() {
                        _selectedColor = colorName;
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: LayoutUtils.getColorFromName(colorName),
                          width: 4,
                        ),
                        color: _selectedColor == colorName
                            ? LayoutUtils.getColorFromName(colorName)
                            : cdkColors.background,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }).toList(growable: false),
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
