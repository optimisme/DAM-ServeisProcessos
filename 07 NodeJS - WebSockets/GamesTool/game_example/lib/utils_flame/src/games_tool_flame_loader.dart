import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:game_example/utils_gt/utils_gt.dart';

import 'parallax_tile_layer_component.dart';
import 'viewport_adapter.dart';

// ---------------------------------------------------------------------------
// Top-level animation builder — shared by loader and sprite handles
// ---------------------------------------------------------------------------

SpriteAnimation _buildAnimation({
  required Image image,
  required int startFrame,
  required int endFrame,
  required double fps,
  required bool loop,
  required int frameWidth,
  required int frameHeight,
}) {
  final int fw = frameWidth <= 0 ? 1 : frameWidth;
  final int fh = frameHeight <= 0 ? 1 : frameHeight;
  final int columns = math.max(1, image.width ~/ fw);
  final int start = math.min(startFrame, endFrame);
  final int end = math.max(startFrame, endFrame);
  final double stepTime = fps <= 0 ? 0.1 : 1 / fps;

  final List<Sprite> sprites = <Sprite>[];
  for (int frame = start; frame <= end; frame++) {
    final int row = frame ~/ columns;
    final int col = frame % columns;
    final double srcX = (col * fw).toDouble();
    final double srcY = (row * fh).toDouble();
    if (srcX + fw > image.width || srcY + fh > image.height) continue;
    sprites.add(
      Sprite(
        image,
        srcPosition: Vector2(srcX, srcY),
        srcSize: Vector2(fw.toDouble(), fh.toDouble()),
      ),
    );
  }

  if (sprites.isEmpty) sprites.add(Sprite(image));
  return SpriteAnimation.spriteList(sprites, stepTime: stepTime, loop: loop);
}

// ---------------------------------------------------------------------------
// GamesToolSpriteHandle — runtime control over a mounted sprite
// ---------------------------------------------------------------------------

/// Gives game code full control over a sprite that was mounted into the world.
///
/// Obtain handles from [GamesToolFlameMountResult.spriteHandles] after calling
/// [GamesToolFlameLoader.mountLevel].
///
/// ```dart
/// final hero = result.spriteHandles
///     .firstWhere((h) => h.sprite.name == 'Hero');
///
/// // Play a different animation:
/// await hero.playAnimation(result.loadedProject.animationByName('Heroi Camina Dreta')!);
///
/// // Pause mid-animation:
/// hero.pause();
///
/// // Seek to a specific frame:
/// hero.seekToFrame(3);
///
/// // Resume:
/// hero.resume();
/// ```
class GamesToolSpriteHandle {
  GamesToolSpriteHandle._animated({
    required GamesToolAnimatedSprite sprite,
    required SpriteAnimationComponent component,
    required this.loadedProject,
  }) : sprite = sprite, // ignore: prefer_initializing_formals
       _animComponent = component,
       _staticComponent = null;

  GamesToolSpriteHandle._static({
    required GamesToolStaticSprite sprite,
    required SpriteComponent component,
    required this.loadedProject,
  }) : sprite = sprite, // ignore: prefer_initializing_formals
       _animComponent = null,
       _staticComponent = component;

  /// The Games Tool sprite data this handle refers to.
  final GamesToolSprite sprite;
  final GamesToolLoadedProject loadedProject;

  final SpriteAnimationComponent? _animComponent;
  final SpriteComponent? _staticComponent;

  /// The underlying Flame component placed in the world.
  PositionComponent get component =>
      (_animComponent ?? _staticComponent) as PositionComponent;

  // ---- Visibility --------------------------------------------------------

  /// Whether this sprite is currently visible.
  /// Setting to `false` makes the component fully transparent.
  bool get isVisible {
    if (_animComponent != null) return _animComponent.opacity > 0;
    if (_staticComponent != null) return _staticComponent.opacity > 0;
    return true;
  }

  set isVisible(bool value) {
    final double opacity = value ? 1.0 : 0.0;
    _animComponent?.setOpacity(opacity);
    _staticComponent?.setOpacity(opacity);
  }

  // ---- Position / transform ----------------------------------------------

  Vector2 get position => component.position;
  set position(Vector2 value) => component.position = value;

  Vector2 get size => component.size;

  // ---- Animation control -------------------------------------------------

  /// Pauses the animation at the current frame. No-op for static sprites.
  void pause() {
    _animComponent?.animationTicker?.paused = true;
  }

  /// Resumes a paused animation. No-op for static sprites.
  void resume() {
    _animComponent?.animationTicker?.paused = false;
  }

  /// Whether the animation is currently paused.
  bool get isPaused => _animComponent?.animationTicker?.isPaused ?? false;

  /// Whether this handle wraps an animated sprite.
  bool get isAnimated => _animComponent != null;

  /// Restarts the animation from frame 0. No-op for static sprites.
  void restart() {
    final ticker = _animComponent?.animationTicker;
    if (ticker == null) return;
    ticker.reset();
  }

  /// Jumps to [frameIndex] (0-based within the current animation clip).
  /// No-op for static sprites or out-of-range indices.
  void seekToFrame(int frameIndex) {
    final ticker = _animComponent?.animationTicker;
    if (ticker == null) return;
    final int total = ticker.spriteAnimation.frames.length;
    if (frameIndex < 0 || frameIndex >= total) return;
    ticker.currentIndex = frameIndex;
    ticker.clock = 0;
    ticker.elapsed = 0;
  }

  /// Replaces the current animation with [animation] from the project,
  /// loading the spritesheet image if not already cached.
  ///
  /// The [game] reference is required to access the image cache.
  ///
  /// ```dart
  /// await hero.playAnimation(
  ///   project.animationByName('Heroi Camina Dreta')!,
  ///   game,
  /// );
  /// ```
  Future<void> playAnimation(
    GamesToolAnimation animation,
    FlameGame game, {
    bool resetOnPlay = true,
  }) async {
    final ac = _animComponent;
    if (ac == null) return;

    final GamesToolMediaAsset? mediaAsset = loadedProject.mediaAssetByFileName(
      animation.mediaFile,
    );
    final int frameWidth = mediaAsset?.tileWidth ?? size.x.toInt();
    final int frameHeight = mediaAsset?.tileHeight ?? size.y.toInt();

    final String previousPrefix = game.images.prefix;
    game.images.prefix = '';
    final Image image;
    try {
      image = await game.images.load(
        loadedProject.resolveAssetPath(animation.mediaFile),
      );
    } finally {
      game.images.prefix = previousPrefix;
    }

    ac.animation = _buildAnimation(
      image: image,
      startFrame: animation.startFrame,
      endFrame: animation.endFrame,
      fps: animation.fps,
      loop: animation.loop,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
    );
    if (resetOnPlay) ac.animationTicker?.reset();
    ac.animationTicker?.paused = false;
  }
}

// ---------------------------------------------------------------------------
// GamesToolFlameMountResult — result of mounting a level into a FlameGame
// ---------------------------------------------------------------------------

class GamesToolFlameMountResult {
  GamesToolFlameMountResult({
    required this.loadedProject,
    required this.loadedLevel,
    required this.worldBounds,
    required this.spriteHandles,
    required this.viewportMode,
    required this.viewportOrigin,
  });

  final GamesToolLoadedProject loadedProject;

  /// The fully-resolved level including zones.
  final GamesToolLoadedLevel loadedLevel;

  /// World-space bounding box covering all rendered content.
  final Rect worldBounds;

  /// One handle per visible sprite in the level, in depth order.
  /// Use these to control animations, visibility, and position at runtime.
  final List<GamesToolSpriteHandle> spriteHandles;

  /// The viewport adaptation mode that was applied (resolved from game data
  /// when [GamesToolViewportMode.fromGameData] was requested).
  final GamesToolViewportMode viewportMode;

  /// The initial camera world-space position set when the level was mounted.
  /// Equal to the viewport centre from the level design.
  /// Use this as a reference point for parallax calculations and to restore
  /// the camera after panning.
  final Vector2 viewportOrigin;

  // Convenience delegates --------------------------------------------------

  GamesToolLevel get level => loadedLevel.level;
  int get levelIndex => loadedLevel.levelIndex;

  /// Find a sprite handle by the sprite's designer name.
  GamesToolSpriteHandle? handleForSpriteName(String name) =>
      spriteHandles.where((h) => h.sprite.name == name).firstOrNull;

  /// All handles whose sprite [GamesToolSprite.type] matches [type].
  List<GamesToolSpriteHandle> handlesForSpriteType(String type) =>
      spriteHandles.where((h) => h.sprite.type == type).toList(growable: false);

  /// Creates a [GamesToolZoneTracker] for a subset of zones in this level.
  ///
  /// See [GamesToolLoadedLevel.createZoneTracker] for full documentation.
  GamesToolZoneTracker createZoneTracker({
    String? type,
    String? groupName,
    void Function(GamesToolZone)? onEnter,
    void Function(GamesToolZone)? onExit,
    void Function(GamesToolZone)? onStay,
  }) => loadedLevel.createZoneTracker(
    type: type,
    groupName: groupName,
    onEnter: onEnter,
    onExit: onExit,
    onStay: onStay,
  );
}

// ---------------------------------------------------------------------------
// Project-root resolution helpers
// ---------------------------------------------------------------------------

class GamesToolProjectRootResolution {
  GamesToolProjectRootResolution({
    required this.resolvedRoot,
    required this.availableRoots,
    required this.usedFallback,
    required this.requestedRoot,
  });

  final String resolvedRoot;
  final List<String> availableRoots;
  final bool usedFallback;
  final String? requestedRoot;
}

// ---------------------------------------------------------------------------
// GamesToolFlameLoader — main entry point for Flame integration
// ---------------------------------------------------------------------------

class GamesToolFlameLoader {
  GamesToolFlameLoader({GamesToolProjectRepository? repository})
    : _repository = repository ?? GamesToolProjectRepository();

  final GamesToolProjectRepository _repository;

  // ---- Discovery ---------------------------------------------------------

  Future<List<String>> discoverProjectRoots({String assetsRoot = 'assets'}) =>
      _repository.discoverProjectRoots(assetsRoot: assetsRoot);

  Future<GamesToolProjectRootResolution> resolveProjectRoot({
    String? preferredRoot,
    String assetsRoot = 'assets',
  }) async {
    final List<String> roots = await _safeDiscoverProjectRoots(
      assetsRoot: assetsRoot,
    );

    final String? requested = preferredRoot?.trim();
    if (requested == null || requested.isEmpty) {
      if (roots.isEmpty) {
        throw GamesToolProjectAssetNotFoundException(
          'No exported Games Tool projects found under "$assetsRoot".',
        );
      }
      return GamesToolProjectRootResolution(
        resolvedRoot: roots.first,
        availableRoots: roots,
        usedFallback: false,
        requestedRoot: preferredRoot,
      );
    }

    final String normalizedRequested = _normalizeAssetPath(requested);
    final List<String> requestedCandidates = _candidateProjectRoots(
      normalizedRequested,
    );
    if (roots.isEmpty) {
      return GamesToolProjectRootResolution(
        resolvedRoot: requestedCandidates.first,
        availableRoots: roots,
        usedFallback: requestedCandidates.first != normalizedRequested,
        requestedRoot: preferredRoot,
      );
    }

    for (final String root in roots) {
      final String normalizedRoot = _normalizeAssetPath(root);
      if (requestedCandidates.contains(normalizedRoot)) {
        return GamesToolProjectRootResolution(
          resolvedRoot: root,
          availableRoots: roots,
          usedFallback: normalizedRoot != normalizedRequested,
          requestedRoot: preferredRoot,
        );
      }
    }

    for (final String root in roots) {
      if (_normalizeAssetPath(root).toLowerCase() ==
          normalizedRequested.toLowerCase()) {
        return GamesToolProjectRootResolution(
          resolvedRoot: root,
          availableRoots: roots,
          usedFallback: false,
          requestedRoot: preferredRoot,
        );
      }
    }

    final String requestedLeafNoVowels = normalizedRequested
        .split('/')
        .last
        .toLowerCase()
        .replaceAll(RegExp(r'[aeiou]'), '');
    for (final String root in roots) {
      final String rootLeafNoVowels = _normalizeAssetPath(
        root,
      ).split('/').last.toLowerCase().replaceAll(RegExp(r'[aeiou]'), '');
      if (rootLeafNoVowels == requestedLeafNoVowels) {
        return GamesToolProjectRootResolution(
          resolvedRoot: root,
          availableRoots: roots,
          usedFallback: true,
          requestedRoot: preferredRoot,
        );
      }
    }

    return GamesToolProjectRootResolution(
      resolvedRoot: roots.first,
      availableRoots: roots,
      usedFallback: true,
      requestedRoot: preferredRoot,
    );
  }

  // ---- High-level mount --------------------------------------------------

  /// Loads the project from [projectRoot] and mounts [levelIndex] into [game].
  ///
  /// This is the one-call entry point for most games:
  /// ```dart
  /// final result = await loader.mountLevel(
  ///   game: this,
  ///   projectRoot: 'assets/exemple_0',
  ///   levelIndex: 0,
  /// );
  /// final hero = result.handleForSpriteName('Hero')!;
  /// hero.playAnimation(result.loadedProject.animationByName('Heroi Camina Dreta')!, this);
  /// ```
  /// Loads the project from [projectRoot] and mounts [levelIndex] into [game].
  ///
  /// [viewportMode] controls how the design resolution is mapped to the screen.
  /// Defaults to [GamesToolViewportMode.fromGameData], which reads the
  /// `viewportAdaptation` field from the exported project.
  Future<GamesToolFlameMountResult> mountLevel({
    required FlameGame game,
    required String projectRoot,
    int levelIndex = 0,
    bool strict = true,
    GamesToolViewportMode viewportMode = GamesToolViewportMode.fromGameData,
  }) async {
    final List<String> candidates = <String>[
      ..._candidateProjectRoots(projectRoot),
      ...(await _safeDiscoverProjectRoots()),
    ];

    final Set<String> attempted = <String>{};
    Object? lastError;
    for (final String candidate in candidates) {
      final String normalized = _normalizeAssetPath(candidate);
      if (normalized.isEmpty || attempted.contains(normalized)) continue;
      attempted.add(normalized);
      try {
        final GamesToolLoadedProject loadedProject = await _repository
            .loadFromAssets(projectRoot: normalized, strict: strict);
        return _mountLoadedLevel(
          game: game,
          loadedProject: loadedProject,
          levelIndex: levelIndex,
          strict: strict,
          viewportMode: viewportMode,
        );
      } catch (error) {
        lastError = error;
      }
    }

    throw GamesToolProjectAssetNotFoundException(
      'Unable to load Games Tool project. Attempted roots: ${attempted.join(', ')}',
      cause: lastError,
    );
  }

  /// Mounts [levelIndex] from an already-loaded [loadedProject] into [game].
  ///
  /// Use this when you want to load the project once and switch levels
  /// without reloading assets from disk.
  Future<GamesToolFlameMountResult> mountLoadedLevel({
    required FlameGame game,
    required GamesToolLoadedProject loadedProject,
    int levelIndex = 0,
    bool strict = true,
    GamesToolViewportMode viewportMode = GamesToolViewportMode.fromGameData,
  }) async {
    return _mountLoadedLevel(
      game: game,
      loadedProject: loadedProject,
      levelIndex: levelIndex,
      strict: strict,
      viewportMode: viewportMode,
    );
  }

  // ---- Internal mount ----------------------------------------------------

  Future<GamesToolFlameMountResult> _mountLoadedLevel({
    required FlameGame game,
    required GamesToolLoadedProject loadedProject,
    int levelIndex = 0,
    bool strict = true,
    GamesToolViewportMode viewportMode = GamesToolViewportMode.fromGameData,
  }) async {
    final String previousPrefix = game.images.prefix;
    game.images.prefix = '';
    try {
      final List<GamesToolLevel> levels = loadedProject.project.levels;
      if (levelIndex < 0 || levelIndex >= levels.length) {
        throw GamesToolProjectFormatException(
          'Invalid level index $levelIndex. '
          'Available levels: ${levels.length}.',
        );
      }

      final GamesToolLoadedLevel loadedLevel = loadedProject.loadedLevel(
        levelIndex,
      );
      final GamesToolLevel level = loadedLevel.level;

      // Camera world-space centre as designed by the level editor.
      final Vector2 viewportOrigin = Vector2(
        level.viewportX.toDouble() + level.viewportWidth.toDouble() / 2,
        level.viewportY.toDouble() + level.viewportHeight.toDouble() / 2,
      );

      final World world = World();
      game.world = world;

      Size screenSize = Size.zero;
      if (game.hasLayout) {
        final Vector2 gameSize = game.size;
        if (gameSize.x > 0 && gameSize.y > 0) {
          screenSize = Size(gameSize.x, gameSize.y);
        }
      }

      final (
        CameraComponent camera,
        GamesToolViewportMode resolvedMode,
      ) = buildCamera(
        level: level,
        world: world,
        mode: viewportMode,
        screenSize: screenSize,
      );
      game.camera = camera;

      final (
        Rect worldBounds,
        List<GamesToolSpriteHandle> handles,
      ) = await _buildLevelWorld(
        game: game,
        world: world,
        loadedProject: loadedProject,
        loadedLevel: loadedLevel,
        viewportOrigin: viewportOrigin,
        strict: strict,
      );

      await _applyBackground(
        world: world,
        level: level,
        worldBounds: worldBounds,
      );

      camera.viewfinder.position = viewportOrigin;

      return GamesToolFlameMountResult(
        loadedProject: loadedProject,
        loadedLevel: loadedLevel,
        worldBounds: worldBounds,
        spriteHandles: handles,
        viewportMode: resolvedMode,
        viewportOrigin: viewportOrigin,
      );
    } finally {
      game.images.prefix = previousPrefix;
    }
  }

  Future<(Rect, List<GamesToolSpriteHandle>)> _buildLevelWorld({
    required FlameGame game,
    required World world,
    required GamesToolLoadedProject loadedProject,
    required GamesToolLoadedLevel loadedLevel,
    required Vector2 viewportOrigin,
    required bool strict,
  }) async {
    final GamesToolLevel level = loadedLevel.level;
    Rect? worldBounds;

    // ---- Tile layers -------------------------------------------------------
    // Painter algorithm: matches the games_tool editor (canvas_painter.dart).
    // The editor iterates layers from last index → 0, so index 0 is drawn last
    // (on top). We reproduce this by assigning priorities in reverse:
    //   index 0 → highest priority (drawn on top)
    //   last index → lowest priority (drawn at bottom)
    // Depth only affects the parallax scroll speed, NOT the paint order.
    final int layerCount = level.layers.length;
    for (int layerIndex = 0; layerIndex < layerCount; layerIndex++) {
      final GamesToolLayer layer = level.layers[layerIndex];
      if (!layer.visible) continue;

      final GamesToolTileMapFile? tileMap = loadedProject.tileMapForLayer(
        layer,
      );
      if (tileMap == null) {
        if (strict) {
          throw GamesToolProjectAssetNotFoundException(
            'Missing tilemap for layer "${layer.name}" '
            'at "${layer.tileMapFile}".',
          );
        }
        continue;
      }

      if (!loadedProject.containsAsset(layer.tilesSheetFile)) {
        if (strict) {
          throw GamesToolProjectAssetNotFoundException(
            'Missing tileset image for layer "${layer.name}" '
            'at "${layer.tilesSheetFile}".',
          );
        }
        continue;
      }

      final String atlasPath = loadedProject.resolveAssetPath(
        layer.tilesSheetFile,
      );
      final Image? atlas = await _loadImageAsset(
        game: game,
        assetPath: atlasPath,
        strict: strict,
        errorContext: 'tileset image for layer "${layer.name}"',
      );
      if (atlas == null) {
        continue;
      }

      // Reverse priority: index 0 gets (layerCount - 1), last index gets 0.
      final int priority = layerCount - 1 - layerIndex;
      final ParallaxTileLayerComponent tileLayerComponent =
          ParallaxTileLayerComponent(
            atlas: atlas,
            tileMap: tileMap.tileMap,
            tileWidth: layer.tilesWidth,
            tileHeight: layer.tilesHeight,
            baseX: layer.x.toDouble(),
            baseY: layer.y.toDouble(),
            depth: layer.depth.toDouble(),
            viewportOrigin: viewportOrigin,
            priority: priority,
          );
      await world.add(tileLayerComponent);
      worldBounds = _unionRects(worldBounds, tileLayerComponent.worldBounds);

      if (tileLayerComponent.worldBounds.isEmpty && strict) {
        throw GamesToolProjectFormatException(
          'Layer #$layerIndex ("${layer.name}") has an empty tilemap '
          'or invalid tile size.',
        );
      }
    }

    // ---- Sprites (list order from editor) ---------------------------------
    // Editor draws sprites in declaration order (index 0 first, last index on
    // top). We mirror that exactly by assigning increasing priorities.
    const int spriteBasePriority = 50000;
    final List<GamesToolSpriteHandle> handles = <GamesToolSpriteHandle>[];

    for (
      int spriteIndex = 0;
      spriteIndex < level.sprites.length;
      spriteIndex++
    ) {
      final GamesToolSprite sprite = level.sprites[spriteIndex];
      final GamesToolSpriteHandle? handle = await _buildSpriteHandle(
        game: game,
        loadedProject: loadedProject,
        sprite: sprite,
        priority: spriteBasePriority + spriteIndex,
        strict: strict,
      );
      if (handle == null) continue;

      await world.add(handle.component);
      worldBounds = _unionRects(worldBounds, handle.component.toRect());
      handles.add(handle);
    }

    worldBounds ??= Rect.fromLTWH(
      level.viewportX.toDouble(),
      level.viewportY.toDouble(),
      _safeViewportDimension(level.viewportWidth, fallback: 320),
      _safeViewportDimension(level.viewportHeight, fallback: 180),
    );

    return (worldBounds, handles);
  }

  Future<void> _applyBackground({
    required World world,
    required GamesToolLevel level,
    required Rect worldBounds,
  }) async {
    final Color color = _parseHexColor(
      level.backgroundColorHex,
      const Color(0xFF1E1E1E),
    );
    await world.add(
      RectangleComponent(
        position: Vector2(worldBounds.left, worldBounds.top),
        size: Vector2(worldBounds.width, worldBounds.height),
        priority: -100000,
        paint: Paint()..color = color,
      ),
    );
  }

  Future<GamesToolSpriteHandle?> _buildSpriteHandle({
    required FlameGame game,
    required GamesToolLoadedProject loadedProject,
    required GamesToolSprite sprite,
    required int priority,
    required bool strict,
  }) async {
    switch (sprite) {
      case GamesToolAnimatedSprite():
        final GamesToolAnimation? animation = loadedProject.animationById(
          sprite.animationId,
        );
        if (animation == null) {
          if (strict) {
            throw GamesToolProjectFormatException(
              'Animation "${sprite.animationId}" not found '
              'for sprite "${sprite.name}".',
            );
          }
          return null;
        }

        final String mediaPath = normalizeGamesToolRelativePath(
          animation.mediaFile,
        );
        if (mediaPath.isEmpty) {
          if (strict) {
            throw GamesToolProjectFormatException(
              'Invalid animation media path: "${animation.mediaFile}"',
            );
          }
          return null;
        }

        final GamesToolMediaAsset? mediaAsset = loadedProject
            .mediaAssetByFileName(mediaPath);
        final int frameWidth = mediaAsset?.tileWidth ?? sprite.width;
        final int frameHeight = mediaAsset?.tileHeight ?? sprite.height;

        if (!loadedProject.containsAsset(mediaPath)) {
          if (strict) {
            throw GamesToolProjectAssetNotFoundException(
              'Missing animation spritesheet for sprite "${sprite.name}" '
              'at "${animation.mediaFile}".',
            );
          }
          return null;
        }

        final Image? image = await _loadImageAsset(
          game: game,
          assetPath: loadedProject.resolveAssetPath(mediaPath),
          strict: strict,
          errorContext: 'animation spritesheet for sprite "${sprite.name}"',
        );
        if (image == null) {
          return null;
        }
        final SpriteAnimationComponent component = SpriteAnimationComponent(
          animation: _buildAnimation(
            image: image,
            startFrame: animation.startFrame,
            endFrame: animation.endFrame,
            fps: animation.fps,
            loop: animation.loop,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
          ),
          position: Vector2(sprite.x.toDouble(), sprite.y.toDouble()),
          size: Vector2(sprite.width.toDouble(), sprite.height.toDouble()),
          anchor: Anchor.topLeft,
          priority: priority,
        );
        _applyFlip(component, sprite.flipX, sprite.flipY);
        return GamesToolSpriteHandle._animated(
          sprite: sprite,
          component: component,
          loadedProject: loadedProject,
        );

      case GamesToolStaticSprite():
        final String imageRelPath = normalizeGamesToolRelativePath(
          sprite.imageFile,
        );
        if (imageRelPath.isEmpty) {
          if (strict) {
            throw GamesToolProjectFormatException(
              'Invalid sprite image path: "${sprite.imageFile}"',
            );
          }
          return null;
        }

        if (!loadedProject.containsAsset(imageRelPath)) {
          if (strict) {
            throw GamesToolProjectAssetNotFoundException(
              'Missing image for sprite "${sprite.name}" '
              'at "${sprite.imageFile}".',
            );
          }
          return null;
        }

        final Image? image = await _loadImageAsset(
          game: game,
          assetPath: loadedProject.resolveAssetPath(imageRelPath),
          strict: strict,
          errorContext: 'image for sprite "${sprite.name}"',
        );
        if (image == null) {
          return null;
        }
        final SpriteComponent component = SpriteComponent(
          sprite: Sprite(image),
          position: Vector2(sprite.x.toDouble(), sprite.y.toDouble()),
          size: Vector2(sprite.width.toDouble(), sprite.height.toDouble()),
          anchor: Anchor.topLeft,
          priority: priority,
        );
        _applyFlip(component, sprite.flipX, sprite.flipY);
        return GamesToolSpriteHandle._static(
          sprite: sprite,
          component: component,
          loadedProject: loadedProject,
        );
    }
  }

  void _applyFlip(PositionComponent c, bool flipX, bool flipY) {
    if (flipX) {
      c.scale.x = -c.scale.x;
      c.position.x += c.size.x;
    }
    if (flipY) {
      c.scale.y = -c.scale.y;
      c.position.y += c.size.y;
    }
  }

  Rect _unionRects(Rect? a, Rect b) {
    if (a == null) return b;
    return Rect.fromLTRB(
      math.min(a.left, b.left),
      math.min(a.top, b.top),
      math.max(a.right, b.right),
      math.max(a.bottom, b.bottom),
    );
  }

  double _safeViewportDimension(int value, {required double fallback}) =>
      value <= 0 ? fallback : value.toDouble();

  Color _parseHexColor(String raw, Color fallback) {
    final String normalized = raw.trim().replaceFirst('#', '');
    if (normalized.length != 6) return fallback;
    final int? rgb = int.tryParse(normalized, radix: 16);
    if (rgb == null) return fallback;
    return Color(0xFF000000 | rgb);
  }

  Future<Image?> _loadImageAsset({
    required FlameGame game,
    required String assetPath,
    required bool strict,
    required String errorContext,
  }) async {
    try {
      return await game.images.load(assetPath);
    } catch (error) {
      if (strict) {
        throw GamesToolProjectAssetNotFoundException(
          'Missing $errorContext at "$assetPath".',
          cause: error,
        );
      }
      return null;
    }
  }

  Future<List<String>> _safeDiscoverProjectRoots({
    String assetsRoot = 'assets',
  }) async {
    try {
      return await discoverProjectRoots(assetsRoot: assetsRoot);
    } catch (_) {
      return <String>[];
    }
  }

  List<String> _candidateProjectRoots(String root) {
    final String normalized = _normalizeAssetPath(root);
    if (normalized.isEmpty) return <String>[];

    final List<String> baseCandidates = <String>[normalized];
    if (normalized.startsWith('asstes/')) {
      baseCandidates.add('assets/${normalized.substring('asstes/'.length)}');
    }
    if (normalized.startsWith('asset/')) {
      baseCandidates.add('assets/${normalized.substring('asset/'.length)}');
    }
    if (!normalized.startsWith('assets/')) {
      baseCandidates.add('assets/$normalized');
      final List<String> parts = normalized.split('/');
      if (parts.isNotEmpty) baseCandidates.add('assets/${parts.last}');
    }

    final List<String> candidates = <String>[];
    for (final String base in baseCandidates) {
      final String cleaned = _normalizeAssetPath(base);
      if (cleaned.isEmpty || candidates.contains(cleaned)) continue;
      candidates.add(cleaned);

      final String exToEx = cleaned.replaceAll('example', 'exemple');
      if (!candidates.contains(exToEx)) candidates.add(exToEx);
      final String exToEx2 = cleaned.replaceAll('exemple', 'example');
      if (!candidates.contains(exToEx2)) candidates.add(exToEx2);
    }
    return candidates;
  }

  String _normalizeAssetPath(String value) {
    String normalized = value.trim().replaceAll('\\', '/');
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
