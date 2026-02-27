import 'dart:convert';

import 'package:flutter/services.dart';

class GamesToolApi {
  const GamesToolApi({this.projectFolder = 'example_0'});

  final String projectFolder;

  String get projectAssetsRoot => 'assets/$projectFolder';
  String get gameDataAssetPath => '$projectAssetsRoot/game_data.json';

  String toRelativeAssetKey(String relativePath) {
    final String normalizedPath = _normalizePath(relativePath);
    return '$projectFolder/$normalizedPath';
  }

  String toBundleAssetPath(String relativePath) {
    return 'assets/${toRelativeAssetKey(relativePath)}';
  }

  Future<Map<String, dynamic>> loadGameData(AssetBundle bundle) async {
    final String jsonString = await bundle.loadString(gameDataAssetPath);
    final Map<String, dynamic> parsed =
        jsonDecode(jsonString) as Map<String, dynamic>;
    await _attachTileMaps(bundle, parsed);
    return parsed;
  }

  Set<String> collectReferencedImageFiles(Map<String, dynamic> gameData) {
    final Set<String> imageFiles = <String>{};
    final List<dynamic> levels =
        (gameData['levels'] as List<dynamic>?) ?? const <dynamic>[];

    for (final dynamic level in levels) {
      final List<dynamic> layers =
          (level['layers'] as List<dynamic>?) ?? const <dynamic>[];
      for (final dynamic layer in layers) {
        final Object? tilesSheetFile = layer['tilesSheetFile'];
        if (tilesSheetFile is String && tilesSheetFile.isNotEmpty) {
          imageFiles.add(_normalizePath(tilesSheetFile));
        }
      }

      final List<dynamic> sprites =
          (level['sprites'] as List<dynamic>?) ?? const <dynamic>[];
      for (final dynamic sprite in sprites) {
        final Object? imageFile = sprite['imageFile'];
        if (imageFile is String && imageFile.isNotEmpty) {
          imageFiles.add(_normalizePath(imageFile));
        }
      }
    }

    final List<dynamic> mediaAssets =
        (gameData['mediaAssets'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic media in mediaAssets) {
      final Object? fileName = media['fileName'];
      if (fileName is String && fileName.isNotEmpty) {
        imageFiles.add(_normalizePath(fileName));
      }
    }

    return imageFiles;
  }

  Map<String, dynamic>? findLevelByName(
    Map<String, dynamic> gameData,
    String levelName,
  ) {
    final List<dynamic> levels =
        (gameData['levels'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic level in levels) {
      if (level is Map<String, dynamic> && level['name'] == levelName) {
        return level;
      }
    }
    return null;
  }

  Map<String, dynamic>? findSpriteByType(
    Map<String, dynamic> level,
    String spriteType,
  ) {
    final List<dynamic> sprites =
        (level['sprites'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic sprite in sprites) {
      if (sprite is Map<String, dynamic> && sprite['type'] == spriteType) {
        return sprite;
      }
    }
    return null;
  }

  Future<void> _attachTileMaps(
    AssetBundle bundle,
    Map<String, dynamic> gameData,
  ) async {
    final List<dynamic> levels =
        (gameData['levels'] as List<dynamic>?) ?? const <dynamic>[];

    for (final dynamic level in levels) {
      final List<dynamic> layers =
          (level['layers'] as List<dynamic>?) ?? const <dynamic>[];
      for (final dynamic layer in layers) {
        final Object? tileMapFile = layer['tileMapFile'];
        if (tileMapFile is! String || tileMapFile.isEmpty) {
          continue;
        }
        final String tileMapJson =
            await bundle.loadString(toBundleAssetPath(tileMapFile));
        final Map<String, dynamic> tileMapData =
            jsonDecode(tileMapJson) as Map<String, dynamic>;
        final Object? tileMap = tileMapData['tileMap'];
        if (tileMap is List<dynamic>) {
          layer['tileMap'] = tileMap;
        }
      }
    }
  }

  String _normalizePath(String path) {
    String normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('assets/')) {
      normalized = normalized.substring('assets/'.length);
    }
    if (normalized.startsWith('$projectFolder/')) {
      normalized = normalized.substring(projectFolder.length + 1);
    }
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }
}
