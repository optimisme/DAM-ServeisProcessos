import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';

import 'app_data.dart';
import 'widgets/editor_form_dialog_scaffold.dart';
import 'widgets/editor_labeled_field.dart';

class LayoutProjectsMain extends StatefulWidget {
  const LayoutProjectsMain({super.key});

  @override
  State<LayoutProjectsMain> createState() => _LayoutProjectsMainState();
}

class _LayoutProjectsMainState extends State<LayoutProjectsMain> {
  final GlobalKey _selectedEditAnchorKey = GlobalKey();

  Future<_ProjectDialogData?> _promptProjectData({
    required String title,
    required String confirmLabel,
    String initialName = '',
    String initialComments = '',
    String? editingProjectId,
    GlobalKey? anchorKey,
    bool useArrowedPopover = false,
    VoidCallback? onDelete,
  }) async {
    final AppData appData = Provider.of<AppData>(context, listen: false);
    final Set<String> existingNames = appData.projects
        .where((project) => project.id != editingProjectId)
        .map((project) => project.name.trim().toLowerCase())
        .toSet();
    final CDKDialogController controller = CDKDialogController();
    final Completer<_ProjectDialogData?> completer =
        Completer<_ProjectDialogData?>();
    _ProjectDialogData? result;

    final Widget dialogChild = _ProjectFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
      initialComments: initialComments,
      existingNames: existingNames,
      onConfirm: (value) {
        result = value;
        controller.close();
      },
      onCancel: controller.close,
      onDelete: onDelete == null
          ? null
          : () {
              controller.close();
              onDelete();
            },
    );

    if (useArrowedPopover &&
        anchorKey != null &&
        anchorKey.currentContext != null) {
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

  Future<void> _promptAndAddProject() async {
    final _ProjectDialogData? data = await _promptProjectData(
      title: "New empty project",
      confirmLabel: "Add",
    );
    if (data == null || !mounted) {
      return;
    }
    final AppData appData = Provider.of<AppData>(context, listen: false);
    await appData.createProject(
      projectName: data.name,
      projectComments: data.comments,
    );
  }

  Future<void> _promptAndEditProject(
    StoredProject project,
    GlobalKey anchorKey,
  ) async {
    final _ProjectDialogData? data = await _promptProjectData(
      title: "Edit project",
      confirmLabel: "Save",
      initialName: project.name,
      initialComments: project.comments,
      editingProjectId: project.id,
      anchorKey: anchorKey,
      useArrowedPopover: true,
      onDelete: () async {
        final bool confirmed = await _confirmDelete(context, project.name);
        if (!confirmed || !mounted) {
          return;
        }
        final AppData appData = Provider.of<AppData>(context, listen: false);
        await appData.deleteProject(project.id);
      },
    );
    if (data == null || !mounted) {
      return;
    }
    final AppData appData = Provider.of<AppData>(context, listen: false);
    await appData.updateProjectInfo(
      project.id,
      newName: data.name,
      comments: data.comments,
    );
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

  @override
  Widget build(BuildContext context) {
    final AppData appData = Provider.of<AppData>(context);
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
              onPressed: _promptAndAddProject,
              child: const Text('+ Add Project'),
            ),
          ],
        ),
      );
    }

    return Column(
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
                onPressed: _promptAndAddProject,
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
              final StoredProject project = appData.projects[index];
              final bool isSelected = project.id == appData.selectedProjectId;
              return GestureDetector(
                onTap: () async {
                  await appData.openProject(project.id);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          padding: EdgeInsets.only(right: isSelected ? 12 : 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CDKText(
                                project.name,
                                role: isSelected
                                    ? CDKTextRole.bodyStrong
                                    : CDKTextRole.body,
                                style: const TextStyle(fontSize: 18),
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
                            key: _selectedEditAnchorKey,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(20, 20),
                            onPressed: () async {
                              await _promptAndEditProject(
                                project,
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
    );
  }
}

class _ProjectDialogData {
  const _ProjectDialogData({
    required this.name,
    required this.comments,
  });

  final String name;
  final String comments;
}

class _ProjectFormDialog extends StatefulWidget {
  const _ProjectFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
    required this.initialComments,
    required this.existingNames,
    required this.onConfirm,
    required this.onCancel,
    this.onDelete,
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final String initialComments;
  final Set<String> existingNames;
  final ValueChanged<_ProjectDialogData> onConfirm;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _commentsController =
      TextEditingController(text: widget.initialComments);
  final FocusNode _nameFocusNode = FocusNode();
  String? _errorText;

  bool get _isValid {
    final String cleaned = _nameController.text.trim();
    return cleaned.isNotEmpty &&
        !widget.existingNames.contains(cleaned.toLowerCase());
  }

  void _validateName(String value) {
    final String cleaned = value.trim();
    String? error;
    if (cleaned.isEmpty) {
      error = 'Project name is required.';
    } else if (widget.existingNames.contains(cleaned.toLowerCase())) {
      error = 'Another project is named like that.';
    }
    setState(() {
      _errorText = error;
    });
  }

  void _confirm() {
    final String cleaned = _nameController.text.trim();
    _validateName(cleaned);
    if (!_isValid) {
      return;
    }
    widget.onConfirm(
      _ProjectDialogData(
        name: cleaned,
        comments: _commentsController.text,
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
    _commentsController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    return EditorFormDialogScaffold(
      title: widget.title,
      description: 'Set project name and optional comments.',
      confirmLabel: widget.confirmLabel,
      confirmEnabled: _isValid,
      onConfirm: _confirm,
      onCancel: widget.onCancel,
      onDelete: widget.onDelete,
      minWidth: 340,
      maxWidth: 460,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorLabeledField(
            label: 'Name',
            child: CDKFieldText(
              placeholder: 'Project name',
              controller: _nameController,
              focusNode: _nameFocusNode,
              onChanged: _validateName,
              onSubmitted: (_) => _confirm(),
            ),
          ),
          if (_errorText != null) ...[
            SizedBox(height: spacing.xs),
            CDKText(
              _errorText!,
              role: CDKTextRole.caption,
              color: CupertinoColors.systemRed,
            ),
          ],
          SizedBox(height: spacing.sm),
          EditorLabeledField(
            label: 'Comments',
            child: CupertinoTextField(
              controller: _commentsController,
              style: typography.body,
              placeholderStyle: typography.caption,
              minLines: 4,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
