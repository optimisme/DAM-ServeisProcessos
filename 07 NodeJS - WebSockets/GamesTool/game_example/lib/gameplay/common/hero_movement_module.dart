import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:game_example/utils_flame/utils_flame.dart';
import 'package:game_example/utils_gt/utils_gt.dart';

import '../core/gameplay_module.dart';

class HeroMovementModule extends GameplayModule {
  const HeroMovementModule({this.heroSpriteName = 'Heroi', this.speed = 90});

  final String heroSpriteName;
  final double speed;

  @override
  Future<void> onLevelMounted(GameplayContext context) async {
    final GamesToolSpriteHandle? hero = context.mountResult.handleForSpriteName(
      heroSpriteName,
    );
    if (hero == null || !hero.isAnimated) return;

    await context.game.world.add(
      _HeroMovementController(
        hero: hero,
        loadedProject: context.mountResult.loadedProject,
        game: context.game,
        speed: speed,
      ),
    );
  }
}

class _HeroMovementController extends Component {
  _HeroMovementController({
    required GamesToolSpriteHandle hero,
    required GamesToolLoadedProject loadedProject,
    required FlameGame game,
    required this.speed,
  }) : _hero = hero,
       _loadedProject = loadedProject,
       _game = game;

  final GamesToolSpriteHandle _hero;
  final GamesToolLoadedProject _loadedProject;
  final FlameGame _game;
  final double speed;

  _HeroDirection _facing = _HeroDirection.down;
  bool _isWalking = false;
  String _currentAnimationName = '';
  bool _currentFlipX = false;
  bool _isApplyingVisuals = false;
  bool _visualsDirty = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _applyVisuals(force: true);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final Vector2 movement = _readMovementVector();
    final bool hasMovement = movement.length2 > 0;
    if (hasMovement) {
      if (movement.length2 > 1) movement.normalize();
      _hero.position.add(movement * (speed * dt));
    }

    final _HeroDirection previousFacing = _facing;
    if (hasMovement) {
      _facing = _directionFromMovement(movement);
    }

    if (_isWalking != hasMovement || previousFacing != _facing) {
      _isWalking = hasMovement;
      _markVisualsDirty();
    }
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
