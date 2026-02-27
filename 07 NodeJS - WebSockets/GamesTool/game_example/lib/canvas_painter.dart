import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'app_data.dart';

class CanvasPainter extends CustomPainter {
  final AppData appData;

  CanvasPainter(this.appData);

  @override
  void paint(Canvas canvas, Size painterSize) {
    // Draw white background
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, painterSize.width, painterSize.height),
      paint,
    );

    // Draw game state
    var gameState = appData.gameState;
    var gameData = appData.gameData;

    if (gameState.isNotEmpty && gameData.isNotEmpty) {
      // Get level data
      if (gameState["level"] != null) {
        final String levelName = gameState["level"];
        final List<dynamic> levels = appData.gameData["levels"];
        final level = levels.firstWhere(
          (lvl) => lvl["name"] == levelName,
          orElse: () => null,
        );
        
        // Update camera position based on player data
        if (appData.playerData != null) {
          appData.camera.x = appData.playerData["x"].toDouble();
          appData.camera.y = appData.playerData["y"].toDouble();
        }
        
        // Draw the level
        if (level != null) {
          drawLevel(canvas, painterSize, level);
        }
      }

      // Draw the flag
      drawFlag(canvas, painterSize);
      
      // Draw players
      if (gameState["players"] != null) {
        for (var player in gameState["players"]) {
          drawPlayer(canvas, painterSize, player);
        }
      }

      // Draw connection status indicator
      paint.color = appData.isConnected ? Colors.green : Colors.red;
      canvas.drawCircle(Offset(painterSize.width - 10, 10), 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  // Helper method to get camera and scale
  Map<String, dynamic> _getCameraAndScale(Size painterSize) {
    final cam = appData.camera;
    final double scale = painterSize.width / cam.focal;
    return {'cam': cam, 'scale': scale};
  }

  // Helper method to convert world coordinates to screen coordinates
  Offset worldToScreen(double worldX, double worldY, Size painterSize, {double depth = 0}) {
    final camData = _getCameraAndScale(painterSize);
    final cam = camData['cam'];
    final scale = camData['scale'];
    
    final double parallax = depth >= 0 ? 1.0 : 1.0 / (1.0 - depth);
    final double camX = cam.x * parallax;
    final double camY = cam.y * parallax;
    
    return Offset(
      (worldX - camX) * scale + painterSize.width / 2,
      (worldY - camY) * scale + painterSize.height / 2,
    );
  }

  // Helper method to draw any image from spritesheet
  void drawSpriteFromSheet(
    Canvas canvas, 
    ui.Image spriteSheet, 
    Rect srcRect, 
    Offset destPos, 
    Size destSize,
  ) {
    canvas.drawImageRect(
      spriteSheet,
      srcRect,
      Rect.fromLTWH(
        destPos.dx,
        destPos.dy,
        destSize.width,
        destSize.height,
      ),
      Paint(),
    );
  }

  // Get arrow tile position in the spritesheet
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

  // Convert color string to Flutter Color
  static Color _getColorFromString(String color) {
    switch (color.toLowerCase()) {
      case "gray":
        return Colors.grey;
      case "green":
        return const ui.Color.fromARGB(255, 0, 121, 4);
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
    final camData = _getCameraAndScale(painterSize);
    final cam = camData['cam'];
    final scale = camData['scale'];

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
      final tileSheetPath = "flag_game/${layer["tilesSheetFile"]}";

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

  void drawFlag(Canvas canvas, Size painterSize) {
    final level = appData.gameData["levels"].firstWhere(
      (lvl) => lvl["name"] == appData.gameState["level"],
      orElse: () => null,
    );
    if (level == null) return;

    final sprites = level["sprites"] as List<dynamic>;
    final flagSprite = sprites.firstWhere(
      (sprite) => sprite["type"] == "flag",
      orElse: () => null,
    );
    if (flagSprite == null) return;

    final flagOwnerId = appData.gameState["flagOwnerId"];
    final flagHasOwner = flagOwnerId != null && flagOwnerId.isNotEmpty;

    if (!flagHasOwner) {
      // Draw flag at its position if it doesn't have an owner
      final String spritePath = "flag_game/${flagSprite["imageFile"]}";
      if (!appData.imagesCache.containsKey(spritePath)) return;
      
      final ui.Image spriteImg = appData.imagesCache[spritePath]!;
      final int frameCount = (spriteImg.width / flagSprite["width"]).floor();
      final int tickCounter = appData.gameState["tickCounter"] ?? 0;
      final double frameIndex = (tickCounter % frameCount).toDouble();
      final double srcX = frameIndex * flagSprite["width"];
      
      final Offset screenPos = worldToScreen(
        flagSprite["x"].toDouble(),
        flagSprite["y"].toDouble(),
        painterSize,
      );
      
      final camData = _getCameraAndScale(painterSize);
      final scale = camData['scale'];
      final destWidth = flagSprite["width"] * scale;
      final destHeight = flagSprite["height"] * scale;
      
      canvas.drawImageRect(
        spriteImg,
        Rect.fromLTWH(srcX, 0, flagSprite["width"].toDouble(), flagSprite["height"].toDouble()),
        Rect.fromLTWH(
          screenPos.dx - destWidth / 2,
          screenPos.dy - destHeight / 2,
          destWidth,
          destHeight,
        ),
        Paint(),
      );
    } else {
      // Flag owner text
      final flagOwner = appData.getPlayerData(flagOwnerId);
      if (flagOwner != null) {
        final textSpan = TextSpan(
          text: "Player '${flagOwner["color"]}' has the flag",
          style: TextStyle(color: Colors.black, fontSize: 20),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(50, 50));
      }
    }
  }

  void drawPlayer(Canvas canvas, Size painterSize, Map<String, dynamic> player) {
    final camData = _getCameraAndScale(painterSize);
    final scale = camData['scale'];

    final double playerWidth = (player["width"] as num).toDouble();
    final double playerHeight = (player["width"] as num).toDouble();
    final String color = player["color"];
    final String direction = player["direction"];

    // Get player position
    final Offset screenPos = worldToScreen(
      player["x"].toDouble(),
      player["y"].toDouble(),
      painterSize,
    );

    // Draw player rectangle
    final Paint paint = Paint()..color = _getColorFromString(color);
    final rect = Rect.fromLTWH(screenPos.dx, screenPos.dy, playerWidth * scale, playerHeight * scale);
    canvas.drawRect(rect, paint);

    // Draw direction arrow
    final String arrowPath = "images/arrows.png";
    if (appData.imagesCache.containsKey(arrowPath)) {
      final ui.Image arrowsImage = appData.imagesCache[arrowPath]!;
      final Offset tilePos = _getArrowTile(direction);
      const Size tileSize = Size(64, 64); // Arrow tiles are 64x64
      final Size scaledSize = Size(rect.width, rect.height);

      drawSpriteFromSheet(
        canvas,
        arrowsImage,
        Rect.fromLTWH(tilePos.dx, tilePos.dy, tileSize.width, tileSize.height),
        screenPos,
        scaledSize,
      );
    }

    // Draw flag on top of player if they own it
    final flagOwnerId = appData.gameState["flagOwnerId"];
    if (flagOwnerId == player["id"]) {
      // Find flag sprite
      final level = appData.gameData["levels"].firstWhere(
        (lvl) => lvl["name"] == appData.gameState["level"],
        orElse: () => null,
      );
      if (level == null) return;

      final sprites = level["sprites"] as List<dynamic>;
      final flagSprite = sprites.firstWhere(
        (sprite) => sprite["type"] == "flag",
        orElse: () => null,
      );
      if (flagSprite == null) return;

      final String spritePath = "flag_game/${flagSprite["imageFile"]}";
      if (!appData.imagesCache.containsKey(spritePath)) return;
      
      final ui.Image spriteImg = appData.imagesCache[spritePath]!;
      final int frameCount = (spriteImg.width / flagSprite["width"]).floor();
      final int tickCounter = appData.gameState["tickCounter"] ?? 0;
      final double frameIndex = (tickCounter % frameCount).toDouble();
      final double srcX = frameIndex * flagSprite["width"];
      
      // Draw small flag on top of player
      final double flagScale = 0.5; // Make flag smaller than player
      final double flagWidth = flagSprite["width"] * scale * flagScale;
      final double flagHeight = flagSprite["height"] * scale * flagScale;
      
      // Position flag above player
      final Offset flagPos = Offset(
        screenPos.dx,
        screenPos.dy,
      );
      
      canvas.drawImageRect(
        spriteImg,
        Rect.fromLTWH(srcX, 0, flagSprite["width"].toDouble(), flagSprite["height"].toDouble()),
        Rect.fromLTWH(
          flagPos.dx + playerWidth / 2,
          flagPos.dy - flagHeight,
          flagWidth,
          flagHeight,
        ),
        Paint(),
      );
    }
  }
}