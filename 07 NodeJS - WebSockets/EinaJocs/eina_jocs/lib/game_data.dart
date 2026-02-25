import 'game_level.dart';
import 'game_media_asset.dart';
import 'game_zone_type.dart';

class GameData {
  final String name;
  final List<GameLevel> levels;
  final List<GameMediaAsset> mediaAssets;
  final List<GameZoneType> zoneTypes;

  GameData({
    required this.name,
    required this.levels,
    List<GameMediaAsset>? mediaAssets,
    List<GameZoneType>? zoneTypes,
  })  : mediaAssets = mediaAssets ?? <GameMediaAsset>[],
        zoneTypes = zoneTypes ?? <GameZoneType>[];

  // Constructor de fàbrica per crear una instància des d'un Map (JSON)
  factory GameData.fromJson(Map<String, dynamic> json) {
    final List<GameLevel> levels = (json['levels'] as List<dynamic>)
        .map((level) => GameLevel.fromJson(level))
        .toList();
    final List<GameZoneType> zoneTypes =
        ((json['zoneTypes'] as List<dynamic>?) ?? [])
            .map((item) => GameZoneType.fromJson(item))
            .toList();
    return GameData(
      name: json['name'] as String,
      levels: levels,
      mediaAssets: ((json['mediaAssets'] as List<dynamic>?) ?? [])
          .map((item) => GameMediaAsset.fromJson(item))
          .toList(),
      zoneTypes:
          zoneTypes.isNotEmpty ? zoneTypes : _inferZoneTypesFromLevels(levels),
    );
  }

  static List<GameZoneType> _inferZoneTypesFromLevels(List<GameLevel> levels) {
    final Map<String, String> byName = {};
    for (final level in levels) {
      for (final zone in level.zones) {
        final String name = zone.type.trim();
        if (name.isEmpty) {
          continue;
        }
        byName.putIfAbsent(name, () => zone.color);
      }
    }
    if (byName.isEmpty) {
      return const [
        GameZoneType(name: 'Default', color: 'blue'),
      ];
    }
    return byName.entries
        .map((entry) => GameZoneType(name: entry.key, color: entry.value))
        .toList(growable: false);
  }

  // Convertir l'objecte a JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'levels': levels.map((level) => level.toJson()).toList(),
      'mediaAssets': mediaAssets.map((asset) => asset.toJson()).toList(),
      'zoneTypes': zoneTypes.map((type) => type.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'Game(name: $name, levels: $levels, mediaAssets: $mediaAssets, zoneTypes: $zoneTypes)';
  }
}
