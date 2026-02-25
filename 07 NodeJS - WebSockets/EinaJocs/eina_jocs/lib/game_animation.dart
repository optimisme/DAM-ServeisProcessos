class GameAnimation {
  String id;
  String name;
  String mediaFile;
  int startFrame;
  int endFrame;
  double fps;
  bool loop;

  GameAnimation({
    required this.id,
    required this.name,
    required this.mediaFile,
    required this.startFrame,
    required this.endFrame,
    required this.fps,
    required this.loop,
  });

  factory GameAnimation.fromJson(Map<String, dynamic> json) {
    final int parsedStart = (json['startFrame'] as num?)?.toInt() ?? 0;
    final int parsedEnd = (json['endFrame'] as num?)?.toInt() ?? parsedStart;
    final double parsedFps = (json['fps'] as num?)?.toDouble() ?? 12.0;
    return GameAnimation(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      mediaFile: ((json['mediaFile'] as String?) ??
              (json['imageFile'] as String?) ??
              '')
          .trim(),
      startFrame: parsedStart < 0 ? 0 : parsedStart,
      endFrame: parsedEnd < parsedStart ? parsedStart : parsedEnd,
      fps: parsedFps <= 0 ? 12.0 : parsedFps,
      loop: json['loop'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mediaFile': mediaFile,
      'startFrame': startFrame,
      'endFrame': endFrame,
      'fps': fps,
      'loop': loop,
    };
  }
}
