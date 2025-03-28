import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'app_data.dart';

class CanvasPainter extends CustomPainter {
  final AppData appData;

  CanvasPainter(this.appData);

  @override
  void paint(Canvas canvas, Size painterSize) {

    // Fons blanc
    final paint = Paint();
    paint.color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, painterSize.width, painterSize.height),
      paint,
    );

    // Dibuixar l'estat del joc
    var gameState = appData.gameState;
    var gameData = appData.gameData;

    if (gameState.isNotEmpty && gameData.isNotEmpty) {

      // Pantalla rebuda del servidor
      if (gameState["level"] != null) {
        final String levelName = gameState["level"];
        final List<dynamic> levels = appData.gameData["levels"];
        final level = levels.firstWhere(
          (lvl) => lvl["name"] == levelName,
          orElse: () => null,
        );
        if (appData.playerData != null) {
          appData.camera.x = appData.playerData["x"].toDouble();
          appData.camera.y = appData.playerData["y"].toDouble();
        }
        if (level != null) {
          drawLevel(canvas, painterSize, level);
        }
      }

      if (gameState["players"] != null) {
        for (var player in gameState["players"]) {
          drawPlayer(canvas, painterSize, player);
        }
      }

      // Mostrar el cercle de connexió (amunt a la dreta)
      paint.color = appData.isConnected ? Colors.green : Colors.red;
      canvas.drawCircle(Offset(painterSize.width - 10, 10), 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  // Agafar la part del dibuix que té la fletxa de direcció a dibuixar
  Offset _getArrowTile(String direction) {
    switch (direction) {
      case "left":
        return Offset(64, 0);
      case "upLeft":
        return Offset(128, 0);
      case "up":
        return Offset(192, 0);
      case "upRight":
        return Offset(256, 0);
      case "right":
        return Offset(320, 0);
      case "downRight":
        return Offset(384, 0);
      case "down":
        return Offset(448, 0);
      case "downLeft":
        return Offset(512, 0);
      default:
        return Offset(0, 0);
    }
  }

  // Escollir un color en funció del seu nom
  static Color _getColorFromString(String color) {
    switch (color.toLowerCase()) {
      case "gray":
        return Colors.grey;
      case "green":
        return Colors.green;
      case "blue":
        return Colors.blue;
      case "orange":
        return Colors.orange;
      case "red":
        return Colors.red;
      case "purple":
        return Colors.purple;
      case "black":
        return Colors.black;
      default:
        return Colors.black;
    }
  }

  void drawLevel(Canvas canvas, Size painterSize, Map<String, dynamic> level) {
    final layers = level["layers"] as List<dynamic>;
    final cam = appData.camera;
    final double scale = painterSize.width / cam.focal;

    for (final layer in layers) {
      if (layer["visible"] != true) continue;

      final double depth = (layer["depth"] ?? 0).toDouble();
      final double parallax = depth >= 0 ? 1.0 : 1.0 / (1.0 - depth);
      final double camX = cam.x * parallax;
      final double camY = cam.y * parallax;
      final double layerX = (layer["x"] as num?)?.toDouble() ?? 0;
      final double layerY = (layer["y"] as num?)?.toDouble() ?? 0;

      final tileMap = layer["tileMap"] as List<dynamic>;
      final tileW = (layer["tilesWidth"] as num).toDouble();
      final tileH = (layer["tilesHeight"] as num).toDouble();
      final tileSheetPath = "platform_game/${layer["tilesSheetFile"]}";

      if (!appData.imagesCache.containsKey(tileSheetPath)) continue;
      final ui.Image tileSheet = appData.imagesCache[tileSheetPath]!;
      final int tileSheetCols = (tileSheet.width / tileW).floor();

      for (int row = 0; row < tileMap.length; row++) {
        final rowTiles = tileMap[row] as List<dynamic>;
        for (int col = 0; col < rowTiles.length; col++) {
          final int tileIndex = (rowTiles[col] as num).toInt();
          if (tileIndex < 0) continue;

          final double worldX = layerX + col * tileW;
          final double worldY = layerY + row * tileH;
          final double screenX = (worldX - camX) * scale + painterSize.width / 2;
          final double screenY = (worldY - camY) * scale + painterSize.height / 2;
          final double destWidth = tileW * scale;
          final double destHeight = tileH * scale;
          final int srcCol = tileIndex % tileSheetCols;
          final int srcRow = tileIndex ~/ tileSheetCols;
          final double srcX = srcCol * tileW;
          final double srcY = srcRow * tileH;

          canvas.drawImageRect(
            tileSheet,
            Rect.fromLTWH(srcX, srcY, tileW, tileH),
            Rect.fromLTWH(screenX - 1, screenY - 1, destWidth + 1, destHeight + 1),
            Paint(),
          );
        }
      }
    }
  }


  void drawPlayer(Canvas canvas, Size painterSize, Map<String, dynamic> player) {

    final cam = appData.camera;
    final double scale = painterSize.width / cam.focal;

    final double px = (player["x"] as num).toDouble();
    final double py = (player["y"] as num).toDouble();
    final double radius = (player["radius"] as num).toDouble() / 2;
    final String color = player["color"];
    final String direction = player["direction"];

    final Offset screenPos = Offset(
      (px - cam.x) * scale + painterSize.width / 2,
      (py - cam.y) * scale + painterSize.height / 2,
    );

    final Paint paint = Paint()..color = _getColorFromString(color);
    canvas.drawCircle(screenPos, radius * scale, paint);

    final String imgPath = "images/arrows.png";
    if (appData.imagesCache.containsKey(imgPath)) {
      final ui.Image tilesetImage = appData.imagesCache[imgPath]!;
      final Offset tilePos = _getArrowTile(direction);
      const Size tileSize = Size(64, 64);

      final double painterScale = (2 * radius * scale) / tileSize.width;
      final Size scaledSize = Size(tileSize.width * painterScale, tileSize.height * painterScale);

      canvas.drawImageRect(
        tilesetImage,
        Rect.fromLTWH(tilePos.dx, tilePos.dy, tileSize.width, tileSize.height),
        Rect.fromLTWH(
          screenPos.dx - scaledSize.width / 2,
          screenPos.dy - scaledSize.height / 2,
          scaledSize.width,
          scaledSize.height,
        ),
        Paint(),
      );
    }
  }
}
