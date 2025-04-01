class GameSprite {
  String type;
  int x;
  int y;
  int spriteWidth;
  int spriteHeight;
  String imageFile;

  GameSprite({
    required this.type,
    required this.x,
    required this.y,
    required this.spriteWidth,
    required this.spriteHeight,
    required this.imageFile,
  });

  // Constructor de fàbrica per crear una instància des d'un Map (JSON)
  factory GameSprite.fromJson(Map<String, dynamic> json) {
    return GameSprite(
      type: json['type'] as String,
      x: json['x'] as int,
      y: json['y'] as int,
      spriteWidth: json['width'] as int,
      spriteHeight: json['height'] as int,
      imageFile: json['imageFile'] as String,
    );
  }

  // Convertir l'objecte a JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'x': x,
      'y': y,
      'width': spriteWidth,
      'height': spriteHeight,
      'imageFile': imageFile,
    };
  }

  @override
  String toString() {
    return 'GameItem(type: $type, x: $x, y: $y, width: $spriteWidth, height: $spriteHeight, imageFile: $imageFile)';
  }
}
