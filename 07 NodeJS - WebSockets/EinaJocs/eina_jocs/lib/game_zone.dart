class GameZone {
  String type;
  int x;
  int y;
  int width;
  int height;
  String color;

  GameZone(
      {required this.type,
      required this.x,
      required this.y,
      required this.width,
      required this.height,
      required this.color});

  // Constructor de fàbrica per crear una instància des d'un Map (JSON)
  factory GameZone.fromJson(Map<String, dynamic> json) {
    return GameZone(
        type: json['type'] as String,
        x: json['x'] as int,
        y: json['y'] as int,
        width: json['width'] as int,
        height: json['height'] as int,
        color: json['color'] as String);
  }

  // Convertir l'objecte a JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'color': color
    };
  }

  @override
  String toString() {
    return 'GameZone(type: $type, x: $x, y: $y, width: $width, height: $height, color: $color)';
  }
}
