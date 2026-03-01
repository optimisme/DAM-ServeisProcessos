import 'game_animation_hit_box.dart';

class GameAnimation {
  static const String defaultGroupId = '__main__';
  static const double defaultAnchorX = 0.5;
  static const double defaultAnchorY = 0.5;
  static const String defaultAnchorColor = 'red';
  static const List<String> anchorColorPalette = <String>[
    'red',
    'deepOrange',
    'orange',
    'amber',
    'yellow',
    'lime',
    'lightGreen',
    'green',
    'teal',
    'cyan',
    'lightBlue',
    'blue',
    'indigo',
    'purple',
    'pink',
    'black',
    'white',
  ];

  String id;
  String name;
  String mediaFile;
  int startFrame;
  int endFrame;
  double fps;
  bool loop;
  String groupId;
  double anchorX;
  double anchorY;
  String anchorColor;
  List<GameAnimationHitBox> hitBoxes;

  GameAnimation({
    required this.id,
    required this.name,
    required this.mediaFile,
    required this.startFrame,
    required this.endFrame,
    required this.fps,
    required this.loop,
    String? groupId,
    double? anchorX,
    double? anchorY,
    String? anchorColor,
    List<GameAnimationHitBox>? hitBoxes,
  })  : groupId = _normalizeGroupId(groupId),
        anchorX = _normalizeAnchorComponent(anchorX, defaultAnchorX),
        anchorY = _normalizeAnchorComponent(anchorY, defaultAnchorY),
        anchorColor = _normalizeAnchorColor(anchorColor),
        hitBoxes = hitBoxes ?? <GameAnimationHitBox>[];

  factory GameAnimation.fromJson(Map<String, dynamic> json) {
    final int parsedStart = (json['startFrame'] as num?)?.toInt() ?? 0;
    final int parsedEnd = (json['endFrame'] as num?)?.toInt() ?? parsedStart;
    final double parsedFps = (json['fps'] as num?)?.toDouble() ?? 12.0;
    return GameAnimation(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      mediaFile: ((json['mediaFile'] as String?) ??
              (json['imageFile'] as String?) ??
              '')
          .trim(),
      startFrame: parsedStart < 0 ? 0 : parsedStart,
      endFrame: parsedEnd < parsedStart ? parsedStart : parsedEnd,
      fps: parsedFps <= 0 ? 12.0 : parsedFps,
      loop: json['loop'] as bool? ?? true,
      groupId: json['groupId'] as String? ?? defaultGroupId,
      anchorX:
          (json['anchorX'] as num?)?.toDouble() ?? GameAnimation.defaultAnchorX,
      anchorY:
          (json['anchorY'] as num?)?.toDouble() ?? GameAnimation.defaultAnchorY,
      anchorColor: json['anchorColor'] as String? ?? defaultAnchorColor,
      hitBoxes: ((json['hitBoxes'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(GameAnimationHitBox.fromJson)
          .toList(growable: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mediaFile': mediaFile,
      'startFrame': startFrame,
      'endFrame': endFrame,
      'fps': fps,
      'loop': loop,
      'groupId': _normalizeGroupId(groupId),
      'anchorX': _normalizeAnchorComponent(anchorX, defaultAnchorX),
      'anchorY': _normalizeAnchorComponent(anchorY, defaultAnchorY),
      'anchorColor': _normalizeAnchorColor(anchorColor),
      'hitBoxes': hitBoxes.map((item) => item.toJson()).toList(),
    };
  }

  static String _normalizeGroupId(String? rawGroupId) {
    final String trimmed = rawGroupId?.trim() ?? '';
    if (trimmed.isEmpty) {
      return defaultGroupId;
    }
    return trimmed;
  }

  static double _normalizeAnchorComponent(double? value, double fallback) {
    if (value == null || value.isNaN || value.isInfinite) {
      return fallback;
    }
    return value.clamp(0.0, 1.0);
  }

  static String _normalizeAnchorColor(String? rawColor) {
    final String normalized = rawColor?.trim() ?? '';
    if (anchorColorPalette.contains(normalized)) {
      return normalized;
    }
    return defaultAnchorColor;
  }
}
