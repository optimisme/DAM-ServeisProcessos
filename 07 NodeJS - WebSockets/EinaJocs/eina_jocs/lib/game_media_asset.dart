class GameMediaAsset {
  String fileName;
  String mediaType;
  int tileWidth;
  int tileHeight;

  GameMediaAsset({
    required this.fileName,
    required this.mediaType,
    required this.tileWidth,
    required this.tileHeight,
  });

  static const List<String> validTypes = [
    'image',
    'tileset',
    'spritesheet',
    'atlas',
  ];

  /// Whether this asset uses a tile/cell grid (tileset or atlas).
  bool get hasTileGrid =>
      mediaType == 'tileset' || mediaType == 'atlas';

  factory GameMediaAsset.fromJson(Map<String, dynamic> json) {
    final String parsedType =
        (json['mediaType'] as String? ?? 'image').trim().toLowerCase();
    final String normalizedType =
        validTypes.contains(parsedType) ? parsedType : 'image';

    return GameMediaAsset(
      fileName: json['fileName'] as String,
      mediaType: normalizedType,
      tileWidth: (json['tileWidth'] as num?)?.toInt() ?? 32,
      tileHeight: (json['tileHeight'] as num?)?.toInt() ?? 32,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'mediaType': mediaType,
      'tileWidth': tileWidth,
      'tileHeight': tileHeight,
    };
  }
}
