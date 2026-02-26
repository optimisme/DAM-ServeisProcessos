import 'package:flutter/material.dart';
import 'package:game_example/utils_gt/utils_gt.dart';

/// A simple level-select menu that lists all available Games Tool projects
/// and their levels over a black background.
///
/// Tapping a level calls [onLevelSelected] with the screen's [BuildContext],
/// the resolved project root, and the level index so the parent can navigate
/// to the game screen using the correct navigator.
class LevelMenuScreen extends StatefulWidget {
  const LevelMenuScreen({
    super.key,
    required this.onLevelSelected,
    this.assetsRoot = 'assets',
  });

  /// Called when the user selects a level.
  /// [context] is the menu screen's own context, safe for `Navigator.of`.
  final void Function(
    BuildContext context,
    String projectRoot,
    int levelIndex,
  ) onLevelSelected;

  /// Root directory to search for exported projects (default: `'assets'`).
  final String assetsRoot;

  @override
  State<LevelMenuScreen> createState() => _LevelMenuScreenState();
}

class _LevelMenuScreenState extends State<LevelMenuScreen> {
  late final Future<List<_ProjectEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadProjects();
  }

  Future<List<_ProjectEntry>> _loadProjects() async {
    final GamesToolProjectRepository repo = GamesToolProjectRepository();
    final List<String> roots = await repo.discoverProjectRoots(
      assetsRoot: widget.assetsRoot,
    );

    final List<_ProjectEntry> entries = <_ProjectEntry>[];
    for (final String root in roots) {
      try {
        final GamesToolLoadedProject loaded = await repo.loadFromAssets(
          projectRoot: root,
          strict: false,
        );
        entries.add(_ProjectEntry(root: root, loaded: loaded));
      } catch (_) {
        // Skip projects that fail to load.
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Games Tool',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<_ProjectEntry>>(
        future: _future,
        builder: (BuildContext ctx, AsyncSnapshot<List<_ProjectEntry>> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snap.hasError) {
            return Center(
              child: Text(
                'Error loading projects:\n${snap.error}',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            );
          }

          final List<_ProjectEntry> projects = snap.data ?? <_ProjectEntry>[];
          if (projects.isEmpty) {
            return const Center(
              child: Text(
                'No Games Tool projects found.\n'
                'Export a project and add it to the assets folder.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (BuildContext ctx2, int projectIndex) {
              final _ProjectEntry entry = projects[projectIndex];
              final GamesToolProject project = entry.loaded.project;
              return _ProjectSection(
                project: project,
                onLevelTap: (int levelIndex) =>
                    widget.onLevelSelected(ctx2, entry.root, levelIndex),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal widgets
// ---------------------------------------------------------------------------

class _ProjectSection extends StatelessWidget {
  const _ProjectSection({
    required this.project,
    required this.onLevelTap,
  });

  final GamesToolProject project;
  final void Function(int levelIndex) onLevelTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            project.name.isNotEmpty ? project.name : '(unnamed project)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        ...project.levels.indexed.map(
          (e) => _LevelTile(
            level: e.$2,
            levelIndex: e.$1,
            onTap: () => onLevelTap(e.$1),
          ),
        ),
      ],
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.levelIndex,
    required this.onTap,
  });

  final GamesToolLevel level;
  final int levelIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String title =
        level.name.isNotEmpty ? level.name : 'Level $levelIndex';
    final String subtitle =
        '${level.viewportWidth} × ${level.viewportHeight}  •  '
        '${level.layers.length} layer${level.layers.length == 1 ? '' : 's'}  •  '
        '${level.sprites.length} sprite${level.sprites.length == 1 ? '' : 's'}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
      trailing: const Icon(Icons.play_arrow, color: Colors.white54),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Data holder
// ---------------------------------------------------------------------------

class _ProjectEntry {
  _ProjectEntry({required this.root, required this.loaded});
  final String root;
  final GamesToolLoadedProject loaded;
}
