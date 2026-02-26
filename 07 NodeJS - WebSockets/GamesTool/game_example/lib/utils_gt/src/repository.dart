import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'errors.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// GamesToolZoneTracker — runtime zone-entry/exit detection
// ---------------------------------------------------------------------------

/// Tracks whether a moving entity (e.g. the player) enters or exits
/// [GamesToolZone] rectangles at runtime.
///
/// Call [update] every frame with the entity's current world-space position.
/// The tracker fires [onEnter] / [onExit] callbacks whenever the set of
/// overlapping zones changes.
///
/// ```dart
/// final tracker = GamesToolZoneTracker(
///   zones: loadedLevel.zones,
///   onEnter: (zone) {
///     if (zone.type == 'Mur') blockMovement();
///     if (zone.type == 'Pont') allowBridgeCross();
///   },
///   onExit: (zone) => restoreNormalBehaviour(),
/// );
///
/// // In your game loop:
/// tracker.update(player.position.x.toInt(), player.position.y.toInt());
/// ```
class GamesToolZoneTracker {
  GamesToolZoneTracker({
    required List<GamesToolZone> zones,
    this.onEnter,
    this.onExit,
    this.onStay,
  }) : _zones = List<GamesToolZone>.unmodifiable(zones);

  final List<GamesToolZone> _zones;
  final Set<GamesToolZone> _active = {};

  /// Called when the entity enters a zone for the first time.
  final void Function(GamesToolZone zone)? onEnter;

  /// Called when the entity exits a zone it was previously inside.
  final void Function(GamesToolZone zone)? onExit;

  /// Called every [update] for each zone the entity is currently inside.
  final void Function(GamesToolZone zone)? onStay;

  /// The zones the entity is currently overlapping.
  Set<GamesToolZone> get activeZones => Set.unmodifiable(_active);

  bool get isInsideAnyZone => _active.isNotEmpty;

  /// Updates the tracker with the entity's world-space position.
  ///
  /// [width] / [height] describe the entity's own bounding box, so the
  /// check is rect–rect overlap rather than point–rect containment.
  void update(int x, int y, {int width = 1, int height = 1}) {
    final GamesToolRect entityRect = GamesToolRect(
      x: x,
      y: y,
      width: width,
      height: height,
    );

    final Set<GamesToolZone> nowInside = _zones
        .where((z) => z.bounds.overlaps(entityRect))
        .toSet();

    for (final GamesToolZone entered in nowInside.difference(_active)) {
      onEnter?.call(entered);
    }
    for (final GamesToolZone exited in _active.difference(nowInside)) {
      onExit?.call(exited);
    }
    for (final GamesToolZone staying in nowInside.intersection(_active)) {
      onStay?.call(staying);
    }

    _active
      ..clear()
      ..addAll(nowInside);
  }

  /// Resets all active zones without firing exit callbacks.
  void reset() => _active.clear();
}

// ---------------------------------------------------------------------------
// GamesToolLoadedLevel — a level with its associated zones data resolved
// ---------------------------------------------------------------------------

/// A [GamesToolLevel] with its [GamesToolZonesFile] already loaded, providing
/// a single object for all level-related game queries.
class GamesToolLoadedLevel {
  GamesToolLoadedLevel({
    required this.level,
    required this.levelIndex,
    required GamesToolZonesFile? zonesFile,
    required this.project,
  }) : _zonesFile = zonesFile;

  final GamesToolLevel level;
  final int levelIndex;
  final GamesToolProject project;
  final GamesToolZonesFile? _zonesFile;

  // ---- Zone access -------------------------------------------------------

  /// All zones in this level. Empty if no zones file was loaded.
  List<GamesToolZone> get zones => _zonesFile?.zones ?? const [];

  /// All zone groups defined for this level.
  List<GamesToolGroup> get zoneGroups => _zonesFile?.zoneGroups ?? const [];

  /// All zones whose [GamesToolZone.type] matches [typeName].
  ///
  /// Example: `loadedLevel.zonesOfType('Mur')` for collision walls.
  List<GamesToolZone> zonesOfType(String typeName) =>
      _zonesFile?.zonesOfType(typeName) ?? const [];

  /// All zones belonging to the zone group named [groupName].
  ///
  /// Use this to check only a semantically related subset of zones —
  /// e.g. only `"Llac gran"` water zones when swimming mechanics apply.
  List<GamesToolZone> zonesInGroup(String groupName) {
    final GamesToolGroup? group = zoneGroups
        .where((g) => g.name == groupName)
        .firstOrNull;
    if (group == null) return const [];
    return zones.where((z) => z.groupId == group.id).toList(growable: false);
  }

  /// All zones belonging to the zone group with [groupId].
  List<GamesToolZone> zonesInGroupById(String groupId) =>
      zones.where((z) => z.groupId == groupId).toList(growable: false);

  /// All zones overlapping the point ([px], [py]).
  List<GamesToolZone> zonesAt(int px, int py) =>
      _zonesFile?.zonesAt(px, py) ?? const [];

  /// All zones overlapping [rect].
  List<GamesToolZone> zonesOverlapping(GamesToolRect rect) =>
      _zonesFile?.zonesOverlapping(rect) ?? const [];

  // ---- Zone tracker factory ---------------------------------------------

  /// Creates a [GamesToolZoneTracker] scoped to all zones in this level.
  ///
  /// Optionally restrict to a specific zone [type] or [groupName] to avoid
  /// checking every zone each frame.
  ///
  /// ```dart
  /// final collisionTracker = loadedLevel.createZoneTracker(
  ///   type: 'Mur',
  ///   onEnter: (_) => player.blockMovement(),
  ///   onExit:  (_) => player.allowMovement(),
  /// );
  /// ```
  GamesToolZoneTracker createZoneTracker({
    String? type,
    String? groupName,
    void Function(GamesToolZone)? onEnter,
    void Function(GamesToolZone)? onExit,
    void Function(GamesToolZone)? onStay,
  }) {
    List<GamesToolZone> subset = zones;
    if (type != null) {
      subset = subset.where((z) => z.type == type).toList(growable: false);
    }
    if (groupName != null) {
      subset = zonesInGroup(groupName);
    }
    return GamesToolZoneTracker(
      zones: subset,
      onEnter: onEnter,
      onExit: onExit,
      onStay: onStay,
    );
  }

  // ---- Order manipulation ------------------------------------------------

  /// Reorders layers in-place using editor painter-order semantics.
  void moveLayer(int fromIndex, int toIndex) {
    level.moveLayer(fromIndex, toIndex);
  }

  /// Reorders sprites in-place using editor painter-order semantics.
  void moveSprite(int fromIndex, int toIndex) {
    level.moveSprite(fromIndex, toIndex);
  }

  /// Reorders zones in-place.
  ///
  /// Throws [StateError] if this level has no zones file loaded.
  void moveZone(int fromIndex, int toIndex) {
    final GamesToolZonesFile? zonesFile = _zonesFile;
    if (zonesFile == null) {
      throw StateError(
        'Cannot reorder zones: level "$name" has no zones file.',
      );
    }
    zonesFile.moveZone(fromIndex, toIndex);
  }

  // ---- Sprite convenience -----------------------------------------------

  /// All sprites in this level.
  List<GamesToolSprite> get sprites => level.sprites;

  /// Sprites whose [GamesToolSprite.type] matches [type].
  List<GamesToolSprite> spritesByType(String type) => level.spritesByType(type);

  /// All animated sprites in this level.
  List<GamesToolAnimatedSprite> get animatedSprites => level.animatedSprites;

  /// All static (image) sprites in this level.
  List<GamesToolStaticSprite> get staticSprites => level.staticSprites;

  // ---- Layer convenience ------------------------------------------------

  /// All layers in this level.
  List<GamesToolLayer> get layers => level.layers;

  /// Only visible layers, sorted by depth ascending.
  List<GamesToolLayer> get visibleLayers => level.visibleLayers;

  // ---- Metadata ---------------------------------------------------------

  String get name => level.name;
  String get description => level.description;
  int get viewportWidth => level.viewportWidth;
  int get viewportHeight => level.viewportHeight;
  int get viewportX => level.viewportX;
  int get viewportY => level.viewportY;
  String get backgroundColorHex => level.backgroundColorHex;

  @override
  String toString() =>
      'GamesToolLoadedLevel("${level.name}", index=$levelIndex, zones=${zones.length})';
}

// ---------------------------------------------------------------------------
// GamesToolLoadedProject — fully resolved project ready for game use
// ---------------------------------------------------------------------------

class GamesToolLoadedProject {
  GamesToolLoadedProject({
    required this.projectRoot,
    required this.project,
    required Map<String, GamesToolTileMapFile> tileMapsByRelativePath,
    required Map<String, GamesToolZonesFile> zonesByRelativePath,
    required Set<String> availableAssetPaths,
    required Set<String> missingMediaRelativePaths,
    required this.rawJson,
  }) : tileMapsByRelativePath = Map<String, GamesToolTileMapFile>.unmodifiable(
         tileMapsByRelativePath,
       ),
       zonesByRelativePath = Map<String, GamesToolZonesFile>.unmodifiable(
         zonesByRelativePath,
       ),
       availableAssetPaths = Set<String>.unmodifiable(availableAssetPaths),
       missingMediaRelativePaths = Set<String>.unmodifiable(
         missingMediaRelativePaths,
       );

  /// The asset path that was used to load this project (e.g.
  /// `"assets/exemple_0"`).
  final String projectRoot;

  final GamesToolProject project;
  final Map<String, GamesToolTileMapFile> tileMapsByRelativePath;
  final Map<String, GamesToolZonesFile> zonesByRelativePath;
  final Set<String> availableAssetPaths;
  final Set<String> missingMediaRelativePaths;

  /// The raw decoded JSON of `game_data.json`. Useful as an escape hatch when
  /// the typed model does not yet cover a field you need.
  final JsonMap rawJson;

  // ---- Level access -----------------------------------------------------

  /// Returns a [GamesToolLoadedLevel] for [levelIndex] with its zones
  /// already resolved.
  ///
  /// Throws [RangeError] for an out-of-range index.
  GamesToolLoadedLevel loadedLevel(int levelIndex) {
    final List<GamesToolLevel> levels = project.levels;
    RangeError.checkValidIndex(levelIndex, levels, 'levelIndex');
    final GamesToolLevel level = levels[levelIndex];
    return GamesToolLoadedLevel(
      level: level,
      levelIndex: levelIndex,
      zonesFile: zonesForLevel(level),
      project: project,
    );
  }

  /// All levels as [GamesToolLoadedLevel] objects.
  List<GamesToolLoadedLevel> get loadedLevels {
    return List.generate(project.levels.length, loadedLevel, growable: false);
  }

  // ---- Asset resolution -------------------------------------------------

  /// Resolves a project-relative [relativePath] to a full asset path
  /// suitable for loading via Flutter's `AssetBundle` or Flame's image cache.
  String resolveAssetPath(String relativePath) {
    final String normalized = normalizeGamesToolRelativePath(relativePath);
    if (normalized.isEmpty) {
      throw GamesToolProjectFormatException(
        'Invalid project-relative asset path: "$relativePath"',
      );
    }
    return '$projectRoot/$normalized';
  }

  bool containsAsset(String relativePath) {
    final String normalized = normalizeGamesToolRelativePath(relativePath);
    if (normalized.isEmpty) return false;
    return availableAssetPaths.contains('$projectRoot/$normalized');
  }

  // ---- Tilemap lookups --------------------------------------------------

  GamesToolTileMapFile? tileMapForLayer(GamesToolLayer layer) {
    final String key = normalizeGamesToolRelativePath(layer.tileMapFile);
    if (key.isEmpty) return null;
    return tileMapsByRelativePath[key];
  }

  // ---- Zone lookups -----------------------------------------------------

  GamesToolZonesFile? zonesForLevel(GamesToolLevel level) {
    final String key = normalizeGamesToolRelativePath(level.zonesFile);
    if (key.isEmpty) return null;
    return zonesByRelativePath[key];
  }

  // ---- Animation/media lookups ------------------------------------------

  /// Find an animation by ID. Returns `null` if not found.
  GamesToolAnimation? animationById(String id) => project.animationById(id);

  /// Find an animation by name. Returns `null` if not found.
  GamesToolAnimation? animationByName(String name) =>
      project.animationByName(name);

  /// Find the registered [GamesToolMediaAsset] for a project-relative file.
  GamesToolMediaAsset? mediaAssetByFileName(String relativeFileName) =>
      project.mediaAssetByFileName(relativeFileName);

  /// Find the [GamesToolMediaAsset] that backs a given layer's tileset.
  GamesToolMediaAsset? mediaAssetForLayer(GamesToolLayer layer) =>
      project.mediaAssetByFileName(layer.tilesSheetFile);

  /// Find a zone type by name (e.g. `"Mur"`, `"Aigua"`).
  GamesToolZoneType? zoneTypeByName(String name) =>
      project.zoneTypeByName(name);

  @override
  String toString() =>
      'GamesToolLoadedProject("${project.name}", root=$projectRoot)';
}

// ---------------------------------------------------------------------------
// GamesToolProjectRepository — loads projects from the Flutter asset bundle
// ---------------------------------------------------------------------------

class GamesToolProjectRepository {
  GamesToolProjectRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const String projectDescriptorFileName = 'game_data.json';

  final AssetBundle _bundle;

  /// Discovers all exported Games Tool projects under [assetsRoot].
  ///
  /// Returns a sorted list of project root paths (e.g.
  /// `["assets/exemple_0", "assets/exemple_1"]`).
  Future<List<String>> discoverProjectRoots({
    String assetsRoot = 'assets',
  }) async {
    final Set<String> assets = await _listAssetPaths();
    final String normalizedAssetsRoot = _normalizeAssetRoot(assetsRoot);
    final String prefix = '$normalizedAssetsRoot/';
    final String suffix = '/$projectDescriptorFileName';

    final List<String> roots =
        assets
            .where((p) => p.startsWith(prefix) && p.endsWith(suffix))
            .map((p) => p.substring(0, p.length - suffix.length))
            .toList(growable: false)
          ..sort();
    return roots;
  }

  /// Loads a Games Tool project from [projectRoot] in the asset bundle.
  ///
  /// Set [strict] to `false` to tolerate missing tilemap / media assets
  /// instead of throwing.
  Future<GamesToolLoadedProject> loadFromAssets({
    required String projectRoot,
    bool strict = true,
  }) async {
    final String normalizedProjectRoot = _normalizeAssetRoot(projectRoot);
    final Set<String> availableAssetPaths = await _listAssetPaths();

    final String descriptorPath =
        '$normalizedProjectRoot/$projectDescriptorFileName';
    final JsonMap descriptorJson = await _loadJsonMapAsset(descriptorPath);
    final GamesToolProject project = GamesToolProject.fromJson(descriptorJson);

    final Map<String, GamesToolTileMapFile> tileMapsByRelativePath =
        <String, GamesToolTileMapFile>{};
    for (final String relativePath
        in project.referencedTileMapRelativePaths()) {
      final String normalized = normalizeGamesToolRelativePath(relativePath);
      if (normalized.isEmpty) {
        if (strict) {
          throw GamesToolProjectFormatException(
            'Invalid tilemap reference in project: "$relativePath"',
          );
        }
        continue;
      }
      final String path = '$normalizedProjectRoot/$normalized';
      try {
        final JsonMap json = await _loadJsonMapAsset(path);
        tileMapsByRelativePath[normalized] = GamesToolTileMapFile.fromJson(
          json,
        );
      } catch (error) {
        if (strict) rethrow;
      }
    }

    final Map<String, GamesToolZonesFile> zonesByRelativePath =
        <String, GamesToolZonesFile>{};
    for (final String relativePath in project.referencedZonesRelativePaths()) {
      final String normalized = normalizeGamesToolRelativePath(relativePath);
      if (normalized.isEmpty) {
        if (strict) {
          throw GamesToolProjectFormatException(
            'Invalid zones reference in project: "$relativePath"',
          );
        }
        continue;
      }
      final String path = '$normalizedProjectRoot/$normalized';
      try {
        final JsonMap json = await _loadJsonMapAsset(path);
        zonesByRelativePath[normalized] = GamesToolZonesFile.fromJson(json);
      } catch (error) {
        if (strict) rethrow;
      }
    }

    final Set<String> missingMediaRelativePaths = <String>{};
    for (final String relativePath in project.referencedMediaRelativePaths()) {
      final String normalized = normalizeGamesToolRelativePath(relativePath);
      if (normalized.isEmpty) {
        if (strict) {
          throw GamesToolProjectFormatException(
            'Invalid media reference in project: "$relativePath"',
          );
        }
        continue;
      }
      final String path = '$normalizedProjectRoot/$normalized';
      if (!availableAssetPaths.contains(path)) {
        missingMediaRelativePaths.add(normalized);
      }
    }

    if (strict && missingMediaRelativePaths.isNotEmpty) {
      throw GamesToolProjectAssetNotFoundException(
        'Missing media assets: ${missingMediaRelativePaths.join(', ')}',
      );
    }

    return GamesToolLoadedProject(
      projectRoot: normalizedProjectRoot,
      project: project,
      tileMapsByRelativePath: tileMapsByRelativePath,
      zonesByRelativePath: zonesByRelativePath,
      availableAssetPaths: availableAssetPaths,
      missingMediaRelativePaths: missingMediaRelativePaths,
      rawJson: descriptorJson,
    );
  }

  Future<Set<String>> _listAssetPaths() async {
    try {
      final String manifestJson = await _bundle.loadString(
        'AssetManifest.json',
      );
      final dynamic decoded = jsonDecode(manifestJson);
      if (decoded is Map) {
        return decoded.keys.map((dynamic k) => k.toString()).toSet();
      }
    } catch (_) {}

    try {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
        _bundle,
      );
      return manifest.listAssets().toSet();
    } catch (_) {}

    return <String>{};
  }

  Future<JsonMap> _loadJsonMapAsset(String assetPath) async {
    try {
      final String raw = await _bundle.loadString(assetPath);
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
      }
      throw GamesToolProjectFormatException(
        'Expected JSON object in asset: $assetPath',
      );
    } on FlutterError catch (error) {
      throw GamesToolProjectAssetNotFoundException(
        'Asset not found: $assetPath',
        cause: error,
      );
    } on FormatException catch (error) {
      throw GamesToolProjectFormatException(
        'Invalid JSON in asset: $assetPath',
        cause: error,
      );
    }
  }

  String _normalizeAssetRoot(String value) {
    String normalized = value.trim().replaceAll('\\', '/');
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.isEmpty) {
      throw GamesToolProjectFormatException('Asset root cannot be empty.');
    }
    return normalized;
  }
}
