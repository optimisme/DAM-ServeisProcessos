typedef JsonMap = Map<String, dynamic>;

// ---------------------------------------------------------------------------
// Internal helpers — not exported in the public barrel
// ---------------------------------------------------------------------------

String _normalizeRelativePath(String value) {
  String normalized = value.trim().replaceAll('\\', '/');
  while (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  if (normalized.isEmpty) {
    return '';
  }
  final List<String> segments = normalized.split('/');
  for (final String segment in segments) {
    if (segment.isEmpty || segment == '.' || segment == '..') {
      return '';
    }
  }
  return segments.join('/');
}

// Public alias used by the flame loader — kept for compatibility.
String normalizeGamesToolRelativePath(String value) =>
    _normalizeRelativePath(value);

JsonMap _asJsonMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }
  return <String, dynamic>{};
}

List<JsonMap> _asJsonMapList(dynamic raw) {
  if (raw is! List) {
    return const <JsonMap>[];
  }
  return raw.whereType<Map>().map<JsonMap>(_asJsonMap).toList(growable: false);
}

List<List<int>> _asIntMatrix(dynamic raw) {
  if (raw is! List) {
    return const <List<int>>[];
  }
  return raw
      .whereType<List>()
      .map<List<int>>(
        (List row) => row
            .map<int>((dynamic v) => v is num ? v.toInt() : -1)
            .toList(growable: false),
      )
      .toList(growable: false);
}

String _readString(JsonMap json, String key, {String fallback = ''}) {
  final dynamic value = json[key];
  return value is String ? value : fallback;
}

int _readInt(JsonMap json, String key, {int fallback = 0}) {
  final dynamic value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

double _readDouble(JsonMap json, String key, {double fallback = 0}) {
  final dynamic value = json[key];
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return fallback;
}

bool _readBool(JsonMap json, String key, {bool fallback = false}) {
  final dynamic value = json[key];
  return value is bool ? value : fallback;
}

void _moveItemInPlace<T>(List<T> items, int fromIndex, int toIndex) {
  RangeError.checkValidIndex(fromIndex, items, 'fromIndex');
  RangeError.checkValidIndex(toIndex, items, 'toIndex');
  if (fromIndex == toIndex) return;

  final T moving = items[fromIndex];
  if (fromIndex < toIndex) {
    for (int i = fromIndex; i < toIndex; i++) {
      items[i] = items[i + 1];
    }
  } else {
    for (int i = fromIndex; i > toIndex; i--) {
      items[i] = items[i - 1];
    }
  }
  items[toIndex] = moving;
}

// ---------------------------------------------------------------------------
// GamesToolRect — lightweight axis-aligned bounding box
// ---------------------------------------------------------------------------

/// An immutable axis-aligned rectangle used throughout the library to
/// represent the world-space bounds of layers, sprites and zones.
///
/// Avoids a dependency on `dart:ui` or Flame in the pure-data layer.
class GamesToolRect {
  const GamesToolRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;

  int get right => x + width;
  int get bottom => y + height;
  bool get isEmpty => width <= 0 || height <= 0;

  /// Returns `true` when [other] overlaps this rectangle.
  bool overlaps(GamesToolRect other) {
    return x < other.right &&
        right > other.x &&
        y < other.bottom &&
        bottom > other.y;
  }

  /// Returns `true` when [px],[py] falls inside this rectangle.
  bool contains(int px, int py) {
    return px >= x && px < right && py >= y && py < bottom;
  }

  @override
  String toString() => 'GamesToolRect($x, $y, ${width}x$height)';
}

// ---------------------------------------------------------------------------
// GamesToolGroup — editor-only grouping, exposed for advanced consumers
// ---------------------------------------------------------------------------

class GamesToolGroup {
  const GamesToolGroup({
    required this.id,
    required this.name,
    required this.collapsed,
  });

  final String id;
  final String name;

  /// Whether the group was collapsed in the editor. Not relevant at runtime.
  final bool collapsed;

  factory GamesToolGroup.fromJson(JsonMap json) {
    return GamesToolGroup(
      id: _readString(json, 'id'),
      name: _readString(json, 'name'),
      collapsed: _readBool(json, 'collapsed'),
    );
  }

  @override
  String toString() => 'GamesToolGroup("$name")';
}

// ---------------------------------------------------------------------------
// GamesToolZoneType — a named category of zones defined in the project
// ---------------------------------------------------------------------------

class GamesToolZoneType {
  const GamesToolZoneType({required this.name, required this.color});

  /// The name used to tag zones of this type (e.g. `"Mur"`, `"Aigua"`).
  final String name;

  /// Editor colour hint (e.g. `"red"`, `"blue"`). Not a strict constraint.
  final String color;

  factory GamesToolZoneType.fromJson(JsonMap json) {
    return GamesToolZoneType(
      name: _readString(json, 'name'),
      color: _readString(json, 'color'),
    );
  }

  @override
  String toString() => 'GamesToolZoneType("$name")';
}

// ---------------------------------------------------------------------------
// GamesToolMediaAsset — a registered image / spritesheet in the project
// ---------------------------------------------------------------------------

/// Represents an image file registered in the project's media library.
///
/// For tilesets: [tileWidth] / [tileHeight] define the tile size.
/// For spritesheets: [tileWidth] / [tileHeight] define the frame size.
class GamesToolMediaAsset {
  const GamesToolMediaAsset({
    required this.name,
    required this.fileName,
    required this.mediaType,
    required this.tileWidth,
    required this.tileHeight,
    required this.selectionColorHex,
    required this.groupId,
  });

  final String name;

  /// Project-relative path to the image file (e.g. `"media/tileset.png"`).
  final String fileName;

  /// `"tileset"` or `"spritesheet"`.
  final String mediaType;

  bool get isTileset => mediaType == 'tileset';
  bool get isSpritesheet => mediaType == 'spritesheet';

  /// Tile/frame width in pixels.
  final int tileWidth;

  /// Tile/frame height in pixels.
  final int tileHeight;

  final String selectionColorHex;
  final String groupId;

  factory GamesToolMediaAsset.fromJson(JsonMap json) {
    return GamesToolMediaAsset(
      name: _readString(json, 'name'),
      fileName: _readString(json, 'fileName'),
      mediaType: _readString(json, 'mediaType'),
      tileWidth: _readInt(json, 'tileWidth'),
      tileHeight: _readInt(json, 'tileHeight'),
      selectionColorHex: _readString(json, 'selectionColorHex'),
      groupId: _readString(json, 'groupId'),
    );
  }

  @override
  String toString() => 'GamesToolMediaAsset("$name", $fileName)';
}

// ---------------------------------------------------------------------------
// GamesToolAnimation — a named frame range on a spritesheet
// ---------------------------------------------------------------------------

class GamesToolAnimation {
  const GamesToolAnimation({
    required this.id,
    required this.name,
    required this.mediaFile,
    required this.startFrame,
    required this.endFrame,
    required this.fps,
    required this.loop,
    required this.groupId,
  });

  final String id;
  final String name;

  /// Project-relative path to the spritesheet image.
  final String mediaFile;

  final int startFrame;
  final int endFrame;
  final double fps;
  final bool loop;
  final String groupId;

  /// Total number of frames in this animation clip.
  int get frameCount => (endFrame - startFrame).abs() + 1;

  factory GamesToolAnimation.fromJson(JsonMap json) {
    return GamesToolAnimation(
      id: _readString(json, 'id'),
      name: _readString(json, 'name'),
      mediaFile: _readString(json, 'mediaFile'),
      startFrame: _readInt(json, 'startFrame'),
      endFrame: _readInt(json, 'endFrame'),
      fps: _readDouble(json, 'fps', fallback: 1),
      loop: _readBool(json, 'loop', fallback: true),
      groupId: _readString(json, 'groupId'),
    );
  }

  @override
  String toString() =>
      'GamesToolAnimation("$name", frames $startFrame-$endFrame)';
}

// ---------------------------------------------------------------------------
// GamesToolLayer — a tile layer inside a level
// ---------------------------------------------------------------------------

class GamesToolLayer {
  const GamesToolLayer({
    required this.name,
    required this.x,
    required this.y,
    required this.depth,
    required this.tilesSheetFile,
    required this.tilesWidth,
    required this.tilesHeight,
    required this.visible,
    required this.groupId,
    required this.tileMapFile,
  });

  final String name;

  /// World-space origin of this layer in pixels.
  final int x;
  final int y;

  /// Render depth (lower values render behind higher ones).
  final double depth;

  /// Project-relative path to the tileset image.
  final String tilesSheetFile;

  /// Width of each individual tile in pixels.
  final int tilesWidth;

  /// Height of each individual tile in pixels.
  final int tilesHeight;

  final bool visible;
  final String groupId;

  /// Project-relative path to the tilemap JSON for this layer.
  final String tileMapFile;

  factory GamesToolLayer.fromJson(JsonMap json) {
    return GamesToolLayer(
      name: _readString(json, 'name'),
      x: _readInt(json, 'x'),
      y: _readInt(json, 'y'),
      depth: _readDouble(json, 'depth'),
      tilesSheetFile: _readString(json, 'tilesSheetFile'),
      tilesWidth: _readInt(json, 'tilesWidth'),
      tilesHeight: _readInt(json, 'tilesHeight'),
      visible: _readBool(json, 'visible', fallback: true),
      groupId: _readString(json, 'groupId'),
      tileMapFile: _readString(json, 'tileMapFile'),
    );
  }

  @override
  String toString() => 'GamesToolLayer("$name")';
}

// ---------------------------------------------------------------------------
// GamesToolSprite — sealed: either an animated or a static sprite
// ---------------------------------------------------------------------------

/// Base class for sprites placed in a level.
///
/// Use pattern matching to distinguish between the two variants:
///
/// ```dart
/// switch (sprite) {
///   case GamesToolAnimatedSprite s:
///     // s.animationId, s.animation (if loaded)
///   case GamesToolStaticSprite s:
///     // s.imageFile
/// }
/// ```
sealed class GamesToolSprite {
  const GamesToolSprite({
    required this.name,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.flipX,
    required this.flipY,
    required this.depth,
    required this.groupId,
  });

  final String name;

  /// Designer-assigned type tag (e.g. `"Hero"`, `"Enemy"`). Free-form string.
  final String type;

  final int x;
  final int y;
  final int width;
  final int height;
  final bool flipX;
  final bool flipY;

  /// Render depth (lower values render behind higher ones).
  final double depth;
  final String groupId;

  /// World-space bounds of this sprite.
  GamesToolRect get bounds =>
      GamesToolRect(x: x, y: y, width: width, height: height);

  factory GamesToolSprite.fromJson(JsonMap json) {
    final String animationId = _readString(json, 'animationId');
    final String name = _readString(json, 'name');
    final String type = _readString(json, 'type');
    final int x = _readInt(json, 'x');
    final int y = _readInt(json, 'y');
    final int width = _readInt(json, 'width');
    final int height = _readInt(json, 'height');
    final bool flipX = _readBool(json, 'flipX');
    final bool flipY = _readBool(json, 'flipY');
    final double depth = _readDouble(json, 'depth');
    final String groupId = _readString(json, 'groupId');

    if (animationId.isNotEmpty) {
      return GamesToolAnimatedSprite(
        name: name,
        type: type,
        animationId: animationId,
        x: x,
        y: y,
        width: width,
        height: height,
        flipX: flipX,
        flipY: flipY,
        depth: depth,
        groupId: groupId,
      );
    }

    return GamesToolStaticSprite(
      name: name,
      type: type,
      imageFile: _readString(json, 'imageFile'),
      x: x,
      y: y,
      width: width,
      height: height,
      flipX: flipX,
      flipY: flipY,
      depth: depth,
      groupId: groupId,
    );
  }

  @override
  String toString() => 'GamesToolSprite("$name", type=$type)';
}

/// A sprite that plays a named animation from the project's animation library.
final class GamesToolAnimatedSprite extends GamesToolSprite {
  const GamesToolAnimatedSprite({
    required super.name,
    required super.type,
    required this.animationId,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.flipX,
    required super.flipY,
    required super.depth,
    required super.groupId,
  });

  /// ID referencing a [GamesToolAnimation] in the project.
  final String animationId;

  @override
  String toString() => 'GamesToolAnimatedSprite("$name", anim=$animationId)';
}

/// A sprite that displays a static image file.
final class GamesToolStaticSprite extends GamesToolSprite {
  const GamesToolStaticSprite({
    required super.name,
    required super.type,
    required this.imageFile,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.flipX,
    required super.flipY,
    required super.depth,
    required super.groupId,
  });

  /// Project-relative path to the image file.
  final String imageFile;

  @override
  String toString() => 'GamesToolStaticSprite("$name", $imageFile)';
}

// ---------------------------------------------------------------------------
// GamesToolZone — a named rectangular region in a level
// ---------------------------------------------------------------------------

class GamesToolZone {
  const GamesToolZone({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
    required this.groupId,
  });

  /// Zone type name matching a [GamesToolZoneType.name] in the project.
  final String type;

  final int x;
  final int y;
  final int width;
  final int height;

  /// Editor colour hint. Use [GamesToolProject.zoneTypeByName] to get the
  /// full [GamesToolZoneType] for this zone.
  final String color;
  final String groupId;

  /// World-space bounds of this zone.
  GamesToolRect get bounds =>
      GamesToolRect(x: x, y: y, width: width, height: height);

  factory GamesToolZone.fromJson(JsonMap json) {
    return GamesToolZone(
      type: _readString(json, 'type'),
      x: _readInt(json, 'x'),
      y: _readInt(json, 'y'),
      width: _readInt(json, 'width'),
      height: _readInt(json, 'height'),
      color: _readString(json, 'color'),
      groupId: _readString(json, 'groupId'),
    );
  }

  @override
  String toString() => 'GamesToolZone(type=$type, $bounds)';
}

// ---------------------------------------------------------------------------
// GamesToolZonesFile — the deserialized content of a zones JSON file
// ---------------------------------------------------------------------------

class GamesToolZonesFile {
  const GamesToolZonesFile({required this.zoneGroups, required this.zones});

  final List<GamesToolGroup> zoneGroups;
  final List<GamesToolZone> zones;

  /// Reorders a zone in-place.
  ///
  /// Later zones in the list are typically considered visually on top in editor
  /// tooling, so changing this order can alter draw precedence.
  void moveZone(int fromIndex, int toIndex) {
    _moveItemInPlace(zones, fromIndex, toIndex);
  }

  /// Reorders a zone group in-place.
  void moveZoneGroup(int fromIndex, int toIndex) {
    _moveItemInPlace(zoneGroups, fromIndex, toIndex);
  }

  /// Returns all zones whose [GamesToolZone.type] matches [typeName].
  List<GamesToolZone> zonesOfType(String typeName) =>
      zones.where((z) => z.type == typeName).toList(growable: false);

  /// Returns all zones whose bounds overlap the given point.
  List<GamesToolZone> zonesAt(int px, int py) =>
      zones.where((z) => z.bounds.contains(px, py)).toList(growable: false);

  /// Returns all zones whose bounds overlap [rect].
  List<GamesToolZone> zonesOverlapping(GamesToolRect rect) =>
      zones.where((z) => z.bounds.overlaps(rect)).toList(growable: false);

  factory GamesToolZonesFile.fromJson(JsonMap json) {
    return GamesToolZonesFile(
      zoneGroups: _asJsonMapList(
        json['zoneGroups'],
      ).map(GamesToolGroup.fromJson).toList(growable: false),
      zones: _asJsonMapList(
        json['zones'],
      ).map(GamesToolZone.fromJson).toList(growable: false),
    );
  }
}

// ---------------------------------------------------------------------------
// GamesToolTileMapFile — a 2-D grid of tile indices
// ---------------------------------------------------------------------------

/// The deserialized tilemap for a single layer.
///
/// Tile indices are 0-based references into the tileset image.
/// Empty cells have the value `-1`.
class GamesToolTileMapFile {
  GamesToolTileMapFile({required this.tileMap})
    : _placedTileCount = tileMap
          .expand((row) => row)
          .where((v) => v >= 0)
          .length;

  final List<List<int>> tileMap;
  final int _placedTileCount;

  int get rowCount => tileMap.length;
  int get columnCount => tileMap.isEmpty ? 0 : tileMap.first.length;

  bool get isEmpty => _placedTileCount == 0;

  /// Number of cells that contain an actual tile (value >= 0).
  int get placedTileCount => _placedTileCount;

  /// Returns the tile index at ([row], [col]), or `-1` for an empty cell.
  /// Returns `-1` for out-of-bounds coordinates instead of throwing.
  int tileAt(int row, int col) {
    if (row < 0 || row >= rowCount) return -1;
    final List<int> r = tileMap[row];
    if (col < 0 || col >= r.length) return -1;
    return r[col];
  }

  /// Returns `true` if the cell at ([row], [col]) contains a tile.
  bool hasTileAt(int row, int col) => tileAt(row, col) >= 0;

  /// Returns every (row, col) pair that contains [tileIndex].
  List<(int row, int col)> findTile(int tileIndex) {
    final List<(int, int)> result = <(int, int)>[];
    for (int r = 0; r < rowCount; r++) {
      final List<int> row = tileMap[r];
      for (int c = 0; c < row.length; c++) {
        if (row[c] == tileIndex) result.add((r, c));
      }
    }
    return result;
  }

  factory GamesToolTileMapFile.fromJson(JsonMap json) {
    return GamesToolTileMapFile(tileMap: _asIntMatrix(json['tileMap']));
  }
}

// ---------------------------------------------------------------------------
// GamesToolLevel — a single level / map
// ---------------------------------------------------------------------------

class GamesToolLevel {
  GamesToolLevel({
    required this.name,
    required this.description,
    required this.layers,
    required this.layerGroups,
    required this.sprites,
    required this.spriteGroups,
    required this.groupId,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.viewportX,
    required this.viewportY,
    required this.viewportAdaptation,
    required this.backgroundColorHex,
    required this.zonesFile,
  });

  final String name;
  final String description;
  final List<GamesToolLayer> layers;
  final List<GamesToolGroup> layerGroups;
  final List<GamesToolSprite> sprites;
  final List<GamesToolGroup> spriteGroups;
  final String groupId;

  /// Viewport width in pixels for this level.
  final int viewportWidth;

  /// Viewport height in pixels for this level.
  final int viewportHeight;

  /// Viewport initial X position in world space.
  final int viewportX;

  /// Viewport initial Y position in world space.
  final int viewportY;

  /// Viewport scaling strategy (e.g. `"letterbox"`).
  final String viewportAdaptation;

  /// Background colour as a 6-digit hex string (e.g. `"#DCDCE1"`).
  final String backgroundColorHex;

  /// Project-relative path to the zones JSON for this level.
  final String zonesFile;

  /// Reorders a layer in-place.
  ///
  /// Layer list order is the canonical painter order used by the editor and
  /// Flame loader. Move items here to change visual stacking.
  void moveLayer(int fromIndex, int toIndex) {
    _moveItemInPlace(layers, fromIndex, toIndex);
  }

  /// Reorders a sprite in-place.
  ///
  /// Sprite list order is the canonical painter order used by the editor and
  /// Flame loader. Move items here to change visual stacking.
  void moveSprite(int fromIndex, int toIndex) {
    _moveItemInPlace(sprites, fromIndex, toIndex);
  }

  /// Reorders a layer group in-place.
  void moveLayerGroup(int fromIndex, int toIndex) {
    _moveItemInPlace(layerGroups, fromIndex, toIndex);
  }

  /// Reorders a sprite group in-place.
  void moveSpriteGroup(int fromIndex, int toIndex) {
    _moveItemInPlace(spriteGroups, fromIndex, toIndex);
  }

  // ---- Sprite convenience -----------------------------------------------

  /// All sprites of the given designer [type] tag.
  List<GamesToolSprite> spritesByType(String type) =>
      sprites.where((s) => s.type == type).toList(growable: false);

  /// All animated sprites in this level.
  List<GamesToolAnimatedSprite> get animatedSprites =>
      sprites.whereType<GamesToolAnimatedSprite>().toList(growable: false);

  /// All static (non-animated) sprites in this level.
  List<GamesToolStaticSprite> get staticSprites =>
      sprites.whereType<GamesToolStaticSprite>().toList(growable: false);

  // ---- Layer convenience ------------------------------------------------

  /// Only the visible layers, sorted by depth ascending.
  List<GamesToolLayer> get visibleLayers {
    final List<GamesToolLayer> result = layers.where((l) => l.visible).toList();
    result.sort((a, b) => a.depth.compareTo(b.depth));
    return result;
  }

  // ---- Internal helpers -------------------------------------------------

  String _normalizedZonesFile() => _normalizeRelativePath(zonesFile);

  Set<String> _referencedMediaRelativePaths() {
    final Set<String> refs = <String>{};
    for (final GamesToolLayer layer in layers) {
      final String n = _normalizeRelativePath(layer.tilesSheetFile);
      if (n.isNotEmpty) refs.add(n);
    }
    for (final GamesToolSprite sprite in sprites) {
      if (sprite is GamesToolStaticSprite) {
        final String n = _normalizeRelativePath(sprite.imageFile);
        if (n.isNotEmpty) refs.add(n);
      }
    }
    return refs;
  }

  Set<String> _referencedTileMapRelativePaths() {
    final Set<String> refs = <String>{};
    for (final GamesToolLayer layer in layers) {
      final String n = _normalizeRelativePath(layer.tileMapFile);
      if (n.isNotEmpty) refs.add(n);
    }
    return refs;
  }

  factory GamesToolLevel.fromJson(JsonMap json) {
    return GamesToolLevel(
      name: _readString(json, 'name'),
      description: _readString(json, 'description'),
      layers: _asJsonMapList(
        json['layers'],
      ).map(GamesToolLayer.fromJson).toList(growable: false),
      layerGroups: _asJsonMapList(
        json['layerGroups'],
      ).map(GamesToolGroup.fromJson).toList(growable: false),
      sprites: _asJsonMapList(
        json['sprites'],
      ).map(GamesToolSprite.fromJson).toList(growable: false),
      spriteGroups: _asJsonMapList(
        json['spriteGroups'],
      ).map(GamesToolGroup.fromJson).toList(growable: false),
      groupId: _readString(json, 'groupId'),
      viewportWidth: _readInt(json, 'viewportWidth', fallback: 320),
      viewportHeight: _readInt(json, 'viewportHeight', fallback: 180),
      viewportX: _readInt(json, 'viewportX'),
      viewportY: _readInt(json, 'viewportY'),
      viewportAdaptation: _readString(json, 'viewportAdaptation'),
      backgroundColorHex: _readString(json, 'backgroundColorHex'),
      zonesFile: _readString(json, 'zonesFile'),
    );
  }

  @override
  String toString() => 'GamesToolLevel("$name")';
}

// ---------------------------------------------------------------------------
// GamesToolProject — the top-level project descriptor (game_data.json)
// ---------------------------------------------------------------------------

class GamesToolProject {
  GamesToolProject({
    required this.name,
    required this.projectComments,
    required this.levels,
    required this.levelGroups,
    required this.mediaAssets,
    required this.mediaGroups,
    required this.animations,
    required this.animationGroups,
    required this.zoneTypes,
  }) : _animationsById = {for (final a in animations) a.id: a},
       _animationsByName = {for (final a in animations) a.name: a},
       _mediaAssetsByFileName = {
         for (final m in mediaAssets) _normalizeRelativePath(m.fileName): m,
       },
       _zoneTypesByName = {for (final z in zoneTypes) z.name: z};

  final String name;
  final String projectComments;
  final List<GamesToolLevel> levels;
  final List<GamesToolGroup> levelGroups;
  final List<GamesToolMediaAsset> mediaAssets;
  final List<GamesToolGroup> mediaGroups;
  final List<GamesToolAnimation> animations;
  final List<GamesToolGroup> animationGroups;
  final List<GamesToolZoneType> zoneTypes;

  final Map<String, GamesToolAnimation> _animationsById;
  final Map<String, GamesToolAnimation> _animationsByName;
  final Map<String, GamesToolMediaAsset> _mediaAssetsByFileName;
  final Map<String, GamesToolZoneType> _zoneTypesByName;

  // ---- Animation lookups ------------------------------------------------

  /// Find an animation by its unique ID. Returns `null` if not found.
  GamesToolAnimation? animationById(String id) => _animationsById[id];

  /// Find an animation by its designer name. Returns `null` if not found.
  GamesToolAnimation? animationByName(String name) => _animationsByName[name];

  // ---- Media asset lookups ----------------------------------------------

  /// Find the media asset registered for [relativeFileName].
  ///
  /// [relativeFileName] is a project-relative path such as
  /// `"media/tileset.png"`.
  GamesToolMediaAsset? mediaAssetByFileName(String relativeFileName) {
    return _mediaAssetsByFileName[_normalizeRelativePath(relativeFileName)];
  }

  // ---- Zone type lookups ------------------------------------------------

  /// Find a zone type by its name (e.g. `"Mur"`, `"Aigua"`).
  GamesToolZoneType? zoneTypeByName(String name) => _zoneTypesByName[name];

  // ---- Internal helpers (used by repository) ----------------------------

  Set<String> referencedMediaRelativePaths() {
    final Set<String> refs = <String>{};
    for (final GamesToolMediaAsset m in mediaAssets) {
      final String n = _normalizeRelativePath(m.fileName);
      if (n.isNotEmpty) refs.add(n);
    }
    for (final GamesToolAnimation a in animations) {
      final String n = _normalizeRelativePath(a.mediaFile);
      if (n.isNotEmpty) refs.add(n);
    }
    for (final GamesToolLevel level in levels) {
      refs.addAll(level._referencedMediaRelativePaths());
    }
    return refs;
  }

  Set<String> referencedTileMapRelativePaths() {
    final Set<String> refs = <String>{};
    for (final GamesToolLevel level in levels) {
      refs.addAll(level._referencedTileMapRelativePaths());
    }
    return refs;
  }

  Set<String> referencedZonesRelativePaths() {
    final Set<String> refs = <String>{};
    for (final GamesToolLevel level in levels) {
      final String n = level._normalizedZonesFile();
      if (n.isNotEmpty) refs.add(n);
    }
    return refs;
  }

  factory GamesToolProject.fromJson(JsonMap json) {
    return GamesToolProject(
      name: _readString(json, 'name'),
      projectComments: _readString(json, 'projectComments'),
      levels: _asJsonMapList(
        json['levels'],
      ).map(GamesToolLevel.fromJson).toList(growable: false),
      levelGroups: _asJsonMapList(
        json['levelGroups'],
      ).map(GamesToolGroup.fromJson).toList(growable: false),
      mediaAssets: _asJsonMapList(
        json['mediaAssets'],
      ).map(GamesToolMediaAsset.fromJson).toList(growable: false),
      mediaGroups: _asJsonMapList(
        json['mediaGroups'],
      ).map(GamesToolGroup.fromJson).toList(growable: false),
      animations: _asJsonMapList(
        json['animations'],
      ).map(GamesToolAnimation.fromJson).toList(growable: false),
      animationGroups: _asJsonMapList(
        json['animationGroups'],
      ).map(GamesToolGroup.fromJson).toList(growable: false),
      zoneTypes: _asJsonMapList(
        json['zoneTypes'],
      ).map(GamesToolZoneType.fromJson).toList(growable: false),
    );
  }

  @override
  String toString() => 'GamesToolProject("$name", ${levels.length} levels)';
}
