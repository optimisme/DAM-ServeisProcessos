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

  factory GameMediaAsset.fromJson(Map<String, dynamic> json) {
    final String parsedType =
        (json['mediaType'] as String? ?? 'image').trim().toLowerCase();
    final String normalizedType = parsedType == 'tileset' ? 'tileset' : 'image';

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
