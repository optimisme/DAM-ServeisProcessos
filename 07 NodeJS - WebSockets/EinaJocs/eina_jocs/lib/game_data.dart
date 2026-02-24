import 'game_level.dart';
import 'game_media_asset.dart';

class GameData {
  final String name;
  final List<GameLevel> levels;
  final List<GameMediaAsset> mediaAssets;

  GameData({
    required this.name,
    required this.levels,
    List<GameMediaAsset>? mediaAssets,
  }) : mediaAssets = mediaAssets ?? <GameMediaAsset>[];

  // Constructor de fàbrica per crear una instància des d'un Map (JSON)
  factory GameData.fromJson(Map<String, dynamic> json) {
    return GameData(
      name: json['name'] as String,
      levels: (json['levels'] as List<dynamic>)
          .map((level) => GameLevel.fromJson(level))
          .toList(),
      mediaAssets: ((json['mediaAssets'] as List<dynamic>?) ?? [])
          .map((item) => GameMediaAsset.fromJson(item))
          .toList(),
    );
  }

  // Convertir l'objecte a JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'levels': levels.map((level) => level.toJson()).toList(),
      'mediaAssets': mediaAssets.map((asset) => asset.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'Game(name: $name, levels: $levels, mediaAssets: $mediaAssets)';
  }
}
