class GameLayer {
  final String name;
  final int x;
  final int y;
  final double depth;
  final String tilesSheetFile;
  final int tilesWidth;
  final int tilesHeight;
  final List<List<int>> tileMap;
  final bool visible;

  GameLayer({
    required this.name,
    required this.x,
    required this.y,
    required this.depth,
    required this.tilesSheetFile,
    required this.tilesWidth,
    required this.tilesHeight,
    required this.tileMap,
    required this.visible,
  });

  // Constructor de fàbrica per crear una instància des d'un Map (JSON)
  factory GameLayer.fromJson(Map<String, dynamic> json) {
    final dynamic rawDepth = json['depth'];
    final double parsedDepth = rawDepth is num ? rawDepth.toDouble() : 0.0;
    return GameLayer(
        name: json['name'] as String,
        x: json['x'] as int,
        y: json['y'] as int,
        depth: parsedDepth,
        tilesSheetFile: json['tilesSheetFile'] as String,
        tilesWidth: json['tilesWidth'] as int,
        tilesHeight: json['tilesHeight'] as int,
        tileMap: (json['tileMap'] as List<dynamic>)
            .map((row) => List<int>.from(row))
            .toList(),
        visible: json['visible'] as bool);
  }

  // Convertir l'objecte a JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'x': x,
      'y': y,
      'depth': depth,
      'tilesSheetFile': tilesSheetFile,
      'tilesWidth': tilesWidth,
      'tilesHeight': tilesHeight,
      'tileMap': tileMap.map((row) => row.toList()).toList(),
      'visible': visible
    };
  }

  @override
  String toString() {
    return 'GameLayer(name: $name, x: $x, y: $y, depth: $depth, tilesSheetFile: $tilesSheetFile, tilesWidth: $tilesWidth, tilesHeight: $tilesHeight, tileMap: $tileMap, visible: $visible)';
  }
}
