import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'app_data.dart';
import 'game_layer.dart';

class LayoutUtils {
  static Future<ui.Image> generateTilemapImage(
      AppData appData, int levelIndex, int layerIndex, bool drawGrid) async {
    final level = appData.gameData.levels[levelIndex];
    final layer = level.layers[layerIndex];

    int rows = layer.tileMap.length;
    int cols = layer.tileMap[0].length;
    double tileWidth = layer.tilesWidth.toDouble();
    double tileHeight = layer.tilesHeight.toDouble();
    double tilemapWidth = cols * tileWidth;
    double tilemapHeight = rows * tileHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final ui.Image tilesetImage = await appData.getImage(layer.tilesSheetFile);

    // Obtenir el nombre de columnes al tileset
    int tilesetColumns = (tilesetImage.width / tileWidth).floor();

    // Dibuixar els tiles segons el `tileMap`
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        int tileIndex = layer.tileMap[row][col];

        if (tileIndex >= 0) {
          // Només dibuixar si el tileIndex és vàlid
          int tileRow = (tileIndex / tilesetColumns).floor();
          int tileCol = (tileIndex % tilesetColumns);

          double tileX = tileCol * tileWidth;
          double tileY = tileRow * tileHeight;

          // Posició al tilemap
          double destX = col * tileWidth;
          double destY = row * tileHeight;

          // Dibuixar el tile corresponent
          canvas.drawImageRect(
            tilesetImage,
            Rect.fromLTWH(tileX, tileY, tileWidth, tileHeight),
            Rect.fromLTWH(destX, destY, tileWidth, tileHeight),
            Paint(),
          );
        }
      }
    }

    if (drawGrid) {
      final textStyle = TextStyle(
        color: Colors.black,
        fontSize: 10,
      );
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );

      final gridPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      for (int row = 0; row <= rows; row++) {
        double y = row * tileHeight;
        canvas.drawLine(Offset(0, y), Offset(tilemapWidth, y), gridPaint);

        // Draw row number at the left
        if (row < rows) {
          textPainter.text = TextSpan(
            text: '$y',
            style: textStyle,
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(0, y));
        }
      }

      for (int col = 0; col <= cols; col++) {
        double x = col * tileWidth;
        canvas.drawLine(Offset(x, 0), Offset(x, tilemapHeight), gridPaint);

        // Draw column number at the top
        if (col < cols) {
          textPainter.text = TextSpan(
            text: '$x',
            style: textStyle,
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(x, 0));
        }
      }
    }

    final picture = recorder.endRecording();
    return await picture.toImage(tilemapWidth.toInt(), tilemapHeight.toInt());
  }

  static Future<ui.Image> generateTilesetImage(
      AppData appData,
      String tilesetPath,
      double tileWidth,
      double tileHeight,
      bool drawGrid) async {
    final tilesheetImage = await appData.getImage(tilesetPath);

    double imageWidth = tilesheetImage.width.toDouble();
    double imageHeight = tilesheetImage.height.toDouble();

    int tilesetColumns = (imageWidth / tileWidth).floor();
    int tilesetRows = (imageHeight / tileHeight).floor();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(tilesheetImage, Offset.zero, Paint());

    if (drawGrid) {
      final gridPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      for (int row = 0; row <= tilesetRows; row++) {
        double y = row * tileHeight;
        canvas.drawLine(Offset(0, y), Offset(imageWidth, y), gridPaint);
      }

      for (int col = 0; col <= tilesetColumns; col++) {
        double x = col * tileWidth;
        canvas.drawLine(Offset(x, 0), Offset(x, imageHeight), gridPaint);
      }
    }

    final picture = recorder.endRecording();
    final tilesetImage =
        await picture.toImage(imageWidth.toInt(), imageHeight.toInt());

    return tilesetImage;
  }

  static Future<ui.Image> drawCanvasImageEmpty(AppData appData) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Cal dibuixar algo perquè "recorder" no falli
    canvas.drawRect(
        Rect.fromLTWH(0, 0, 10, 10), Paint()..color = Colors.transparent);

    final picture = recorder.endRecording();
    return await picture.toImage(10, 10);
  }

  static Future<ui.Image> drawCanvasImageLayers(
      AppData appData, bool drawGrid) async {
    if (appData.selectedLevel == -1) {
      return await drawCanvasImageEmpty(appData);
    }

    final level = appData.gameData.levels[appData.selectedLevel];
    final recorder = ui.PictureRecorder();
    final imgCanvas = Canvas(recorder);

    int imageWidth = 10;
    int imageHeight = 10;

    // Draw level layers
    for (var layer in level.layers) {
      if (layer.visible == false) {
        continue;
      }
      final tilemapImage = await generateTilemapImage(appData,
          appData.selectedLevel, level.layers.indexOf(layer), drawGrid);

      imgCanvas.drawImage(tilemapImage,
          Offset(layer.x.toDouble(), layer.y.toDouble()), Paint());

      imageWidth = imageWidth > (layer.x + tilemapImage.width)
          ? imageWidth
          : (layer.x + tilemapImage.width);
      imageHeight = imageHeight > (layer.y + tilemapImage.height)
          ? imageHeight
          : (layer.y + tilemapImage.height);
    }

    // Draw level zones
    for (int cntZone = 0; cntZone < level.zones.length; cntZone = cntZone + 1) {
      final zone = level.zones[cntZone];
      final zoneX = zone.x.toDouble();
      final zoneY = zone.y.toDouble();
      final zoneWidth = zone.width.toDouble();
      final zoneHeight = zone.height.toDouble();
      imgCanvas.drawRect(Rect.fromLTWH(zoneX, zoneY, zoneWidth, zoneHeight),
          Paint()..color = getColorFromName(zone.color).withAlpha(100));
      if (appData.selectedSection == "zones" &&
          cntZone == appData.selectedZone) {
        drawSelectedRect(
          imgCanvas,
          Rect.fromLTWH(zoneX, zoneY, zoneWidth, zoneHeight),
          getColorFromName(zone.color),
        );
      }
    }

    // Draw sprites
    for (int cntSprite = 0;
        cntSprite < level.sprites.length;
        cntSprite = cntSprite + 1) {
      final sprite = level.sprites[cntSprite];
      final spriteImage = await appData.getImage(sprite.imageFile);
      double spriteX = sprite.x.toDouble();
      final spriteY = sprite.y.toDouble();
      final spriteWidth = sprite.spriteWidth.toDouble();
      final spriteHeight = sprite.spriteHeight.toDouble();

      double frames = spriteImage.width / spriteWidth;
      final spriteFrameX = ((appData.frame % frames) * spriteWidth);

      imgCanvas.drawImageRect(
        spriteImage,
        Rect.fromLTWH(spriteFrameX, 0, spriteWidth, spriteHeight),
        Rect.fromLTWH(spriteX, spriteY, spriteWidth, spriteHeight),
        Paint(),
      );
      if (appData.selectedSection == "sprites" &&
          cntSprite == appData.selectedSprite) {
        drawSelectedRect(
            imgCanvas,
            Rect.fromLTWH(spriteX, spriteY, spriteWidth, spriteHeight),
            Colors.blue);
      }
    }

    // Draw selected layer border (if in "layers")
    if (appData.selectedLayer != -1 && appData.selectedSection == "layers") {
      final layer = level.layers[appData.selectedLayer];
      final selectedX = (layer.x + 1).toDouble();
      final selectedY = (layer.y + 1).toDouble();
      final selectedWidth =
          (layer.tileMap[0].length * layer.tilesWidth - 2).toDouble();
      final selectedHeight =
          (layer.tileMap.length * layer.tilesHeight - 2).toDouble();
      drawSelectedRect(
        imgCanvas,
        Rect.fromLTWH(selectedX, selectedY, selectedWidth, selectedHeight),
        Colors.blue,
      );
    }

    final picture = recorder.endRecording();
    return await picture.toImage(imageWidth, imageHeight);
  }

  static Future<ui.Image> drawCanvasImageTilemap(AppData appData) async {
    if (appData.selectedLevel == -1 || appData.selectedLayer == -1) {
      return await drawCanvasImageEmpty(appData);
    }

    final level = appData.gameData.levels[appData.selectedLevel];
    final layer = level.layers[appData.selectedLayer];

    await appData.getImage(layer.tilesSheetFile);

    final recorder = ui.PictureRecorder();
    final imgCanvas = Canvas(recorder);

    // Obtenir imatge del tilemap amb la quadrícula
    final tilemapImage = await generateTilemapImage(
        appData, appData.selectedLevel, appData.selectedLayer, true);

    // Calcular l'escala i la posició del tilemap al canvas
    double availableWidth = tilemapImage.width * 0.95;
    double availableHeight = tilemapImage.height * 0.95;

    double scaleX = availableWidth / tilemapImage.width;
    double scaleY = availableHeight / tilemapImage.height;
    double tilemapScale = scaleX < scaleY ? scaleX : scaleY;

    double scaledTilemapWidth = tilemapImage.width * tilemapScale;
    double scaledTilemapHeight = tilemapImage.height * tilemapScale;

    double tilemapX = (tilemapImage.width - scaledTilemapWidth) / 2;
    double tilemapY = (tilemapImage.height - scaledTilemapHeight) / 2;

    // Guardar offset i escala del tilemap a AppData
    appData.tilemapOffset = Offset(tilemapX, tilemapY);
    appData.tilemapScaleFactor = tilemapScale;

    imgCanvas.drawImageRect(
      tilemapImage,
      Rect.fromLTWH(
          0, 0, tilemapImage.width.toDouble(), tilemapImage.height.toDouble()),
      Rect.fromLTWH(
          tilemapX, tilemapY, scaledTilemapWidth, scaledTilemapHeight),
      Paint(),
    );

    // Obtenir imatge del tileset amb la quadrícula
    final tilesetImage = await generateTilesetImage(
        appData,
        layer.tilesSheetFile,
        layer.tilesWidth.toDouble(),
        layer.tilesHeight.toDouble(),
        true);

    // Calcular la posició i mida escalada del tileset
    double tilesetMaxWidth = tilemapImage.width * 0.5;
    double tilesetMaxHeight = tilemapImage.height.toDouble();
    double tilesetX = tilemapImage.width + 10;

    double tilesetScale =
        (tilesetMaxWidth / tilesetImage.width).clamp(0.0, 1.0);
    if (tilesetImage.height * tilesetScale > tilesetMaxHeight) {
      tilesetScale = (tilesetMaxHeight / tilesetImage.height).clamp(0.0, 1.0);
    }

    double scaledTilesetWidth = tilesetImage.width * tilesetScale;
    double scaledTilesetHeight = tilesetImage.height * tilesetScale;
    double centeredTilesetX =
        tilesetX + (tilesetMaxWidth - scaledTilesetWidth) / 2;
    double centeredTilesetY = (tilesetMaxHeight - scaledTilesetHeight) / 2;

    // Guardar offset i escala del tileset a AppData
    appData.tilesetOffset = Offset(centeredTilesetX, centeredTilesetY);
    appData.tilesetScaleFactor = tilesetScale;

    // Dibuixar el tileset escalat amb la quadrícula
    imgCanvas.drawImageRect(
      tilesetImage,
      Rect.fromLTWH(
          0, 0, tilesetImage.width.toDouble(), tilesetImage.height.toDouble()),
      Rect.fromLTWH(centeredTilesetX, centeredTilesetY, scaledTilesetWidth,
          scaledTilesetHeight),
      Paint(),
    );

    final picture = recorder.endRecording();
    return await picture.toImage(
        (tilemapImage.width + tilesetMaxWidth + 10).toInt(),
        tilemapImage.height);
  }

  static Offset translateCoords(
      Offset coords, Offset offset, double scaleFactor) {
    return Offset(
      (coords.dx - offset.dx) / scaleFactor,
      (coords.dy - offset.dy) / scaleFactor,
    );
  }

  static Future<int> tileIndexFromTilesetCoords(
      Offset coords, AppData appData, GameLayer layer) async {
    final tilesheetImage = await appData.getImage(layer.tilesSheetFile);

    double imageWidth = tilesheetImage.width.toDouble();
    double imageHeight = tilesheetImage.height.toDouble();

    // Si està fora dels límits del tileset, retornem -1
    if (coords.dx < 0 ||
        coords.dy < 0 ||
        coords.dx >= imageWidth ||
        coords.dy >= imageHeight) {
      return -1;
    }

    // Calcular la columna i la fila del tile
    int col = (coords.dx / layer.tilesWidth).floor();
    int row = (coords.dy / layer.tilesHeight).floor();

    int tilesetColumns = (imageWidth / layer.tilesWidth).floor();

    // Retornar l'índex del tile dins del tileset
    return row * tilesetColumns + col;
  }

  static Future<void> dragTileIndexFromTileset(
      AppData appData, Offset localPosition) async {
    if (appData.selectedLevel == -1 || appData.selectedLayer == -1) {
      return;
    }

    final level = appData.gameData.levels[appData.selectedLevel];
    final layer = level.layers[appData.selectedLayer];

    if (layer.tilesWidth <= 0 || layer.tilesHeight <= 0) {
      return;
    }

    // Convertir de coordenades de canvas a coordenades d'imatge
    Offset imageCoords = translateCoords(
        localPosition, appData.imageOffset, appData.scaleFactor);

    // Convertir de coordenades d'imatge a coordenades del tileset
    Offset tilesetCoords = translateCoords(
        imageCoords, appData.tilesetOffset, appData.tilesetScaleFactor);

    appData.draggingTileIndex =
        await tileIndexFromTilesetCoords(tilesetCoords, appData, layer);
    appData.draggingOffset = localPosition;
  }

  static Offset? getTilemapCoords(AppData appData, Offset localPosition) {
    if (appData.selectedLevel == -1 || appData.selectedLayer == -1) {
      return null;
    }

    final level = appData.gameData.levels[appData.selectedLevel];
    final layer = level.layers[appData.selectedLayer];

    if (layer.tilesWidth <= 0 || layer.tilesHeight <= 0) {
      return null;
    }

    // Convertir de coordenades de canvas a coordenades d'imatge
    Offset imageCoords = translateCoords(
        localPosition, appData.imageOffset, appData.scaleFactor);

    // Convertir de coordenades d'imatge a coordenades del tilemap
    Offset tilemapCoords = translateCoords(
        imageCoords, appData.tilemapOffset, appData.tilemapScaleFactor);

    double tilemapWidth = layer.tilesWidth * layer.tileMap[0].length.toDouble();
    double tilemapHeight = layer.tilesHeight * layer.tileMap.length.toDouble();

    // Verificar si està fora dels límits del tilemap
    if (tilemapCoords.dx < 0 ||
        tilemapCoords.dy < 0 ||
        tilemapCoords.dx >= tilemapWidth ||
        tilemapCoords.dy >= tilemapHeight) {
      return null;
    }

    // Calcular la fila i columna al tilemap
    int col = (tilemapCoords.dx / layer.tilesWidth).floor();
    int row = (tilemapCoords.dy / layer.tilesHeight).floor();

    return Offset(row.toDouble(), col.toDouble());
  }

  static void dropTileIndexFromTileset(AppData appData, Offset localPosition) {
    Offset? tileCoords = getTilemapCoords(appData, localPosition);
    if (tileCoords == null) return;

    final level = appData.gameData.levels[appData.selectedLevel];
    final layer = level.layers[appData.selectedLayer];

    int row = tileCoords.dx.toInt();
    int col = tileCoords.dy.toInt();

    layer.tileMap[row][col] = appData.draggingTileIndex;
  }

  static void removeTileIndexFromTileset(
      AppData appData, Offset localPosition) {
    Offset? tileCoords = getTilemapCoords(appData, localPosition);
    if (tileCoords == null) return;

    final level = appData.gameData.levels[appData.selectedLevel];
    final layer = level.layers[appData.selectedLayer];

    int row = tileCoords.dx.toInt();
    int col = tileCoords.dy.toInt();

    layer.tileMap[row][col] = -1;
  }

  static Color getColorFromName(String colorName) {
    switch (colorName) {
      case "blue":
        return Colors.blue;
      case "green":
        return Colors.green;
      case "yellow":
        return Colors.yellow;
      case "orange":
        return Colors.orange;
      case "red":
        return Colors.red;

      case "purple":
        return Colors.purple;
      case "grey":
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  static drawSelectedRect(Canvas cnv, Rect rect, Color color) {
    cnv.drawRect(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
