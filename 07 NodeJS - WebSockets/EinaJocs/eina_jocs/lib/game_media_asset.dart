class GameMediaAsset {
  static const String defaultSelectionColorHex = '#FFCC00';

  String fileName;
  String mediaType;
  int tileWidth;
  int tileHeight;
  String selectionColorHex;

  GameMediaAsset({
    required this.fileName,
    required this.mediaType,
    required this.tileWidth,
    required this.tileHeight,
    String? selectionColorHex,
  }) : selectionColorHex = _normalizeSelectionColorHex(selectionColorHex);

  static const List<String> validTypes = [
    'image',
    'tileset',
    'spritesheet',
    'atlas',
  ];

  /// Whether this asset uses a tile/cell grid (tileset or atlas).
  bool get hasTileGrid => mediaType == 'tileset' || mediaType == 'atlas';

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
      selectionColorHex: json['selectionColorHex'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'mediaType': mediaType,
      'tileWidth': tileWidth,
      'tileHeight': tileHeight,
      'selectionColorHex': _normalizeSelectionColorHex(selectionColorHex),
    };
  }

  static String _normalizeSelectionColorHex(String? raw) {
    if (raw == null) {
      return defaultSelectionColorHex;
    }
    final String cleaned = raw.trim().replaceFirst('#', '').toUpperCase();
    final RegExp sixHex = RegExp(r'^[0-9A-F]{6}$');
    if (!sixHex.hasMatch(cleaned)) {
      return defaultSelectionColorHex;
    }
    return '#$cleaned';
  }
}
