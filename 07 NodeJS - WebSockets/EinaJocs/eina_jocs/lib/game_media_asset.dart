class GameMediaAsset {
  static const String defaultSelectionColorHex = '#FFCC00';

  String name;
  String fileName;
  String mediaType;
  int tileWidth;
  int tileHeight;
  String selectionColorHex;

  GameMediaAsset({
    required String? name,
    required this.fileName,
    required this.mediaType,
    required this.tileWidth,
    required this.tileHeight,
    String? selectionColorHex,
  })  : name = _normalizeName(name, fileName),
        selectionColorHex = _normalizeSelectionColorHex(selectionColorHex);

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
      name: json['name'] as String?,
      fileName: json['fileName'] as String,
      mediaType: normalizedType,
      tileWidth: (json['tileWidth'] as num?)?.toInt() ?? 32,
      tileHeight: (json['tileHeight'] as num?)?.toInt() ?? 32,
      selectionColorHex: json['selectionColorHex'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': _normalizeName(name, fileName),
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

  static String inferNameFromFileName(String fileName) {
    if (fileName.trim().isEmpty) {
      return 'Media';
    }
    final String segment = fileName.split(RegExp(r'[\\/]')).last;
    if (segment.trim().isEmpty) {
      return 'Media';
    }
    final int dotIndex = segment.lastIndexOf('.');
    final String noExtension =
        dotIndex > 0 ? segment.substring(0, dotIndex) : segment;
    final String trimmed = noExtension.trim();
    return trimmed.isEmpty ? segment.trim() : trimmed;
  }

  static String _normalizeName(String? rawName, String fileName) {
    final String trimmed = rawName?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return inferNameFromFileName(fileName);
  }
}
