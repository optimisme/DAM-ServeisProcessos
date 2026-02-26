import 'game_layer.dart';
import 'game_zone.dart';
import 'game_sprite.dart';

class GameLevel {
  final String name;
  final String description;
  final List<GameLayer> layers;
  final List<GameZone> zones;
  final List<GameSprite> sprites;
  int viewportWidth;
  int viewportHeight;
  int viewportX;
  int viewportY;
  // 'letterbox', 'expand', 'stretch'
  String viewportAdaptation;
  // Hex color for preview/runtime background (for example "#BFD2EA").
  String backgroundColorHex;

  GameLevel({
    required this.name,
    required this.description,
    required this.layers,
    required this.zones,
    required this.sprites,
    this.viewportWidth = 320,
    this.viewportHeight = 180,
    this.viewportX = 0,
    this.viewportY = 0,
    this.viewportAdaptation = 'letterbox',
    this.backgroundColorHex = '#BFD2EA',
  });

  // Constructor de fàbrica per crear una instància des d'un Map (JSON)
  factory GameLevel.fromJson(Map<String, dynamic> json) {
    return GameLevel(
      name: json['name'] as String,
      description: json['description'] as String,
      layers: (json['layers'] as List<dynamic>)
          .map((layer) => GameLayer.fromJson(layer))
          .toList(),
      zones: (json['zones'] as List<dynamic>)
          .map((zone) => GameZone.fromJson(zone))
          .toList(),
      sprites: (json['sprites'] as List<dynamic>)
          .map((item) => GameSprite.fromJson(item))
          .toList(),
      viewportWidth: (json['viewportWidth'] as int?) ?? 320,
      viewportHeight: (json['viewportHeight'] as int?) ?? 180,
      viewportX: (json['viewportX'] as int?) ?? 0,
      viewportY: (json['viewportY'] as int?) ?? 0,
      viewportAdaptation:
          (json['viewportAdaptation'] as String?) ?? 'letterbox',
      backgroundColorHex: (json['backgroundColorHex'] as String?) ?? '#BFD2EA',
    );
  }

  // Convertir l'objecte a JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'layers': layers.map((layer) => layer.toJson()).toList(),
      'zones': zones.map((zone) => zone.toJson()).toList(),
      'sprites': sprites.map((item) => item.toJson()).toList(),
      'viewportWidth': viewportWidth,
      'viewportHeight': viewportHeight,
      'viewportX': viewportX,
      'viewportY': viewportY,
      'viewportAdaptation': viewportAdaptation,
      'backgroundColorHex': backgroundColorHex,
    };
  }

  @override
  String toString() {
    return 'GameLevel(name: $name, description: $description, layers: $layers, zones: $zones, sprites: $sprites, viewport: ${viewportWidth}x$viewportHeight at ($viewportX,$viewportY) [$viewportAdaptation], background: $backgroundColorHex)';
  }
}
