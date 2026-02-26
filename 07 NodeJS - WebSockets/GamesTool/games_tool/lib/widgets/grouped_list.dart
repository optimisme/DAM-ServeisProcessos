import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';

enum GroupedListRowType { group, item }

class GroupedListRow<G, I> {
  const GroupedListRow._({
    required this.type,
    required this.groupId,
    this.group,
    this.item,
    this.itemIndex,
    this.hiddenByCollapse = false,
  });

  factory GroupedListRow.group({
    required String groupId,
    required G group,
  }) {
    return GroupedListRow._(
      type: GroupedListRowType.group,
      groupId: groupId,
      group: group,
    );
  }

  factory GroupedListRow.item({
    required String groupId,
    required I item,
    required int itemIndex,
    bool hiddenByCollapse = false,
  }) {
    return GroupedListRow._(
      type: GroupedListRowType.item,
      groupId: groupId,
      item: item,
      itemIndex: itemIndex,
      hiddenByCollapse: hiddenByCollapse,
    );
  }

  final GroupedListRowType type;
  final String groupId;
  final G? group;
  final I? item;
  final int? itemIndex;
  final bool hiddenByCollapse;

  bool get isGroup => type == GroupedListRowType.group;
  bool get isItem => type == GroupedListRowType.item;
}

class GroupedListAlgorithms {
  static List<GroupedListRow<G, I>> buildRows<G, I>({
    required List<G> groups,
    required List<I> items,
    required String mainGroupId,
    required String Function(G group) groupIdOf,
    required bool Function(G group) groupCollapsedOf,
    required String Function(I item) itemGroupIdOf,
  }) {
    final List<GroupedListRow<G, I>> rows = <GroupedListRow<G, I>>[];
    final Set<String> validGroupIds = groups.map(groupIdOf).toSet();

    for (final G group in groups) {
      final String groupId = groupIdOf(group);
      rows.add(GroupedListRow<G, I>.group(groupId: groupId, group: group));
      for (int i = 0; i < items.length; i++) {
        final I item = items[i];
        final String rawGroupId = itemGroupIdOf(item).trim();
        final String effectiveGroupId =
            validGroupIds.contains(rawGroupId) ? rawGroupId : mainGroupId;
        if (effectiveGroupId != groupId) {
          continue;
        }
        rows.add(
          GroupedListRow<G, I>.item(
            groupId: effectiveGroupId,
            item: item,
            itemIndex: i,
            hiddenByCollapse: groupCollapsedOf(group),
          ),
        );
      }
    }

    return rows;
  }

  static int normalizeTargetIndex({
    required int oldIndex,
    required int newIndex,
    required int rowCount,
  }) {
    int next = newIndex;
    if (next < 0) {
      next = 0;
    }
    if (next > rowCount) {
      next = rowCount;
    }
    if (oldIndex < next) {
      next -= 1;
    }
    if (next < 0) {
      next = 0;
    }
    return next;
  }

  static int _firstItemIndexForGroup<I>(
    List<I> items,
    String groupId,
    String Function(I item) effectiveGroupIdOfItem,
  ) {
    for (int i = 0; i < items.length; i++) {
      if (effectiveGroupIdOfItem(items[i]) == groupId) {
        return i;
      }
    }
    return -1;
  }

  static int _lastItemIndexForGroup<I>(
    List<I> items,
    String groupId,
    String Function(I item) effectiveGroupIdOfItem,
  ) {
    for (int i = items.length - 1; i >= 0; i--) {
      if (effectiveGroupIdOfItem(items[i]) == groupId) {
        return i;
      }
    }
    return -1;
  }

  static int _insertionIndexAtGroupStart<G, I>({
    required List<G> groups,
    required List<I> items,
    required String groupId,
    required String Function(G group) groupIdOf,
    required String Function(I item) effectiveGroupIdOfItem,
  }) {
    final int firstInGroup =
        _firstItemIndexForGroup(items, groupId, effectiveGroupIdOfItem);
    if (firstInGroup != -1) {
      return firstInGroup;
    }

    final int groupOrderIndex =
        groups.indexWhere((g) => groupIdOf(g) == groupId);
    if (groupOrderIndex == -1) {
      return items.length;
    }

    for (int i = groupOrderIndex - 1; i >= 0; i--) {
      final int lastPrevious = _lastItemIndexForGroup(
        items,
        groupIdOf(groups[i]),
        effectiveGroupIdOfItem,
      );
      if (lastPrevious != -1) {
        return lastPrevious + 1;
      }
    }

    for (int i = groupOrderIndex + 1; i < groups.length; i++) {
      final int firstNext = _firstItemIndexForGroup(
        items,
        groupIdOf(groups[i]),
        effectiveGroupIdOfItem,
      );
      if (firstNext != -1) {
        return firstNext;
      }
    }

    return items.length;
  }

  static int _insertionIndexAtGroupEnd<G, I>({
    required List<G> groups,
    required List<I> items,
    required String groupId,
    required String Function(G group) groupIdOf,
    required String Function(I item) effectiveGroupIdOfItem,
  }) {
    final int lastInGroup =
        _lastItemIndexForGroup(items, groupId, effectiveGroupIdOfItem);
    if (lastInGroup != -1) {
      return lastInGroup + 1;
    }
    return _insertionIndexAtGroupStart(
      groups: groups,
      items: items,
      groupId: groupId,
      groupIdOf: groupIdOf,
      effectiveGroupIdOfItem: effectiveGroupIdOfItem,
    );
  }

  static void moveGroup<G, I>({
    required List<G> groups,
    required List<GroupedListRow<G, I>> rowsWithoutMovedItem,
    required GroupedListRow<G, I> movedRow,
    required int targetRowIndex,
    required String Function(G group) groupIdOf,
  }) {
    final int movedGroupIndex =
        groups.indexWhere((group) => groupIdOf(group) == movedRow.groupId);
    if (movedGroupIndex == -1) {
      return;
    }

    int insertGroupIndex;
    if (targetRowIndex >= rowsWithoutMovedItem.length) {
      insertGroupIndex = groups.length;
    } else {
      final GroupedListRow<G, I> targetRow =
          rowsWithoutMovedItem[targetRowIndex];
      insertGroupIndex =
          groups.indexWhere((group) => groupIdOf(group) == targetRow.groupId);
      if (insertGroupIndex == -1) {
        insertGroupIndex = groups.length;
      }
    }

    final G movedGroup = groups.removeAt(movedGroupIndex);
    if (movedGroupIndex < insertGroupIndex) {
      insertGroupIndex -= 1;
    }
    insertGroupIndex = insertGroupIndex.clamp(0, groups.length);
    groups.insert(insertGroupIndex, movedGroup);
  }

  static int moveItemAndReturnSelectedIndex<G, I>({
    required List<G> groups,
    required List<I> items,
    required List<GroupedListRow<G, I>> rowsWithoutMovedItem,
    required GroupedListRow<G, I> movedRow,
    required int targetRowIndex,
    required String mainGroupId,
    required String Function(G group) groupIdOf,
    required String Function(I item) effectiveGroupIdOfItem,
    required void Function(I item, String groupId) setItemGroupId,
    required int selectedIndex,
  }) {
    final I? movedItem = movedRow.item;
    if (movedItem == null) {
      return selectedIndex;
    }

    final I? selectedItem = selectedIndex >= 0 && selectedIndex < items.length
        ? items[selectedIndex]
        : null;

    final int currentIndex = items.indexOf(movedItem);
    if (currentIndex == -1) {
      return selectedIndex;
    }
    items.removeAt(currentIndex);

    String targetGroupId = mainGroupId;
    int insertItemIndex = items.length;

    if (rowsWithoutMovedItem.isEmpty) {
      targetGroupId = mainGroupId;
      insertItemIndex = _insertionIndexAtGroupEnd(
        groups: groups,
        items: items,
        groupId: targetGroupId,
        groupIdOf: groupIdOf,
        effectiveGroupIdOfItem: effectiveGroupIdOfItem,
      );
    } else if (targetRowIndex <= 0) {
      final GroupedListRow<G, I> firstRow = rowsWithoutMovedItem.first;
      targetGroupId = firstRow.groupId;
      if (firstRow.isItem) {
        final int targetItemIndex = items.indexOf(firstRow.item as I);
        insertItemIndex = targetItemIndex == -1
            ? _insertionIndexAtGroupStart(
                groups: groups,
                items: items,
                groupId: targetGroupId,
                groupIdOf: groupIdOf,
                effectiveGroupIdOfItem: effectiveGroupIdOfItem,
              )
            : targetItemIndex;
      } else {
        insertItemIndex = _insertionIndexAtGroupStart(
          groups: groups,
          items: items,
          groupId: targetGroupId,
          groupIdOf: groupIdOf,
          effectiveGroupIdOfItem: effectiveGroupIdOfItem,
        );
      }
    } else if (targetRowIndex >= rowsWithoutMovedItem.length) {
      final GroupedListRow<G, I> lastRow = rowsWithoutMovedItem.last;
      targetGroupId = lastRow.groupId;
      if (lastRow.isItem) {
        final int targetItemIndex = items.indexOf(lastRow.item as I);
        insertItemIndex = targetItemIndex == -1
            ? _insertionIndexAtGroupEnd(
                groups: groups,
                items: items,
                groupId: targetGroupId,
                groupIdOf: groupIdOf,
                effectiveGroupIdOfItem: effectiveGroupIdOfItem,
              )
            : targetItemIndex + 1;
      } else {
        insertItemIndex = _insertionIndexAtGroupEnd(
          groups: groups,
          items: items,
          groupId: targetGroupId,
          groupIdOf: groupIdOf,
          effectiveGroupIdOfItem: effectiveGroupIdOfItem,
        );
      }
    } else {
      final GroupedListRow<G, I> targetRow =
          rowsWithoutMovedItem[targetRowIndex];
      if (targetRow.isItem) {
        targetGroupId = targetRow.groupId;
        final int targetItemIndex = items.indexOf(targetRow.item as I);
        insertItemIndex = targetItemIndex == -1
            ? _insertionIndexAtGroupEnd(
                groups: groups,
                items: items,
                groupId: targetGroupId,
                groupIdOf: groupIdOf,
                effectiveGroupIdOfItem: effectiveGroupIdOfItem,
              )
            : targetItemIndex;
      } else {
        bool groupHasItems(String groupId) {
          return items.any((item) => effectiveGroupIdOfItem(item) == groupId);
        }

        targetGroupId = targetRow.groupId;
        final bool targetGroupHasItems = groupHasItems(targetGroupId);
        if (targetRowIndex > 0) {
          final GroupedListRow<G, I> previousRow =
              rowsWithoutMovedItem[targetRowIndex - 1];
          if (previousRow.isGroup && !groupHasItems(previousRow.groupId)) {
            targetGroupId = previousRow.groupId;
            insertItemIndex = _insertionIndexAtGroupStart(
              groups: groups,
              items: items,
              groupId: targetGroupId,
              groupIdOf: groupIdOf,
              effectiveGroupIdOfItem: effectiveGroupIdOfItem,
            );
          } else if (previousRow.isItem && targetGroupHasItems) {
            targetGroupId = previousRow.groupId;
            final int previousItemIndex = items.indexOf(previousRow.item as I);
            insertItemIndex = previousItemIndex == -1
                ? _insertionIndexAtGroupEnd(
                    groups: groups,
                    items: items,
                    groupId: targetGroupId,
                    groupIdOf: groupIdOf,
                    effectiveGroupIdOfItem: effectiveGroupIdOfItem,
                  )
                : previousItemIndex + 1;
          } else {
            insertItemIndex = _insertionIndexAtGroupStart(
              groups: groups,
              items: items,
              groupId: targetGroupId,
              groupIdOf: groupIdOf,
              effectiveGroupIdOfItem: effectiveGroupIdOfItem,
            );
          }
        } else {
          insertItemIndex = _insertionIndexAtGroupStart(
            groups: groups,
            items: items,
            groupId: targetGroupId,
            groupIdOf: groupIdOf,
            effectiveGroupIdOfItem: effectiveGroupIdOfItem,
          );
        }
      }
    }

    if (insertItemIndex < 0 || insertItemIndex > items.length) {
      insertItemIndex = items.length;
    }
    setItemGroupId(movedItem, targetGroupId);
    items.insert(insertItemIndex, movedItem);

    if (selectedItem == null) {
      return -1;
    }
    return items.indexOf(selectedItem);
  }
}

class GroupedListGroupDraft {
  const GroupedListGroupDraft({
    required this.id,
    required this.name,
    required this.collapsed,
  });

  final String id;
  final String name;
  final bool collapsed;

  GroupedListGroupDraft copyWith({
    String? id,
    String? name,
    bool? collapsed,
  }) {
    return GroupedListGroupDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      collapsed: collapsed ?? this.collapsed,
    );
  }
}

class GroupedListGroupsPopover extends StatefulWidget {
  const GroupedListGroupsPopover({
    super.key,
    required this.title,
    required this.itemCaption,
    required this.initialGroups,
    required this.itemCountsByGroup,
    required this.mainGroupId,
    required this.onCreateGroup,
    required this.onRenameGroup,
    required this.onDeleteGroup,
  });

  final String title;
  final String itemCaption;
  final List<GroupedListGroupDraft> initialGroups;
  final Map<String, int> itemCountsByGroup;
  final String mainGroupId;
  final Future<GroupedListGroupDraft?> Function(String name) onCreateGroup;
  final Future<bool> Function(String groupId, String name) onRenameGroup;
  final Future<bool> Function(String groupId) onDeleteGroup;

  @override
  State<GroupedListGroupsPopover> createState() =>
      _GroupedListGroupsPopoverState();
}

class _GroupedListGroupsPopoverState extends State<GroupedListGroupsPopover> {
  late final List<GroupedListGroupDraft> _groups = widget.initialGroups
      .map((group) => group.copyWith())
      .toList(growable: true);
  final TextEditingController _nameController = TextEditingController();
  String? _selectedGroupId;
  String? _nameError;
  bool _busy = false;

  GroupedListGroupDraft? get _selectedGroup {
    if (_selectedGroupId == null) {
      return null;
    }
    for (final group in _groups) {
      if (group.id == _selectedGroupId) {
        return group;
      }
    }
    return null;
  }

  bool _isDuplicatedName(String name, {String? excludingId}) {
    final String normalized = name.trim().toLowerCase();
    for (final group in _groups) {
      if (group.id == excludingId) {
        continue;
      }
      if (group.name.trim().toLowerCase() == normalized) {
        return true;
      }
    }
    return false;
  }

  void _selectGroup(GroupedListGroupDraft group) {
    setState(() {
      if (_selectedGroupId == group.id) {
        _selectedGroupId = null;
        _nameController.clear();
      } else {
        _selectedGroupId = group.id;
        _nameController.text = group.name;
      }
      _nameError = null;
    });
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }

    final String nextName = _nameController.text.trim();
    if (nextName.isEmpty) {
      setState(() {
        _nameError = 'Group name is required.';
      });
      return;
    }

    final GroupedListGroupDraft? selected = _selectedGroup;
    if (_isDuplicatedName(nextName, excludingId: selected?.id)) {
      setState(() {
        _nameError = 'A group with this name already exists.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _nameError = null;
    });

    if (selected == null) {
      final GroupedListGroupDraft? created =
          await widget.onCreateGroup(nextName);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        if (created == null) {
          _nameError = 'Could not add group.';
          return;
        }
        _groups.add(created);
        _selectedGroupId = null;
        _nameController.clear();
      });
      return;
    }

    final bool renamed = await widget.onRenameGroup(selected.id, nextName);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      if (!renamed) {
        _nameError = 'Could not update group.';
        return;
      }
      final int index = _groups.indexWhere((group) => group.id == selected.id);
      if (index != -1) {
        _groups[index] = _groups[index].copyWith(name: nextName);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final GroupedListGroupDraft? selected = _selectedGroup;
    if (_busy || selected == null || selected.id == widget.mainGroupId) {
      return;
    }

    setState(() {
      _busy = true;
      _nameError = null;
    });
    final bool deleted = await widget.onDeleteGroup(selected.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      if (!deleted) {
        _nameError = 'Could not delete group.';
        return;
      }
      _groups.removeWhere((group) => group.id == selected.id);
      _selectedGroupId = null;
      _nameController.clear();
    });
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
    final GroupedListGroupDraft? selected = _selectedGroup;
    final bool selectedIsMain = selected?.id == widget.mainGroupId;
    final bool isUpdateMode = selected != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 420, maxWidth: 480),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CDKText(widget.title, role: CDKTextRole.title),
            SizedBox(height: spacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _groups.length,
                itemBuilder: (context, index) {
                  final GroupedListGroupDraft group = _groups[index];
                  final bool isSelected = group.id == _selectedGroupId;
                  final int count = widget.itemCountsByGroup[group.id] ?? 0;
                  return GestureDetector(
                    onTap: () => _selectGroup(group),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      color: isSelected
                          ? CupertinoColors.systemBlue.withValues(alpha: 0.18)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CDKText(
                                      group.name,
                                      role: isSelected
                                          ? CDKTextRole.bodyStrong
                                          : CDKTextRole.body,
                                      color: cdkColors.colorText,
                                    ),
                                    if (group.id == widget.mainGroupId) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        CupertinoIcons.lock_fill,
                                        size: 12,
                                        color: cdkColors.colorText
                                            .withValues(alpha: 0.7),
                                      ),
                                      const SizedBox(width: 4),
                                      const CDKText(
                                        '(non-deletable)',
                                        role: CDKTextRole.caption,
                                        secondary: true,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                CDKText(
                                  '$count ${widget.itemCaption}',
                                  role: CDKTextRole.caption,
                                  secondary: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
              placeholder: 'Group name',
              controller: _nameController,
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() {
                    _nameError = null;
                  });
                }
              },
              onSubmitted: (_) => _submit(),
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
            SizedBox(
              height: 18,
              child: selectedIsMain
                  ? Row(
                      children: const [
                        Icon(
                          CupertinoIcons.lock_fill,
                          size: 11,
                        ),
                        SizedBox(width: 4),
                        CDKText(
                          'Main group is non-deletable.',
                          role: CDKTextRole.caption,
                          secondary: true,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(height: spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CDKButton(
                  style: CDKButtonStyle.normal,
                  enabled: selected != null && !selectedIsMain && !_busy,
                  onPressed: _deleteSelected,
                  child: const Text('Delete group'),
                ),
                CDKButton(
                  style: CDKButtonStyle.action,
                  enabled: !_busy,
                  onPressed: _submit,
                  child: Text(isUpdateMode ? 'Update group' : 'Add group'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
