import 'package:flutter/cupertino.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';

class LayoutProjectsMain extends StatefulWidget {
  const LayoutProjectsMain({super.key});

  @override
  State<LayoutProjectsMain> createState() => _LayoutProjectsMainState();
}

class _LayoutProjectsMainState extends State<LayoutProjectsMain> {
  final TextEditingController _nameEditorController = TextEditingController();
  final FocusNode _nameEditorFocusNode = FocusNode();
  String _editingProjectId = "";

  @override
  void initState() {
    super.initState();
    _nameEditorFocusNode.addListener(() async {
      if (!_nameEditorFocusNode.hasFocus) {
        await _commitRenameIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _nameEditorFocusNode.dispose();
    _nameEditorController.dispose();
    super.dispose();
  }

  Future<String?> _promptName({
    required BuildContext context,
    required String title,
  }) async {
    final appData = Provider.of<AppData>(context, listen: false);
    final String? result = await CDKDialogsManager.showPrompt(
      context: context,
      title: title,
      message: "Enter a project name.",
      placeholder: "Project name",
      confirmLabel: "OK",
      cancelLabel: "Cancel",
      validator: (value) {
        final String cleaned = value.trim();
        if (cleaned.isEmpty) {
          return null;
        }
        final bool duplicateName = appData.projects.any(
          (project) =>
              project.name.trim().toLowerCase() == cleaned.toLowerCase(),
        );
        if (duplicateName) {
          return "Another project is named like that.";
        }
        return null;
      },
    );
    final String? cleaned = result?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }
    return cleaned;
  }

  Future<bool> _confirmDelete(BuildContext context, String projectName) async {
    final bool? confirmed = await CDKDialogsManager.showConfirm(
      context: context,
      title: "Delete project",
      message: "Delete \"$projectName\" permanently?",
      confirmLabel: "Delete",
      cancelLabel: "Cancel",
      isDestructive: true,
      showBackgroundShade: true,
    );
    return confirmed ?? false;
  }

  String _formatLastModified(String updatedAtRaw) {
    final DateTime? parsed = DateTime.tryParse(updatedAtRaw);
    if (parsed == null) {
      return "Last modified: unknown";
    }
    final DateTime local = parsed.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final String date =
        "${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}";
    final String time = "${twoDigits(local.hour)}:${twoDigits(local.minute)}";
    return "Last modified: $date $time";
  }

  void _startEditingProject(StoredProject project) {
    setState(() {
      _editingProjectId = project.id;
      _nameEditorController.text = project.name;
      _nameEditorController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameEditorController.text.length,
      );
    });
    _nameEditorFocusNode.requestFocus();
  }

  Future<void> _commitRenameIfNeeded() async {
    if (_editingProjectId == "") {
      return;
    }

    final appData = Provider.of<AppData>(context, listen: false);
    StoredProject? project;
    for (final item in appData.projects) {
      if (item.id == _editingProjectId) {
        project = item;
        break;
      }
    }

    final String editedName = _nameEditorController.text.trim();
    if (project != null &&
        editedName.isNotEmpty &&
        editedName != project.name.trim()) {
      await appData.renameProject(project.id, editedName);
    }

    if (mounted) {
      setState(() {
        _editingProjectId = "";
      });
    }
  }

  Future<void> _toggleEditForProject(StoredProject project) async {
    if (_editingProjectId == project.id) {
      _nameEditorFocusNode.unfocus();
      await _commitRenameIfNeeded();
      return;
    }

    await _commitRenameIfNeeded();
    _startEditingProject(project);
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);

    if (!appData.storageReady) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (appData.projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CDKText(
              'No projects found.\nCreate a new empty project or import one.',
              textAlign: TextAlign.center,
              role: CDKTextRole.body,
              color: CupertinoColors.black,
            ),
            const SizedBox(height: 10),
            CDKButton(
              style: CDKButtonStyle.action,
              onPressed: () async {
                final String? name = await _promptName(
                  context: context,
                  title: "New empty project",
                );
                if (name != null) {
                  await appData.createProject(projectName: name);
                }
              },
              child: const Text('+ Add Project'),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        _nameEditorFocusNode.unfocus();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                CDKText(
                  'Projects',
                  role: CDKTextRole.title,
                  style: typography.title.copyWith(fontSize: 28),
                ),
                const Spacer(),
                CDKButton(
                  style: CDKButtonStyle.action,
                  onPressed: () async {
                    final String? name = await _promptName(
                      context: context,
                      title: "New empty project",
                    );
                    if (name != null) {
                      await appData.createProject(projectName: name);
                    }
                  },
                  child: const Text('+ Add Project'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: appData.projects.length,
              itemBuilder: (context, index) {
                final project = appData.projects[index];
                final bool isSelected = project.id == appData.selectedProjectId;
                final bool isEditing = _editingProjectId == project.id;
                return GestureDetector(
                  onTap: () async {
                    await _commitRenameIfNeeded();
                    await appData.openProject(project.id);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? CupertinoColors.systemBlue.withValues(alpha: 0.2)
                          : cdkColors.backgroundSecondary0,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? CupertinoColors.systemBlue
                            : CupertinoColors.systemGrey4,
                        width: isSelected ? 1.3 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding:
                                EdgeInsets.only(right: isSelected ? 12 : 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isEditing)
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 260),
                                    child: CupertinoTextField(
                                      controller: _nameEditorController,
                                      focusNode: _nameEditorFocusNode,
                                      style: typography.body,
                                      placeholderStyle: typography.caption,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      onSubmitted: (_) async {
                                        await _commitRenameIfNeeded();
                                      },
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () {
                                      _startEditingProject(project);
                                    },
                                    child: CDKText(
                                      project.name,
                                      role: isSelected
                                          ? CDKTextRole.bodyStrong
                                          : CDKTextRole.body,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                CDKText(
                                  _formatLastModified(project.updatedAt),
                                  role: CDKTextRole.caption,
                                  color: isSelected
                                      ? cdkColors.colorTextSecondary
                                      : cdkColors.colorText,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isSelected) ...[
                          const CDKText(
                            "Working project",
                            role: CDKTextRole.caption,
                            color: CupertinoColors.systemBlue,
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: CupertinoButton(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              minimumSize: const Size(20, 20),
                              onPressed: () async {
                                await _toggleEditForProject(project);
                              },
                              child: Icon(
                                CupertinoIcons.pencil,
                                size: 16,
                                color: isEditing
                                    ? CupertinoColors.systemBlue
                                    : cdkColors.colorText,
                              ),
                            ),
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: CupertinoButton(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              minimumSize: const Size(20, 20),
                              onPressed: () async {
                                final bool confirmed = await _confirmDelete(
                                  context,
                                  project.name,
                                );
                                if (confirmed) {
                                  await appData.deleteProject(project.id);
                                }
                              },
                              child: const Icon(
                                CupertinoIcons.trash,
                                size: 16,
                                color: CupertinoColors.label,
                              ),
                            ),
                          ),
                        ] else
                          const CDKText(
                            "Select",
                            role: CDKTextRole.caption,
                            secondary: true,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
