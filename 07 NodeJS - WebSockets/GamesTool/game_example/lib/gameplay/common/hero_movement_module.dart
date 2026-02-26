import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:game_example/gameplay/level_game.dart';
import 'package:game_example/utils_flame/utils_flame.dart';
import 'package:game_example/utils_gt/utils_gt.dart';

import '../core/gameplay_module.dart';

class HeroMovementModule extends GameplayModule {
  const HeroMovementModule({
    this.heroSpriteName = 'Heroi',
    this.speed = 75,
    this.enableCameraFollow = true,
    this.cameraFollowMaxSpeed = 0,
    this.clampCameraToWorldBounds = false,
    this.collisionTopInset = 0.5,
  });

  final String heroSpriteName;
  final double speed;
  final bool enableCameraFollow;
  final double cameraFollowMaxSpeed;
  final bool clampCameraToWorldBounds;

  /// Fraction of the sprite height to skip from the top when building the
  /// collision box. `0.5` means only the bottom half collides (feet-only),
  /// which is the standard for top-down games where the character head/body
  /// floats above the ground plane. Range: 0.0 (full sprite) – 0.9.
  final double collisionTopInset;

  @override
  Future<void> onLevelMounted(GameplayContext context) async {
    final GamesToolSpriteHandle? hero = context.mountResult.handleForSpriteName(
      heroSpriteName,
    );
    if (hero == null || !hero.isAnimated) return;

    final ValueNotifier<int>? counter = context.game is LevelGame
        ? (context.game as LevelGame).removedDecorationsCount
        : null;

    await context.game.world.add(
      _HeroMovementController(
        hero: hero,
        loadedProject: context.mountResult.loadedProject,
        loadedLevel: context.mountResult.loadedLevel,
        game: context.game,
        speed: speed,
        enableCameraFollow: enableCameraFollow,
        cameraFollowMaxSpeed: cameraFollowMaxSpeed,
        clampCameraToWorldBounds: clampCameraToWorldBounds,
        worldBounds: context.mountResult.worldBounds,
        collisionTopInset: collisionTopInset.clamp(0.0, 0.9),
        removedDecorationsCount: counter,
      ),
    );
  }
}

class _HeroMovementController extends Component {
  _HeroMovementController({
    required GamesToolSpriteHandle hero,
    required GamesToolLoadedProject loadedProject,
    required GamesToolLoadedLevel loadedLevel,
    required FlameGame game,
    required this.speed,
    required this.enableCameraFollow,
    required this.cameraFollowMaxSpeed,
    required this.clampCameraToWorldBounds,
    required this.collisionTopInset,
    required this.removedDecorationsCount,
    required Rect worldBounds,
  }) : _hero = hero,
       _loadedProject = loadedProject,
       _loadedLevel = loadedLevel,
       _game = game,
       _worldBounds = worldBounds,
       _blockingZones = loadedLevel.zones
           .where(
             (GamesToolZone z) =>
                 _normalizeZoneType(z.type) == 'mur' ||
                 _normalizeZoneType(z.type) == 'aigua',
           )
           .toList(growable: false);

  final GamesToolSpriteHandle _hero;
  final GamesToolLoadedProject _loadedProject;
  final GamesToolLoadedLevel _loadedLevel;
  final FlameGame _game;
  final double speed;
  final ValueNotifier<int>? removedDecorationsCount;
  final bool enableCameraFollow;
  final double cameraFollowMaxSpeed;
  final bool clampCameraToWorldBounds;
  final double collisionTopInset;
  final Rect _worldBounds;
  final List<GamesToolZone> _blockingZones;

  _HeroDirection _facing = _HeroDirection.down;
  bool _isWalking = false;
  String _currentAnimationName = '';
  bool _currentFlipX = false;
  bool _isApplyingVisuals = false;
  bool _visualsDirty = false;
  final Vector2 _cameraTarget = Vector2.zero();
  final Vector2 _cameraDelta = Vector2.zero();
  final Vector2 _heroCenter = Vector2.zero();
  final Vector2 _movementDelta = Vector2.zero();
  GamesToolZoneTracker? _zoneTracker;
  List<List<int>>? _decorationsTileMap;
  int _decorationsTileWidth = 0;
  int _decorationsTileHeight = 0;
  double _decorationsBaseX = 0;
  double _decorationsBaseY = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _initZoneInteractions();
    if (enableCameraFollow) {
      _snapCameraToHero();
    }
    await _applyVisuals(force: true);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final Vector2 movement = _readMovementVector();
    final bool hasMovement = movement.length2 > 0;
    if (hasMovement) {
      if (movement.length2 > 1) movement.normalize();
      _movementDelta
        ..setFrom(movement)
        ..scale(speed * dt);
      _applyMovementWithZones(_movementDelta);
    }
    _updateZoneTracking();

    final _HeroDirection previousFacing = _facing;
    if (hasMovement) {
      _facing = _directionFromMovement(movement);
    }

    if (_isWalking != hasMovement || previousFacing != _facing) {
      _isWalking = hasMovement;
      _markVisualsDirty();
    }

    if (enableCameraFollow) {
      _updateCamera(dt);
    }
  }

  void _snapCameraToHero() {
    _cameraTarget.setFrom(_heroCenterPoint());
    if (clampCameraToWorldBounds) {
      _clampTargetToWorldBounds(_cameraTarget);
    }
    _game.camera.viewfinder.position = _cameraTarget.clone();
  }

  void _updateCamera(double dt) {
    _cameraTarget.setFrom(_heroCenterPoint());
    if (clampCameraToWorldBounds) {
      _clampTargetToWorldBounds(_cameraTarget);
    }

    final Vector2 current = _game.camera.viewfinder.position;
    _cameraDelta
      ..setFrom(_cameraTarget)
      ..sub(current);

    final double distance = _cameraDelta.length;
    if (distance <= 0.0001) {
      _game.camera.viewfinder.position = _cameraTarget.clone();
      return;
    }

    if (cameraFollowMaxSpeed <= 0) {
      _game.camera.viewfinder.position = _cameraTarget.clone();
      return;
    }

    final double maxStep = cameraFollowMaxSpeed * dt;
    if (distance <= maxStep) {
      _game.camera.viewfinder.position = _cameraTarget.clone();
      return;
    }

    _cameraDelta.scale(maxStep / distance);
    _game.camera.viewfinder.position = current + _cameraDelta;
  }

  /// Returns the visual top-left corner of the hero in world space,
  /// accounting for the flip-induced position offset applied by [setFlip].
  double _heroVisualLeft() =>
      _hero.flipX ? _hero.position.x - _hero.size.x : _hero.position.x;
  double _heroVisualTop() =>
      _hero.flipY ? _hero.position.y - _hero.size.y : _hero.position.y;

  /// Pixel height skipped from the top of the sprite for collision/zone checks.
  double get _collisionTopOffset => _hero.size.y * collisionTopInset;

  void _applyMovementWithZones(Vector2 delta) {
    final double startVisualX = _heroVisualLeft();
    final double startVisualY = _heroVisualTop();

    // Try full diagonal move.
    if (!_isBlockedAtVisual(startVisualX + delta.x, startVisualY + delta.y)) {
      _hero.position.x += delta.x;
      _hero.position.y += delta.y;
      return;
    }

    // Try horizontal-only slide.
    if (delta.x != 0) {
      if (!_isBlockedAtVisual(startVisualX + delta.x, startVisualY)) {
        _hero.position.x += delta.x;
      }
    }

    // Try vertical-only slide (from wherever we ended up above).
    if (delta.y != 0) {
      final double currentVisualY = _heroVisualTop();
      if (!_isBlockedAtVisual(_heroVisualLeft(), currentVisualY + delta.y)) {
        _hero.position.y += delta.y;
      }
    }
  }

  void _initZoneInteractions() {
    _zoneTracker = _loadedLevel.createZoneTracker(
      type: 'Arbre',
      onEnter: (GamesToolZone zone) {
        _clearClosestDecorationTile(zone);
      },
    );
    _bindDecorationsLayerTileMap();
  }

  void _updateZoneTracking() {
    final GamesToolZoneTracker? tracker = _zoneTracker;
    if (tracker == null) return;
    final double topOffset = _collisionTopOffset;
    final double vx = _heroVisualLeft();
    final double vy = _heroVisualTop() + topOffset;
    tracker.update(
      vx.floor(),
      vy.floor(),
      width: math.max(1, _hero.size.x.ceil()),
      height: math.max(1, (_hero.size.y - topOffset).ceil()),
    );
  }

  bool _isBlockedAtVisual(double visualX, double visualY) {
    if (_blockingZones.isEmpty) return false;
    final double topOffset = _collisionTopOffset;
    final GamesToolRect playerRect = GamesToolRect(
      x: visualX.floor(),
      y: (visualY + topOffset).floor(),
      width: math.max(1, _hero.size.x.ceil()),
      height: math.max(1, (_hero.size.y - topOffset).ceil()),
    );
    for (final GamesToolZone zone in _blockingZones) {
      if (zone.bounds.overlaps(playerRect)) {
        return true;
      }
    }
    return false;
  }

  void _bindDecorationsLayerTileMap() {
    GamesToolLayer? decorationsLayer;
    for (final GamesToolLayer layer in _loadedLevel.layers) {
      if (layer.name.trim().toLowerCase() == 'decoracions') {
        decorationsLayer = layer;
        break;
      }
    }
    if (decorationsLayer == null) return;

    final GamesToolTileMapFile? tileMapFile = _loadedProject.tileMapForLayer(
      decorationsLayer,
    );
    if (tileMapFile == null) return;

    if (decorationsLayer.tilesWidth <= 0 || decorationsLayer.tilesHeight <= 0) {
      return;
    }
    _decorationsTileMap = tileMapFile.tileMap;
    _decorationsTileWidth = decorationsLayer.tilesWidth;
    _decorationsTileHeight = decorationsLayer.tilesHeight;
    _decorationsBaseX = decorationsLayer.x.toDouble();
    _decorationsBaseY = decorationsLayer.y.toDouble();
  }

  void _clearClosestDecorationTile(GamesToolZone zone) {
    final List<List<int>>? tileMap = _decorationsTileMap;
    if (tileMap == null) return;
    if (_decorationsTileWidth <= 0 || _decorationsTileHeight <= 0) return;

    final Vector2 center = _heroCenterPoint();
    final _TilePosition? selectedTile = _findClosestDecorationTile(
      centerX: center.x,
      centerY: center.y,
      tileMap: tileMap,
      requiredOverlap: zone.bounds,
    );
    if (selectedTile == null) return;

    tileMap[selectedTile.row][selectedTile.col] = -1;
    final ValueNotifier<int>? counter = removedDecorationsCount;
    if (counter != null) counter.value += 1;
  }

  _TilePosition? _findClosestDecorationTile({
    required double centerX,
    required double centerY,
    required List<List<int>> tileMap,
    GamesToolRect? requiredOverlap,
  }) {
    _TilePosition? best;
    double bestDistance2 = double.infinity;

    for (int rowIndex = 0; rowIndex < tileMap.length; rowIndex++) {
      final List<int> row = tileMap[rowIndex];
      for (int colIndex = 0; colIndex < row.length; colIndex++) {
        if (row[colIndex] < 0) continue;

        final int tileX =
            (_decorationsBaseX + (colIndex * _decorationsTileWidth)).floor();
        final int tileY =
            (_decorationsBaseY + (rowIndex * _decorationsTileHeight)).floor();
        if (requiredOverlap != null) {
          final GamesToolRect tileRect = GamesToolRect(
            x: tileX,
            y: tileY,
            width: _decorationsTileWidth,
            height: _decorationsTileHeight,
          );
          if (!requiredOverlap.overlaps(tileRect)) continue;
        }

        final double tileCenterX = tileX + (_decorationsTileWidth * 0.5);
        final double tileCenterY = tileY + (_decorationsTileHeight * 0.5);
        final double dx = tileCenterX - centerX;
        final double dy = tileCenterY - centerY;
        final double distance2 = dx * dx + dy * dy;
        if (distance2 >= bestDistance2) continue;

        bestDistance2 = distance2;
        best = _TilePosition(row: rowIndex, col: colIndex);
      }
    }
    return best;
  }

  Vector2 _heroCenterPoint() => _heroCenter
    ..setValues(
      _hero.position.x + _hero.size.x * (_hero.flipX ? -0.5 : 0.5),
      _hero.position.y + _hero.size.y * (_hero.flipY ? -0.5 : 0.5),
    );

  void _clampTargetToWorldBounds(Vector2 target) {
    final Rect visibleRect = _game.camera.visibleWorldRect;
    final double halfW = visibleRect.width * 0.5;
    final double halfH = visibleRect.height * 0.5;
    final double worldCenterX = (_worldBounds.left + _worldBounds.right) * 0.5;
    final double worldCenterY = (_worldBounds.top + _worldBounds.bottom) * 0.5;

    final double minX = _worldBounds.left + halfW;
    final double maxX = _worldBounds.right - halfW;
    final double minY = _worldBounds.top + halfH;
    final double maxY = _worldBounds.bottom - halfH;

    target.x = minX <= maxX ? target.x.clamp(minX, maxX) : worldCenterX;
    target.y = minY <= maxY ? target.y.clamp(minY, maxY) : worldCenterY;
  }

  Vector2 _readMovementVector() {
    final Set<LogicalKeyboardKey> keys =
        HardwareKeyboard.instance.logicalKeysPressed;

    int x = 0;
    int y = 0;
    if (_isPressed(
      keys,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.arrowLeft,
    )) {
      x -= 1;
    }
    if (_isPressed(
      keys,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.arrowRight,
    )) {
      x += 1;
    }
    if (_isPressed(keys, LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp)) {
      y -= 1;
    }
    if (_isPressed(
      keys,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.arrowDown,
    )) {
      y += 1;
    }
    return Vector2(x.toDouble(), y.toDouble());
  }

  bool _isPressed(
    Set<LogicalKeyboardKey> keys,
    LogicalKeyboardKey primary,
    LogicalKeyboardKey fallback,
  ) {
    return keys.contains(primary) || keys.contains(fallback);
  }

  _HeroDirection _directionFromMovement(Vector2 movement) {
    final int x = movement.x.sign.toInt();
    final int y = movement.y.sign.toInt();

    if (x > 0 && y < 0) return _HeroDirection.upRight;
    if (x > 0 && y > 0) return _HeroDirection.downRight;
    if (x < 0 && y < 0) return _HeroDirection.upLeft;
    if (x < 0 && y > 0) return _HeroDirection.downLeft;
    if (x > 0) return _HeroDirection.right;
    if (x < 0) return _HeroDirection.left;
    if (y < 0) return _HeroDirection.up;
    return _HeroDirection.down;
  }

  void _markVisualsDirty() {
    _visualsDirty = true;
    if (_isApplyingVisuals) return;
    unawaited(_applyVisuals());
  }

  Future<void> _applyVisuals({bool force = false}) async {
    if (_isApplyingVisuals) {
      _visualsDirty = true;
      return;
    }

    _isApplyingVisuals = true;
    do {
      _visualsDirty = false;
      final _HeroAnimationSpec spec = _animationSpecForDirection(_facing);
      final String nextAnimation = _isWalking
          ? spec.walkAnimationName
          : spec.idleAnimationName;

      if (force || _currentFlipX != spec.flipX) {
        _hero.setFlip(flipX: spec.flipX);
        _currentFlipX = spec.flipX;
      }

      if (force || _currentAnimationName != nextAnimation) {
        final GamesToolAnimation? animation = _loadedProject.animationByName(
          nextAnimation,
        );
        if (animation != null) {
          await _hero.playAnimation(animation, _game);
          _currentAnimationName = nextAnimation;
        }
      }
    } while (_visualsDirty);

    _isApplyingVisuals = false;
  }

  _HeroAnimationSpec _animationSpecForDirection(_HeroDirection direction) {
    switch (direction) {
      case _HeroDirection.down:
        return const _HeroAnimationSpec(
          walkAnimationName: 'Heroi Camina Avall',
          idleAnimationName: 'Heroi Aturat Avall',
          flipX: false,
        );
      case _HeroDirection.downRight:
        return const _HeroAnimationSpec(
          walkAnimationName: 'Heroi Camina Avall-Dreta',
          idleAnimationName: 'Heroi Aturat Avall-Dreta',
          flipX: false,
        );
      case _HeroDirection.right:
        return const _HeroAnimationSpec(
          walkAnimationName: 'Heroi Camina Dreta',
          idleAnimationName: 'Heroi Aturat Dreta',
          flipX: false,
        );
      case _HeroDirection.upRight:
        return const _HeroAnimationSpec(
          walkAnimationName: 'Heroi Camina Amunt-Dreta',
          idleAnimationName: 'Heroi Aturat Amunt-Dreta',
          flipX: false,
        );
      case _HeroDirection.up:
        return const _HeroAnimationSpec(
          walkAnimationName: 'Heroi Camina Amunt',
          idleAnimationName: 'Heroi Aturat Amunt',
          flipX: false,
        );
      case _HeroDirection.left:
        return const _HeroAnimationSpec(
          walkAnimationName: 'Heroi Camina Dreta',
          idleAnimationName: 'Heroi Aturat Dreta',
          flipX: true,
        );
      case _HeroDirection.upLeft:
        return const _HeroAnimationSpec(
          walkAnimationName: 'Heroi Camina Amunt-Dreta',
          idleAnimationName: 'Heroi Aturat Amunt-Dreta',
          flipX: true,
        );
      case _HeroDirection.downLeft:
        return const _HeroAnimationSpec(
          walkAnimationName: 'Heroi Camina Avall-Dreta',
          idleAnimationName: 'Heroi Aturat Avall-Dreta',
          flipX: true,
        );
    }
  }
}

class _TilePosition {
  const _TilePosition({required this.row, required this.col});

  final int row;
  final int col;
}

String _normalizeZoneType(String value) => value.trim().toLowerCase();

enum _HeroDirection {
  up,
  upRight,
  right,
  downRight,
  down,
  downLeft,
  left,
  upLeft,
}

class _HeroAnimationSpec {
  const _HeroAnimationSpec({
    required this.walkAnimationName,
    required this.idleAnimationName,
    required this.flipX,
  });

  final String walkAnimationName;
  final String idleAnimationName;
  final bool flipX;
}
