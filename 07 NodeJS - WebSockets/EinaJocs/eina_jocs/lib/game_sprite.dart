class GameSprite {
  String name;
  String animationId;
  int x;
  int y;
  int spriteWidth;
  int spriteHeight;
  String imageFile;
  bool flipX;
  bool flipY;
  double depth;

  GameSprite({
    required this.name,
    required this.animationId,
    required this.x,
    required this.y,
    required this.spriteWidth,
    required this.spriteHeight,
    required this.imageFile,
    this.flipX = false,
    this.flipY = false,
    this.depth = 0.0,
  });

  // Constructor de fàbrica per crear una instància des d'un Map (JSON)
  factory GameSprite.fromJson(Map<String, dynamic> json) {
    final dynamic rawName = json['name'];
    final dynamic rawType = json['type'];
    final String parsedName =
        rawName is String ? rawName : (rawType is String ? rawType : '');
    return GameSprite(
      name: parsedName,
      animationId: (json['animationId'] as String? ?? '').trim(),
      x: json['x'] as int,
      y: json['y'] as int,
      spriteWidth: json['width'] as int,
      spriteHeight: json['height'] as int,
      imageFile: json['imageFile'] as String,
      flipX: json['flipX'] as bool? ?? false,
      flipY: json['flipY'] as bool? ?? false,
      depth: (json['depth'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Convertir l'objecte a JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': name,
      'animationId': animationId,
      'x': x,
      'y': y,
      'width': spriteWidth,
      'height': spriteHeight,
      'imageFile': imageFile,
      'flipX': flipX,
      'flipY': flipY,
      'depth': depth,
    };
  }

  @override
  String toString() {
    return 'GameItem(name: $name, animationId: $animationId, x: $x, y: $y, width: $spriteWidth, height: $spriteHeight, imageFile: $imageFile, flipX: $flipX, flipY: $flipY, depth: $depth)';
  }
}
