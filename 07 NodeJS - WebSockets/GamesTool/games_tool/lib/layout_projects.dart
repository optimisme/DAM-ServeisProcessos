import 'package:flutter/cupertino.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';

class LayoutProjects extends StatelessWidget {
  const LayoutProjects({super.key});

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
                  await appData.exportSelectedProjectToFolder();
                }
              : null,
        ),
      ],
    );
  }
}
