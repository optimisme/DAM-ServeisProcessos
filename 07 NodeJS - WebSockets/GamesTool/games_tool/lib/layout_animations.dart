import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_animation.dart';
import 'game_list_group.dart';
import 'game_media_asset.dart';
import 'layout_utils.dart';
import 'widgets/edit_session.dart';
import 'widgets/editor_form_dialog_scaffold.dart';
import 'widgets/editor_labeled_field.dart';
import 'widgets/grouped_list.dart';
import 'widgets/section_help_button.dart';

class LayoutAnimations extends StatefulWidget {
  const LayoutAnimations({super.key});

  @override
  State<LayoutAnimations> createState() => _LayoutAnimationsState();
}

class _LayoutAnimationsState extends State<LayoutAnimations> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _selectedEditAnchorKey = GlobalKey();
  final GlobalKey _animationGroupsAnchorKey = GlobalKey();
  int _newGroupCounter = 0;
  Timer? _previewTimer;
  DateTime? _previewLastTick;
  String _previewAnimationId = '';
  double _previewElapsedSeconds = 0.0;
  bool _previewPlaying = false;

  @override
  void dispose() {
    _previewTimer?.cancel();
    _previewTimer = null;
    super.dispose();
  }

  void _setPreviewPlaying(bool nextPlaying) {
    if (_previewPlaying == nextPlaying) {
      return;
    }
    _previewPlaying = nextPlaying;
    if (!_previewPlaying) {
      _previewLastTick = null;
      _previewTimer?.cancel();
      _previewTimer = null;
      return;
    }
    _previewLastTick = DateTime.now();
    _previewTimer?.cancel();
    _previewTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted || !_previewPlaying) {
        return;
      }
      final DateTime now = DateTime.now();
      final DateTime previous = _previewLastTick ?? now;
      _previewLastTick = now;
      final double deltaSeconds =
          now.difference(previous).inMicroseconds / 1000000.0;
      if (deltaSeconds <= 0) {
        return;
      }
      setState(() {
        _previewElapsedSeconds += deltaSeconds;
      });
    });
  }

  void _restartPreview() {
    setState(() {
      _previewElapsedSeconds = 0.0;
    });
  }

  void _syncPreviewSelection(GameAnimation? animation) {
    final String nextId = animation?.id ?? '';
    if (nextId == _previewAnimationId) {
      return;
    }
    _previewAnimationId = nextId;
    _previewElapsedSeconds = 0.0;
    _previewLastTick = null;
    if (animation == null) {
      _setPreviewPlaying(false);
      return;
    }
    _setPreviewPlaying(true);
  }

  int _previewFrameIndex({
    required GameAnimation animation,
    required int totalFrames,
  }) {
    final int safeTotalFrames = math.max(1, totalFrames);
    final int start = animation.startFrame.clamp(0, safeTotalFrames - 1);
    final int end = animation.endFrame.clamp(start, safeTotalFrames - 1);
    final int span = math.max(1, end - start + 1);
    final int ticks = (_previewElapsedSeconds * animation.fps).floor();
    final int offset =
        animation.loop ? ticks % span : math.min(ticks, span - 1);
    return start + offset;
  }

  Widget _buildPreviewPanel(AppData appData, GameAnimation? animation) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final bool hasAnimation = animation != null;
    const double previewCanvasHeight = 120;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cdkColors.backgroundSecondary0,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cdkColors.colorTextSecondary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasAnimation)
            const SizedBox(
              height: previewCanvasHeight,
              child: Center(
                child: CDKText(
                  'Select an animation to preview.',
                  role: CDKTextRole.caption,
                  secondary: true,
                ),
              ),
            )
          else
            FutureBuilder<ui.Image>(
              future: appData.getImage(animation.mediaFile),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  return const SizedBox(
                    height: previewCanvasHeight,
                    child: Center(
                      child: CupertinoActivityIndicator(),
                    ),
                  );
                }
                final ui.Image? image = snapshot.data;
                final GameMediaAsset? media =
                    appData.mediaAssetByFileName(animation.mediaFile);
                if (image == null ||
                    media == null ||
                    media.tileWidth <= 0 ||
                    media.tileHeight <= 0) {
                  return const SizedBox(
                    height: previewCanvasHeight,
                    child: Center(
                      child: CDKText(
                        'Preview unavailable',
                        role: CDKTextRole.caption,
                        secondary: true,
                      ),
                    ),
                  );
                }
                final int cols =
                    math.max(1, (image.width / media.tileWidth).floor());
                final int rows =
                    math.max(1, (image.height / media.tileHeight).floor());
                final int totalFrames = math.max(1, cols * rows);
                final int frameIndex = _previewFrameIndex(
                  animation: animation,
                  totalFrames: totalFrames,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: previewCanvasHeight,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: media.tileWidth / media.tileHeight,
                          child: CustomPaint(
                            painter: _AnimationFramePreviewPainter(
                              image: image,
                              frameWidth: media.tileWidth.toDouble(),
                              frameHeight: media.tileHeight.toDouble(),
                              columns: cols,
                              frameIndex: frameIndex,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    CDKText(
                      'Frame $frameIndex (${animation.startFrame}-${animation.endFrame}) @ ${animation.fps.toStringAsFixed(1)} fps',
                      role: CDKTextRole.caption,
                      secondary: true,
                    ),
                  ],
                );
              },
            ),
          if (!hasAnimation) ...[
            SizedBox(height: spacing.xs),
            const CDKText(
              'Frame -',
              role: CDKTextRole.caption,
              secondary: true,
            ),
          ],
        ],
      ),
    );
  }

  List<GameMediaAsset> _animationSourceAssets(AppData appData) {
    return appData.gameData.mediaAssets
        .where(
          (asset) =>
              asset.mediaType == 'spritesheet' || asset.mediaType == 'atlas',
        )
        .toList(growable: false);
  }

  int _animationUsageCount(AppData appData, String animationId) {
    int count = 0;
    for (final level in appData.gameData.levels) {
      for (final sprite in level.sprites) {
        if (sprite.animationId == animationId) {
          count += 1;
        }
      }
    }
    return count;
  }

  List<GameListGroup> _animationGroups(AppData appData) {
    if (appData.gameData.animationGroups.isEmpty) {
      return <GameListGroup>[GameListGroup.main()];
    }
    final bool hasMain = appData.gameData.animationGroups
        .any((group) => group.id == GameListGroup.mainId);
    if (hasMain) {
      return appData.gameData.animationGroups;
    }
    return <GameListGroup>[
      GameListGroup.main(),
      ...appData.gameData.animationGroups,
    ];
  }

  void _ensureMainAnimationGroup(AppData appData) {
    final List<GameListGroup> groups = appData.gameData.animationGroups;
    final int mainIndex =
        groups.indexWhere((group) => group.id == GameListGroup.mainId);
    if (mainIndex == -1) {
      groups.insert(0, GameListGroup.main());
      return;
    }
    final GameListGroup mainGroup = groups[mainIndex];
    final String normalizedName = mainGroup.name.trim().isEmpty
        ? GameListGroup.defaultMainName
        : mainGroup.name.trim();
    if (mainGroup.name != normalizedName) {
      mainGroup.name = normalizedName;
    }
  }

  Set<String> _animationGroupIds(AppData appData) {
    return _animationGroups(appData).map((group) => group.id).toSet();
  }

  String _effectiveAnimationGroupId(AppData appData, GameAnimation animation) {
    final String groupId = animation.groupId.trim();
    if (groupId.isNotEmpty && _animationGroupIds(appData).contains(groupId)) {
      return groupId;
    }
    return GameListGroup.mainId;
  }

  Map<String, int> _animationCountByGroup(AppData appData) {
    final Map<String, int> counts = {
      for (final group in _animationGroups(appData)) group.id: 0,
    };
    for (final animation in appData.gameData.animations) {
      final String groupId = _effectiveAnimationGroupId(appData, animation);
      counts[groupId] = (counts[groupId] ?? 0) + 1;
    }
    return counts;
  }

  GameListGroup? _findAnimationGroupById(AppData appData, String groupId) {
    for (final group in _animationGroups(appData)) {
      if (group.id == groupId) {
        return group;
      }
    }
    return null;
  }

  List<GroupedListRow<GameListGroup, GameAnimation>> _buildAnimationRows(
      AppData appData) {
    return GroupedListAlgorithms.buildRows<GameListGroup, GameAnimation>(
      groups: _animationGroups(appData),
      items: appData.gameData.animations,
      mainGroupId: GameListGroup.mainId,
      groupIdOf: (group) => group.id,
      groupCollapsedOf: (group) => group.collapsed,
      itemGroupIdOf: (animation) =>
          _effectiveAnimationGroupId(appData, animation),
    );
  }

  String _newGroupId() {
    return '__group_${DateTime.now().microsecondsSinceEpoch}_${_newGroupCounter++}';
  }

  Future<bool> _upsertAnimationGroup(
    AppData appData,
    GroupedListGroupDraft draft,
  ) async {
    final String nextName = draft.name.trim();
    if (nextName.isEmpty) {
      return false;
    }

    await appData.runProjectMutation(
      debugLabel: 'animation-group-upsert',
      mutate: () {
        _ensureMainAnimationGroup(appData);
        final List<GameListGroup> groups = appData.gameData.animationGroups;
        final int existingIndex =
            groups.indexWhere((group) => group.id == draft.id);
        if (existingIndex != -1) {
          groups[existingIndex].name = nextName;
          return;
        }
        groups.add(
          GameListGroup(
            id: draft.id,
            name: nextName,
            collapsed: false,
          ),
        );
      },
    );

    return true;
  }

  Future<bool> _confirmAndDeleteAnimationGroup(
      AppData appData, String groupId) async {
    if (!mounted) {
      return false;
    }
    if (groupId == GameListGroup.mainId) {
      return false;
    }

    final GameListGroup? group = _findAnimationGroupById(appData, groupId);
    if (group == null) {
      return false;
    }

    final List<GameAnimation> animationsToDelete = appData.gameData.animations
        .where(
          (animation) =>
              _effectiveAnimationGroupId(appData, animation) == groupId,
        )
        .toList(growable: false);

    int totalUsage = 0;
    for (final animation in animationsToDelete) {
      totalUsage += _animationUsageCount(appData, animation.id);
    }
    if (totalUsage > 0) {
      appData.projectStatusMessage =
          'Group "${group.name}" contains animations used by sprites.';
      appData.update();
      return false;
    }

    final bool? confirmed = await CDKDialogsManager.showConfirm(
      context: context,
      title: 'Delete group',
      message: animationsToDelete.isNotEmpty
          ? 'Delete "${group.name}" and its ${animationsToDelete.length} animation(s)? This cannot be undone.'
          : 'Delete "${group.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
      showBackgroundShade: true,
    );
    if (confirmed != true || !mounted) {
      return false;
    }

    await appData.runProjectMutation(
      debugLabel: 'animation-group-delete',
      mutate: () {
        _ensureMainAnimationGroup(appData);
        final List<GameListGroup> groups = appData.gameData.animationGroups;
        final List<GameAnimation> animations = appData.gameData.animations;
        final int groupIndex = groups.indexWhere((g) => g.id == groupId);
        if (groupIndex == -1) {
          return;
        }

        final GameAnimation? selectedAnimation =
            appData.selectedAnimation >= 0 &&
                    appData.selectedAnimation < animations.length
                ? animations[appData.selectedAnimation]
                : null;
        groups.removeAt(groupIndex);
        animations.removeWhere((animation) => animation.groupId == groupId);

        if (selectedAnimation == null) {
          appData.selectedAnimation = -1;
          _syncFrameSelectionToAnimation(appData, null);
          return;
        }
        appData.selectedAnimation = animations.indexOf(selectedAnimation);
        if (appData.selectedAnimation >= 0 &&
            appData.selectedAnimation < animations.length) {
          _syncFrameSelectionToAnimation(
            appData,
            animations[appData.selectedAnimation],
          );
        } else {
          _syncFrameSelectionToAnimation(appData, null);
        }
      },
    );

    return true;
  }

  Future<void> _showAnimationGroupsPopover(AppData appData) async {
    if (Overlay.maybeOf(context) == null) {
      return;
    }
    final List<GroupedListGroupDraft> initialGroups = _animationGroups(appData)
        .map(
          (group) => GroupedListGroupDraft(
            id: group.id,
            name: group.name,
            collapsed: group.collapsed,
          ),
        )
        .toList(growable: false);
    final Map<String, int> animationCountsByGroup =
        _animationCountByGroup(appData);
    final CDKDialogController controller = CDKDialogController();

    CDKDialogsManager.showPopoverArrowed(
      context: context,
      anchorKey: _animationGroupsAnchorKey,
      isAnimated: true,
      animateContentResize: false,
      dismissOnEscape: true,
      dismissOnOutsideTap: true,
      showBackgroundShade: false,
      controller: controller,
      child: GroupedListGroupsPopover(
        title: 'Animation Groups',
        itemCaption: 'animation(s)',
        initialGroups: initialGroups,
        itemCountsByGroup: animationCountsByGroup,
        mainGroupId: GameListGroup.mainId,
        onCreateGroup: (name) async {
          final String trimmed = name.trim();
          if (trimmed.isEmpty) {
            return null;
          }
          final GroupedListGroupDraft draft = GroupedListGroupDraft(
            id: _newGroupId(),
            name: trimmed,
            collapsed: false,
          );
          final bool success = await _upsertAnimationGroup(appData, draft);
          return success ? draft : null;
        },
        onRenameGroup: (groupId, name) async {
          final String trimmed = name.trim();
          if (trimmed.isEmpty) {
            return false;
          }
          return _upsertAnimationGroup(
            appData,
            GroupedListGroupDraft(
              id: groupId,
              name: trimmed,
              collapsed: false,
            ),
          );
        },
        onDeleteGroup: (groupId) =>
            _confirmAndDeleteAnimationGroup(appData, groupId),
      ),
    );
  }

  void _syncFrameSelectionToAnimation(
      AppData appData, GameAnimation? animation) {
    if (animation == null) {
      LayoutUtils.clearAnimationFrameSelection(appData);
      return;
    }
    appData.animationSelectionStartFrame = animation.startFrame;
    appData.animationSelectionEndFrame = animation.endFrame;
  }

  void _applyAnimationMediaToSprites(
    AppData appData,
    GameAnimation animation,
  ) {
    final GameMediaAsset? media =
        appData.mediaAssetByFileName(animation.mediaFile);
    for (final level in appData.gameData.levels) {
      for (final sprite in level.sprites) {
        if (sprite.animationId != animation.id) {
          continue;
        }
        sprite.imageFile = animation.mediaFile;
        if (media != null && media.tileWidth > 0 && media.tileHeight > 0) {
          sprite.spriteWidth = media.tileWidth;
          sprite.spriteHeight = media.tileHeight;
        }
      }
    }
  }

  void _addAnimation({
    required AppData appData,
    required _AnimationDialogData data,
  }) {
    appData.gameData.animations.add(
      GameAnimation(
        id: 'anim_${DateTime.now().microsecondsSinceEpoch}',
        name: data.name,
        mediaFile: data.mediaFile,
        startFrame: data.startFrame,
        endFrame: data.endFrame,
        fps: data.fps,
        loop: data.loop,
        groupId: GameAnimation.defaultGroupId,
      ),
    );
    appData.selectedAnimation = -1;
    appData.update();
  }

  void _updateAnimation({
    required AppData appData,
    required int index,
    required _AnimationDialogData data,
  }) {
    final animations = appData.gameData.animations;
    if (index < 0 || index >= animations.length) {
      return;
    }
    final previous = animations[index];
    final updated = GameAnimation(
      id: previous.id,
      name: data.name,
      mediaFile: data.mediaFile,
      startFrame: data.startFrame,
      endFrame: data.endFrame,
      fps: data.fps,
      loop: data.loop,
      groupId: previous.groupId,
    );
    animations[index] = updated;
    _applyAnimationMediaToSprites(appData, updated);
    appData.selectedAnimation = index;
    _syncFrameSelectionToAnimation(appData, updated);
  }

  Future<_AnimationDialogData?> _promptAnimationData({
    required String title,
    required String confirmLabel,
    required _AnimationDialogData initialData,
    required List<GameMediaAsset> sourceAssets,
    GlobalKey? anchorKey,
    bool useArrowedPopover = false,
    bool liveEdit = false,
    Future<void> Function(_AnimationDialogData value)? onLiveChanged,
    VoidCallback? onDelete,
  }) async {
    if (Overlay.maybeOf(context) == null) {
      return null;
    }

    final AppData appData = Provider.of<AppData>(context, listen: false);
    final CDKDialogController controller = CDKDialogController();
    final Completer<_AnimationDialogData?> completer =
        Completer<_AnimationDialogData?>();
    _AnimationDialogData? result;

    final dialogChild = _AnimationFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialData: initialData,
      sourceAssets: sourceAssets,
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

  Future<void> _promptAndAddAnimation(List<GameMediaAsset> sourceAssets) async {
    if (sourceAssets.isEmpty) {
      return;
    }
    final GameMediaAsset first = sourceAssets.first;
    final _AnimationDialogData? data = await _promptAnimationData(
      title: 'New animation',
      confirmLabel: 'Add',
      initialData: _AnimationDialogData(
        name: '',
        mediaFile: first.fileName,
        startFrame: 0,
        endFrame: 0,
        fps: 12.0,
        loop: true,
      ),
      sourceAssets: sourceAssets,
    );
    if (!mounted || data == null) {
      return;
    }
    final AppData appData = Provider.of<AppData>(context, listen: false);
    await appData.runProjectMutation(
      debugLabel: 'animation-add',
      mutate: () {
        _addAnimation(appData: appData, data: data);
      },
    );
  }

  Future<void> _confirmAndDeleteAnimation(int index) async {
    if (!mounted) {
      return;
    }
    final AppData appData = Provider.of<AppData>(context, listen: false);
    final animations = appData.gameData.animations;
    if (index < 0 || index >= animations.length) {
      return;
    }
    final GameAnimation animation = animations[index];
    final int usageCount = _animationUsageCount(appData, animation.id);
    if (usageCount > 0) {
      appData.projectStatusMessage =
          'Animation "${animation.name}" is in use by $usageCount sprite(s).';
      appData.update();
      return;
    }

    final bool? confirmed = await CDKDialogsManager.showConfirm(
      context: context,
      title: 'Delete animation',
      message: 'Delete "${animation.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
      showBackgroundShade: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await appData.runProjectMutation(
      debugLabel: 'animation-delete',
      mutate: () {
        animations.removeAt(index);
        appData.selectedAnimation = -1;
        _syncFrameSelectionToAnimation(appData, null);
      },
    );
  }

  Future<void> _promptAndEditAnimation(
    int index,
    GlobalKey anchorKey,
    List<GameMediaAsset> sourceAssets,
  ) async {
    final AppData appData = Provider.of<AppData>(context, listen: false);
    final animations = appData.gameData.animations;
    if (index < 0 || index >= animations.length) {
      return;
    }
    final animation = animations[index];
    final int usageCount = _animationUsageCount(appData, animation.id);
    final String undoGroupKey =
        'animation-live-$index-${DateTime.now().microsecondsSinceEpoch}';

    await _promptAnimationData(
      title: 'Edit animation',
      confirmLabel: 'Save',
      initialData: _AnimationDialogData(
        name: animation.name,
        mediaFile: animation.mediaFile,
        startFrame: animation.startFrame,
        endFrame: animation.endFrame,
        fps: animation.fps,
        loop: animation.loop,
      ),
      sourceAssets: sourceAssets,
      anchorKey: anchorKey,
      useArrowedPopover: true,
      liveEdit: true,
      onLiveChanged: (value) async {
        await appData.runProjectMutation(
          debugLabel: 'animation-live-edit',
          undoGroupKey: undoGroupKey,
          mutate: () {
            _updateAnimation(appData: appData, index: index, data: value);
          },
        );
      },
      onDelete:
          usageCount == 0 ? () => _confirmAndDeleteAnimation(index) : null,
    );
  }

  void _selectAnimation(AppData appData, int index, bool isSelected) {
    if (isSelected) {
      appData.selectedAnimation = -1;
      _syncFrameSelectionToAnimation(appData, null);
      appData.update();
      return;
    }
    appData.selectedAnimation = index;
    if (index >= 0 && index < appData.gameData.animations.length) {
      _syncFrameSelectionToAnimation(
        appData,
        appData.gameData.animations[index],
      );
    } else {
      _syncFrameSelectionToAnimation(appData, null);
    }
    appData.update();
  }

  Future<void> _toggleGroupCollapsed(AppData appData, String groupId) async {
    await appData.runProjectMutation(
      debugLabel: 'animation-group-toggle-collapse',
      mutate: () {
        _ensureMainAnimationGroup(appData);
        final List<GameListGroup> groups = appData.gameData.animationGroups;
        final int index = groups.indexWhere((group) => group.id == groupId);
        if (index == -1) {
          return;
        }
        final GameListGroup group = groups[index];
        group.collapsed = !group.collapsed;
        if (group.collapsed &&
            appData.selectedAnimation >= 0 &&
            appData.selectedAnimation < appData.gameData.animations.length &&
            _effectiveAnimationGroupId(
                  appData,
                  appData.gameData.animations[appData.selectedAnimation],
                ) ==
                group.id) {
          appData.selectedAnimation = -1;
          _syncFrameSelectionToAnimation(appData, null);
        }
      },
    );
  }

  void _moveGroup({
    required AppData appData,
    required List<GroupedListRow<GameListGroup, GameAnimation>>
        rowsWithoutMovedItem,
    required GroupedListRow<GameListGroup, GameAnimation> movedRow,
    required int targetRowIndex,
  }) {
    GroupedListAlgorithms.moveGroup<GameListGroup, GameAnimation>(
      groups: appData.gameData.animationGroups,
      rowsWithoutMovedItem: rowsWithoutMovedItem,
      movedRow: movedRow,
      targetRowIndex: targetRowIndex,
      groupIdOf: (group) => group.id,
    );
  }

  void _moveAnimation({
    required AppData appData,
    required List<GroupedListRow<GameListGroup, GameAnimation>>
        rowsWithoutMovedItem,
    required GroupedListRow<GameListGroup, GameAnimation> movedRow,
    required int targetRowIndex,
  }) {
    final List<GameAnimation> animations = appData.gameData.animations;
    appData.selectedAnimation = GroupedListAlgorithms
        .moveItemAndReturnSelectedIndex<GameListGroup, GameAnimation>(
      groups: appData.gameData.animationGroups,
      items: animations,
      rowsWithoutMovedItem: rowsWithoutMovedItem,
      movedRow: movedRow,
      targetRowIndex: targetRowIndex,
      mainGroupId: GameListGroup.mainId,
      groupIdOf: (group) => group.id,
      effectiveGroupIdOfItem: (animation) =>
          _effectiveAnimationGroupId(appData, animation),
      setItemGroupId: (animation, groupId) {
        animation.groupId = groupId;
      },
      selectedIndex: appData.selectedAnimation,
    );
  }

  void _onReorder(
    AppData appData,
    List<GroupedListRow<GameListGroup, GameAnimation>> rows,
    int oldIndex,
    int newIndex,
  ) {
    if (rows.isEmpty || oldIndex < 0 || oldIndex >= rows.length) {
      return;
    }

    final int targetIndex = GroupedListAlgorithms.normalizeTargetIndex(
      oldIndex: oldIndex,
      newIndex: newIndex,
      rowCount: rows.length,
    );
    final List<GroupedListRow<GameListGroup, GameAnimation>>
        rowsWithoutMovedItem =
        List<GroupedListRow<GameListGroup, GameAnimation>>.from(rows);
    final GroupedListRow<GameListGroup, GameAnimation> movedRow =
        rowsWithoutMovedItem.removeAt(oldIndex);
    int boundedTargetIndex = targetIndex;
    if (boundedTargetIndex > rowsWithoutMovedItem.length) {
      boundedTargetIndex = rowsWithoutMovedItem.length;
    }

    unawaited(
      appData.runProjectMutation(
        debugLabel: 'animation-reorder',
        mutate: () {
          _ensureMainAnimationGroup(appData);
          if (movedRow.isGroup) {
            _moveGroup(
              appData: appData,
              rowsWithoutMovedItem: rowsWithoutMovedItem,
              movedRow: movedRow,
              targetRowIndex: boundedTargetIndex,
            );
          } else {
            _moveAnimation(
              appData: appData,
              rowsWithoutMovedItem: rowsWithoutMovedItem,
              movedRow: movedRow,
              targetRowIndex: boundedTargetIndex,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppData appData = Provider.of<AppData>(context);
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    final TextStyle sectionTitleStyle = typography.title.copyWith(
      fontSize: (typography.title.fontSize ?? 17) + 2,
    );
    final TextStyle listItemTitleStyle = typography.body.copyWith(
      fontSize: (typography.body.fontSize ?? 14) + 2,
      fontWeight: FontWeight.w700,
    );

    if (appData.selectedProject == null) {
      return const Center(
        child: CDKText(
          'Select a project to manage animations.',
          role: CDKTextRole.body,
          secondary: true,
        ),
      );
    }

    final List<GameMediaAsset> sourceAssets = _animationSourceAssets(appData);
    final bool hasSources = sourceAssets.isNotEmpty;
    final animations = appData.gameData.animations;
    final animationRows = _buildAnimationRows(appData);

    if (appData.selectedAnimation >= animations.length) {
      appData.selectedAnimation =
          animations.isEmpty ? -1 : animations.length - 1;
      if (appData.selectedAnimation >= 0 &&
          appData.selectedAnimation < animations.length) {
        _syncFrameSelectionToAnimation(
          appData,
          animations[appData.selectedAnimation],
        );
      } else {
        _syncFrameSelectionToAnimation(appData, null);
      }
    }

    final GameAnimation? selectedAnimation = appData.selectedAnimation >= 0 &&
            appData.selectedAnimation < animations.length
        ? animations[appData.selectedAnimation]
        : null;
    _syncPreviewSelection(selectedAnimation);
    final bool hasSelectedAnimation = selectedAnimation != null;
    final bool isPreviewPlaying = hasSelectedAnimation && _previewPlaying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Row(
            children: [
              CDKText(
                'Animations',
                role: CDKTextRole.title,
                style: sectionTitleStyle,
              ),
              const SizedBox(width: 6),
              const SectionHelpButton(
                message:
                    'Animations define sequences of frames from a spritesheet. They are referenced by sprites to bring game characters and objects to life.',
              ),
              const Spacer(),
              CDKButton(
                key: _animationGroupsAnchorKey,
                style: CDKButtonStyle.normal,
                onPressed: () async {
                  await _showAnimationGroupsPopover(appData);
                },
                child: const Text('Groups'),
              ),
              SizedBox(width: spacing.sm),
              CDKButton(
                style: CDKButtonStyle.action,
                onPressed: hasSources
                    ? () async {
                        await _promptAndAddAnimation(sourceAssets);
                      }
                    : null,
                child: const Text('+ Add Animation'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CDKButton(
                style: CDKButtonStyle.normal,
                onPressed: hasSelectedAnimation
                    ? () {
                        setState(() {
                          _setPreviewPlaying(!_previewPlaying);
                        });
                      }
                    : null,
                child: Icon(
                  isPreviewPlaying
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                  size: 12,
                ),
              ),
              SizedBox(width: spacing.xs),
              CDKButton(
                style: CDKButtonStyle.normal,
                onPressed: hasSelectedAnimation ? _restartPreview : null,
                child: const Icon(
                  CupertinoIcons.refresh,
                  size: 12,
                ),
              ),
            ],
          ),
        ),
        _buildPreviewPanel(appData, selectedAnimation),
        Expanded(
          child: animations.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: CDKText(
                    hasSources
                        ? '(No animations defined)'
                        : 'Add a spritesheet or atlas in Media first.',
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
                      itemCount: animationRows.length,
                      onReorder: (oldIndex, newIndex) => _onReorder(
                        appData,
                        animationRows,
                        oldIndex,
                        newIndex,
                      ),
                      itemBuilder: (context, index) {
                        final GroupedListRow<GameListGroup, GameAnimation> row =
                            animationRows[index];
                        if (row.isGroup) {
                          final GameListGroup group = row.group!;
                          return Container(
                            key: ValueKey('animation-group-${group.id}'),
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 8,
                            ),
                            color: CupertinoColors.systemBlue
                                .withValues(alpha: 0.08),
                            child: Row(
                              children: [
                                CupertinoButton(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  minimumSize: const Size(20, 20),
                                  onPressed: () async {
                                    await _toggleGroupCollapsed(
                                        appData, group.id);
                                  },
                                  child: AnimatedRotation(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeInOutCubic,
                                    turns: group.collapsed ? 0.0 : 0.25,
                                    child: Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 14,
                                      color: cdkColors.colorText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Row(
                                    children: [
                                      CDKText(
                                        group.name,
                                        role: CDKTextRole.body,
                                        style: listItemTitleStyle,
                                      ),
                                      if (group.id == GameListGroup.mainId) ...[
                                        const SizedBox(width: 6),
                                        Icon(
                                          CupertinoIcons.lock_fill,
                                          size: 12,
                                          color: cdkColors.colorText
                                              .withValues(alpha: 0.7),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Icon(
                                      CupertinoIcons.bars,
                                      size: 16,
                                      color: cdkColors.colorText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final GameAnimation animation = row.item!;
                        final int animationIndex = row.itemIndex!;
                        final bool isSelected =
                            animationIndex == appData.selectedAnimation;
                        final int usageCount =
                            _animationUsageCount(appData, animation.id);
                        final String mediaName = appData
                            .mediaDisplayNameByFileName(animation.mediaFile);
                        final String subtitle =
                            '$mediaName | Frames ${animation.startFrame}-${animation.endFrame}';
                        final String details =
                            '${animation.fps.toStringAsFixed(1)} fps | ${animation.loop ? 'Loop' : 'No loop'} | $usageCount sprite(s)';
                        final bool hiddenByCollapse = row.hiddenByCollapse;
                        return AnimatedSize(
                          key: ValueKey('${animation.id}-$index'),
                          duration: const Duration(milliseconds: 300),
                          reverseDuration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.topCenter,
                          child: ClipRect(
                            child: Align(
                              heightFactor: hiddenByCollapse ? 0.0 : 1.0,
                              alignment: Alignment.topCenter,
                              child: IgnorePointer(
                                ignoring: hiddenByCollapse,
                                child: GestureDetector(
                                  onTap: () => _selectAnimation(
                                    appData,
                                    animationIndex,
                                    isSelected,
                                  ),
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
                                        const SizedBox(width: 22),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CDKText(
                                                animation.name,
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
                                        if (isSelected && hasSources)
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: CupertinoButton(
                                              key: _selectedEditAnchorKey,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                              ),
                                              minimumSize: const Size(20, 20),
                                              onPressed: () async {
                                                await _promptAndEditAnimation(
                                                  animationIndex,
                                                  _selectedEditAnchorKey,
                                                  sourceAssets,
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
                                ),
                              ),
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

class _AnimationDialogData {
  const _AnimationDialogData({
    required this.name,
    required this.mediaFile,
    required this.startFrame,
    required this.endFrame,
    required this.fps,
    required this.loop,
  });

  final String name;
  final String mediaFile;
  final int startFrame;
  final int endFrame;
  final double fps;
  final bool loop;
}

class _AnimationFormDialog extends StatefulWidget {
  const _AnimationFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialData,
    required this.sourceAssets,
    this.liveEdit = false,
    this.onLiveChanged,
    this.onClose,
    required this.onConfirm,
    required this.onCancel,
    this.onDelete,
  });

  final String title;
  final String confirmLabel;
  final _AnimationDialogData initialData;
  final List<GameMediaAsset> sourceAssets;
  final bool liveEdit;
  final Future<void> Function(_AnimationDialogData value)? onLiveChanged;
  final VoidCallback? onClose;
  final ValueChanged<_AnimationDialogData> onConfirm;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  State<_AnimationFormDialog> createState() => _AnimationFormDialogState();
}

class _AnimationFormDialogState extends State<_AnimationFormDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialData.name,
  );
  late final TextEditingController _startFrameController =
      TextEditingController(text: widget.initialData.startFrame.toString());
  late final TextEditingController _endFrameController =
      TextEditingController(text: widget.initialData.endFrame.toString());
  late final TextEditingController _fpsController = TextEditingController(
    text: widget.initialData.fps.toStringAsFixed(1),
  );
  late bool _loop = widget.initialData.loop;
  late int _selectedAssetIndex = _resolveInitialAssetIndex();
  EditSession<_AnimationDialogData>? _editSession;

  int _resolveInitialAssetIndex() {
    final String current = widget.initialData.mediaFile;
    if (current.isNotEmpty) {
      final int found =
          widget.sourceAssets.indexWhere((asset) => asset.fileName == current);
      if (found != -1) {
        return found;
      }
    }
    return 0;
  }

  GameMediaAsset? get _selectedAsset {
    if (widget.sourceAssets.isEmpty) {
      return null;
    }
    if (_selectedAssetIndex < 0 ||
        _selectedAssetIndex >= widget.sourceAssets.length) {
      _selectedAssetIndex = 0;
    }
    return widget.sourceAssets[_selectedAssetIndex];
  }

  int? _parseFrame(String raw) {
    final int? value = int.tryParse(raw.trim());
    if (value == null || value < 0) {
      return null;
    }
    return value;
  }

  double? _parseFps(String raw) {
    final String normalized = raw.trim().replaceAll(',', '.');
    final double? value = double.tryParse(normalized);
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  bool get _isValid {
    final int? start = _parseFrame(_startFrameController.text);
    final int? end = _parseFrame(_endFrameController.text);
    final double? fps = _parseFps(_fpsController.text);
    if (_nameController.text.trim().isEmpty || _selectedAsset == null) {
      return false;
    }
    if (start == null || end == null || fps == null) {
      return false;
    }
    return end >= start;
  }

  _AnimationDialogData _currentData() {
    final GameMediaAsset? asset = _selectedAsset;
    final int start = _parseFrame(_startFrameController.text) ?? 0;
    final int end = _parseFrame(_endFrameController.text) ?? start;
    return _AnimationDialogData(
      name: _nameController.text.trim(),
      mediaFile: asset?.fileName ?? widget.initialData.mediaFile,
      startFrame: start,
      endFrame: end < start ? start : end,
      fps: _parseFps(_fpsController.text) ?? 12.0,
      loop: _loop,
    );
  }

  String? _validateData(_AnimationDialogData value) {
    if (value.name.trim().isEmpty) {
      return 'Animation name is required.';
    }
    if (_selectedAsset == null) {
      return 'Select a spritesheet or atlas in Media first.';
    }
    if (value.startFrame < 0 || value.endFrame < value.startFrame) {
      return 'Frame range must be valid.';
    }
    if (value.fps <= 0) {
      return 'FPS must be greater than 0.';
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
      _editSession = EditSession<_AnimationDialogData>(
        initialValue: _currentData(),
        validate: _validateData,
        onPersist: widget.onLiveChanged!,
        areEqual: (a, b) =>
            a.name == b.name &&
            a.mediaFile == b.mediaFile &&
            a.startFrame == b.startFrame &&
            a.endFrame == b.endFrame &&
            a.fps == b.fps &&
            a.loop == b.loop,
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
    _startFrameController.dispose();
    _endFrameController.dispose();
    _fpsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final GameMediaAsset? asset = _selectedAsset;
    final List<String> mediaOptions = widget.sourceAssets
        .map((a) => a.name.trim().isNotEmpty ? a.name : a.fileName)
        .toList(growable: false);

    return EditorFormDialogScaffold(
      title: widget.title,
      description: 'Configure animation details.',
      confirmLabel: widget.confirmLabel,
      confirmEnabled: _isValid,
      onConfirm: _confirm,
      onCancel: widget.onCancel,
      liveEditMode: widget.liveEdit,
      onClose: widget.onClose,
      onDelete: widget.onDelete,
      minWidth: 400,
      maxWidth: 540,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorLabeledField(
            label: 'Animation Name',
            child: CDKFieldText(
              placeholder: 'Animation name',
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
            label: 'Source Media',
            child: mediaOptions.isEmpty
                ? const CDKText(
                    'No spritesheet or atlas available',
                    role: CDKTextRole.caption,
                    secondary: true,
                  )
                : CDKButtonSelect(
                    selectedIndex: _selectedAssetIndex,
                    options: mediaOptions,
                    onSelected: (int index) {
                      setState(() {
                        _selectedAssetIndex = index;
                      });
                      _onInputChanged();
                    },
                  ),
          ),
          if (asset != null) ...[
            const SizedBox(height: 4),
            CDKText(
              'Frame size: ${asset.tileWidth}×${asset.tileHeight} px',
              role: CDKTextRole.caption,
              color: cdkColors.colorText,
              secondary: true,
            ),
          ],
          SizedBox(height: spacing.sm),
          Row(
            children: [
              Expanded(
                child: EditorLabeledField(
                  label: 'Start Frame',
                  child: CDKFieldText(
                    placeholder: 'Start',
                    controller: _startFrameController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setState(() {});
                      _onInputChanged();
                    },
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: EditorLabeledField(
                  label: 'End Frame',
                  child: CDKFieldText(
                    placeholder: 'End',
                    controller: _endFrameController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setState(() {});
                      _onInputChanged();
                    },
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              Expanded(
                child: EditorLabeledField(
                  label: 'FPS',
                  child: CDKFieldText(
                    placeholder: 'Frames per second',
                    controller: _fpsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _onInputChanged();
                    },
                  ),
                ),
              ),
              SizedBox(width: spacing.md),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CDKText(
                    'Loop',
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
                        value: _loop,
                        onChanged: (bool value) {
                          setState(() {
                            _loop = value;
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

class _AnimationFramePreviewPainter extends CustomPainter {
  const _AnimationFramePreviewPainter({
    required this.image,
    required this.frameWidth,
    required this.frameHeight,
    required this.columns,
    required this.frameIndex,
  });

  final ui.Image image;
  final double frameWidth;
  final double frameHeight;
  final int columns;
  final int frameIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bgA = Paint()..color = const Color(0xFFE7E7E7);
    final Paint bgB = Paint()..color = const Color(0xFFD7D7D7);
    const double checker = 12.0;
    for (double y = 0; y < size.height; y += checker) {
      for (double x = 0; x < size.width; x += checker) {
        final bool even =
            ((x / checker).floor() + (y / checker).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, checker, checker),
          even ? bgA : bgB,
        );
      }
    }

    if (frameWidth <= 0 || frameHeight <= 0 || columns <= 0) {
      return;
    }

    final int row = frameIndex ~/ columns;
    final int col = frameIndex % columns;
    final Rect src = Rect.fromLTWH(
      col * frameWidth,
      row * frameHeight,
      frameWidth,
      frameHeight,
    );
    if (src.right > image.width || src.bottom > image.height) {
      return;
    }

    final double scale =
        math.min(size.width / frameWidth, size.height / frameHeight);
    final double drawWidth = frameWidth * scale;
    final double drawHeight = frameHeight * scale;
    final Rect dst = Rect.fromLTWH(
      (size.width - drawWidth) / 2,
      (size.height - drawHeight) / 2,
      drawWidth,
      drawHeight,
    );

    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );

    canvas.drawRect(
      dst,
      Paint()
        ..color = const Color(0x66007AFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _AnimationFramePreviewPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight ||
        oldDelegate.columns != columns ||
        oldDelegate.frameIndex != frameIndex;
  }
}
