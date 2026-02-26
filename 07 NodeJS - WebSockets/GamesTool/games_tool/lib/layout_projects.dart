import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';

class LayoutProjects extends StatefulWidget {
  const LayoutProjects({super.key});

  @override
  State<LayoutProjects> createState() => _LayoutProjectsState();
}

class _LayoutProjectsState extends State<LayoutProjects> {
  Future<bool> _confirmOverwriteExportFiles({
    required BuildContext context,
    required String destinationFolderPath,
    required List<String> conflictingRelativePaths,
  }) async {
    if (Overlay.maybeOf(context) == null) {
      final bool? confirmed = await CDKDialogsManager.showConfirm(
        context: context,
        title: "Overwrite existing files?",
        message:
            "Some files already exist in:\n$destinationFolderPath\n\nOverwrite all exported files?",
        confirmLabel: "Overwrite all",
        cancelLabel: "Cancel",
        isDestructive: true,
        showBackgroundShade: true,
      );
      return confirmed ?? false;
    }

    final int count = conflictingRelativePaths.length;
    final List<String> preview = conflictingRelativePaths.take(4).toList();
    final CDKDialogController controller = CDKDialogController();
    bool overwrite = false;
    final Future<bool> result = (() async {
      final Completer<bool> completer = Completer<bool>();
      CDKDialogsManager.showModal(
        context: context,
        dismissOnEscape: true,
        dismissOnOutsideTap: false,
        showBackgroundShade: true,
        controller: controller,
        onHide: () {
          if (!completer.isCompleted) {
            completer.complete(overwrite);
          }
        },
        child: _ExportOverwritePopover(
          destinationFolderPath: destinationFolderPath,
          conflictingRelativePaths: preview,
          conflictCount: count,
          onCancel: controller.close,
          onConfirm: () {
            overwrite = true;
            controller.close();
          },
        ),
      );
      return completer.future;
    })();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final bool hasSelectedProject = appData.selectedProject != null;

    if (!appData.storageReady) {
      return const Center(child: CupertinoActivityIndicator());
    }

    Widget sectionCard({
      required String title,
      required String description,
      required String buttonLabel,
      required VoidCallback? onPressed,
    }) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cdkColors.backgroundSecondary0,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CupertinoColors.systemGrey4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CDKText(
              title,
              role: CDKTextRole.bodyStrong,
              color: CupertinoColors.black,
            ),
            const SizedBox(height: 4),
            CDKText(
              description,
              role: CDKTextRole.caption,
              color: CupertinoColors.black,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: CDKButton(
                style: CDKButtonStyle.action,
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionCard(
          title: "Import ZIP",
          description:
              "Select a .zip file containing a project. The archive is extracted into local storage and added to the Projects list.",
          buttonLabel: "Import ZIP",
          onPressed: () async {
            await appData.importProject();
          },
        ),
        sectionCard(
          title: "Export ZIP",
          description:
              "Create a .zip archive from the selected project in the main area and save it wherever you choose.",
          buttonLabel: "Export ZIP",
          onPressed: hasSelectedProject
              ? () async {
                  await appData.exportSelectedProject();
                }
              : null,
        ),
        sectionCard(
          title: "Export to folder",
          description:
              "Copy the selected project to a folder you choose, keeping files uncompressed and preserving the project structure.",
          buttonLabel: "Export to folder",
          onPressed: hasSelectedProject
              ? () async {
                  await appData.exportSelectedProjectToFolder(
                    confirmOverwrite: ({
                      required String destinationFolderPath,
                      required List<String> conflictingRelativePaths,
                    }) {
                      return _confirmOverwriteExportFiles(
                        context: context,
                        destinationFolderPath: destinationFolderPath,
                        conflictingRelativePaths: conflictingRelativePaths,
                      );
                    },
                  );
                }
              : null,
        ),
      ],
    );
  }
}

class _ExportOverwritePopover extends StatelessWidget {
  const _ExportOverwritePopover({
    required this.destinationFolderPath,
    required this.conflictingRelativePaths,
    required this.conflictCount,
    required this.onCancel,
    required this.onConfirm,
  });

  final String destinationFolderPath;
  final List<String> conflictingRelativePaths;
  final int conflictCount;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    final String listPreview = conflictingRelativePaths.join('\n');
    final bool hasMore = conflictCount > conflictingRelativePaths.length;
    final String moreText = hasMore
        ? '\n...and ${conflictCount - conflictingRelativePaths.length} more.'
        : '';
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 440),
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CDKText(
              'Overwrite existing files?',
              role: CDKTextRole.bodyStrong,
            ),
            SizedBox(height: spacing.md),
            CDKText(
              '$conflictCount file${conflictCount == 1 ? '' : 's'} already exist in:\n$destinationFolderPath',
              role: CDKTextRole.body,
            ),
            SizedBox(height: spacing.md),
            const CDKText(
              'Overwrite all exported files?',
              role: CDKTextRole.body,
            ),
            if (listPreview.isNotEmpty) ...<Widget>[
              SizedBox(height: spacing.sm),
              CDKText('$listPreview$moreText', role: CDKTextRole.caption),
            ],
            SizedBox(height: spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CDKButton(
                  style: CDKButtonStyle.normal,
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
                SizedBox(width: spacing.sm),
                CDKButton(
                  style: CDKButtonStyle.destructive,
                  onPressed: onConfirm,
                  child: const Text('Overwrite all'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
