import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'app_data.dart';
import 'layout_utils.dart';

class CanvasPainter extends CustomPainter {
  final ui.Image layerImage;
  final AppData appData;

  CanvasPainter(this.layerImage, this.appData);

  @override
  void paint(Canvas canvas, Size size) {
    if (appData.selectedSection == 'layers') {
      _paintLayersViewport(canvas, size);
    } else {
      _paintDefault(canvas, size);
    }
  }

  // ─── Default (fit-to-canvas) rendering used by all sections except layers ──

  void _paintDefault(Canvas canvas, Size size) {
    final double imageWidth = layerImage.width.toDouble();
    final double imageHeight = layerImage.height.toDouble();
    final double availableWidth = size.width * 0.95;
    final double availableHeight = size.height * 0.95;

    final double scaleX = availableWidth / imageWidth;
    final double scaleY = availableHeight / imageHeight;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double scaledWidth = imageWidth * scale;
    final double scaledHeight = imageHeight * scale;
    final double dx = (size.width - scaledWidth) / 2;
    final double dy = (size.height - scaledHeight) / 2;

    appData.scaleFactor = scale;
    appData.imageOffset = Offset(dx, dy);

    canvas.drawImageRect(
      layerImage,
      Rect.fromLTWH(0, 0, imageWidth, imageHeight),
      Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight),
      Paint(),
    );

    // Dragging tile ghost (tilemap section)
    if (appData.selectedSection == 'tilemap' &&
        appData.draggingTileIndex != -1 &&
        appData.selectedLevel != -1 &&
        appData.selectedLayer != -1) {
      final level = appData.gameData.levels[appData.selectedLevel];
      final layer = level.layers[appData.selectedLayer];
      final tilesSheetFile = layer.tilesSheetFile;

      if (appData.imagesCache.containsKey(tilesSheetFile)) {
        final ui.Image tilesetImage = appData.imagesCache[tilesSheetFile]!;
        final double tileWidth = layer.tilesWidth.toDouble();
        final double tileHeight = layer.tilesHeight.toDouble();
        final int tilesetColumns = (tilesetImage.width / tileWidth).floor();
        final int tileIndex = appData.draggingTileIndex;
        final int tileRow = (tileIndex / tilesetColumns).floor();
        final int tileCol = tileIndex % tilesetColumns;

        canvas.drawImageRect(
          tilesetImage,
          Rect.fromLTWH(tileCol * tileWidth, tileRow * tileHeight, tileWidth, tileHeight),
          Rect.fromLTWH(
            appData.draggingOffset.dx - tileWidth / 2,
            appData.draggingOffset.dy - tileHeight / 2,
            tileWidth,
            tileHeight,
          ),
          Paint(),
        );
      }
    }
  }

  // ─── Layers viewport: zoom + pan + axis ─────────────────────────────────────

  void _paintLayersViewport(Canvas canvas, Size size) {
    final double vScale = appData.layersViewScale;
    final Offset vOffset = appData.layersViewOffset;

    // Store for hit-testing in layout_utils (compatible with translateCoords)
    appData.scaleFactor = vScale;
    appData.imageOffset = vOffset;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Apply viewport transform: world → screen
    canvas.translate(vOffset.dx, vOffset.dy);
    canvas.scale(vScale);

    // Draw each layer directly in world space from the image cache
    if (appData.selectedLevel != -1) {
      final level = appData.gameData.levels[appData.selectedLevel];

      for (int li = level.layers.length - 1; li >= 0; li--) {
        final layer = level.layers[li];
        if (layer.visible == false) continue;
        if (!appData.imagesCache.containsKey(layer.tilesSheetFile)) continue;

        final ui.Image tilesetImg = appData.imagesCache[layer.tilesSheetFile]!;
        final double tw = layer.tilesWidth.toDouble();
        final double th = layer.tilesHeight.toDouble();
        final int tsetCols = (tilesetImg.width / tw).floor();
        if (tsetCols == 0) continue;

        final int rows = layer.tileMap.length;
        final int cols = layer.tileMap.isNotEmpty ? layer.tileMap[0].length : 0;
        final double lx = layer.x.toDouble();
        final double ly = layer.y.toDouble();
        final double parallax = LayoutUtils.parallaxFactorForDepth(layer.depth);
        final double parallaxDx = (vOffset.dx * (parallax - 1.0)) / vScale;
        final double parallaxDy = (vOffset.dy * (parallax - 1.0)) / vScale;
        final double drawLx = lx + parallaxDx;
        final double drawLy = ly + parallaxDy;
        final double lw = cols * tw;
        final double lh = rows * th;

        final Paint tilePaint = Paint()..color = const Color(0xFFFFFFFF);

        for (int row = 0; row < rows; row++) {
          for (int col = 0; col < cols; col++) {
            final int tileIndex = layer.tileMap[row][col];
            if (tileIndex < 0) continue;

            final int tileRow = (tileIndex / tsetCols).floor();
            final int tileCol = tileIndex % tsetCols;

            canvas.drawImageRect(
              tilesetImg,
              Rect.fromLTWH(tileCol * tw, tileRow * th, tw, th),
              Rect.fromLTWH(
                drawLx + col * tw,
                drawLy + row * th,
                tw,
                th,
              ),
              tilePaint,
            );
          }
        }

        // Draw grid lines over the layer
        final Paint gridPaint = Paint()
          ..color = const Color(0x33000000)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;
        for (int r = 0; r <= rows; r++) {
          canvas.drawLine(
            Offset(drawLx, drawLy + r * th),
            Offset(drawLx + lw, drawLy + r * th),
            gridPaint,
          );
        }
        for (int c = 0; c <= cols; c++) {
          canvas.drawLine(
            Offset(drawLx + c * tw, drawLy),
            Offset(drawLx + c * tw, drawLy + lh),
            gridPaint,
          );
        }

        // Draw selection border for selected layer
        if (li == appData.selectedLayer) {
          final Paint selPaint = Paint()
            ..color = const Color(0xFF2196F3)
            ..strokeWidth = 2.0 / vScale
            ..style = PaintingStyle.stroke;
          canvas.drawRect(
            Rect.fromLTWH(drawLx + 1, drawLy + 1, lw - 2, lh - 2),
            selPaint,
          );
        }
      }
    }

    canvas.restore();

    // Draw axes on top (in screen space)
    _paintAxes(canvas, size, vScale, vOffset);
  }

  void _paintAxes(Canvas canvas, Size size, double vScale, Offset vOffset) {
    // World origin in screen space
    final double ox = vOffset.dx;
    final double oy = vOffset.dy;

    const double axisThickness = 1.5;
    const double tickLen = 5.0;
    const double labelFontSize = 9.0;
    const double minTickSpacingPx = 40.0;

    // Choose a world-space tick interval that gives reasonable screen spacing
    double worldTickInterval = 32.0;
    while (worldTickInterval * vScale < minTickSpacingPx) {
      worldTickInterval *= 2;
    }
    while (worldTickInterval * vScale > minTickSpacingPx * 4) {
      worldTickInterval /= 2;
    }

    final Paint axisPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.55)
      ..strokeWidth = axisThickness
      ..style = PaintingStyle.stroke;

    final Paint tickPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.45)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textStyle = TextStyle(
      color: Colors.grey.shade500,
      fontSize: labelFontSize,
      fontFamily: 'monospace',
    );

    // ── X axis ──────────────────────────────────────────────────────────────
    // Clamp axis line to visible area
    final double axisY = oy.clamp(0.0, size.height);
    canvas.drawLine(Offset(0, axisY), Offset(size.width, axisY), axisPaint);

    // Ticks and labels along X
    final double firstWorldX =
        ((-ox / vScale) / worldTickInterval).ceil() * worldTickInterval;
    double worldX = firstWorldX;
    while (true) {
      final double screenX = ox + worldX * vScale;
      if (screenX > size.width + 1) break;
      if (screenX >= -1) {
        canvas.drawLine(
          Offset(screenX, axisY - tickLen),
          Offset(screenX, axisY + tickLen),
          tickPaint,
        );
        if (worldX != 0) {
          _drawLabel(
            canvas,
            worldX.toInt().toString(),
            Offset(screenX + 2, axisY + tickLen + 1),
            textStyle,
          );
        }
      }
      worldX += worldTickInterval;
    }

    // ── Y axis ──────────────────────────────────────────────────────────────
    final double axisX = ox.clamp(0.0, size.width);
    canvas.drawLine(Offset(axisX, 0), Offset(axisX, size.height), axisPaint);

    // Ticks and labels along Y
    final double firstWorldY =
        ((-oy / vScale) / worldTickInterval).ceil() * worldTickInterval;
    double worldY = firstWorldY;
    while (true) {
      final double screenY = oy + worldY * vScale;
      if (screenY > size.height + 1) break;
      if (screenY >= -1) {
        canvas.drawLine(
          Offset(axisX - tickLen, screenY),
          Offset(axisX + tickLen, screenY),
          tickPaint,
        );
        if (worldY != 0) {
          _drawLabel(
            canvas,
            worldY.toInt().toString(),
            Offset(axisX + tickLen + 2, screenY - labelFontSize - 1),
            textStyle,
          );
        }
      }
      worldY += worldTickInterval;
    }

    // ── Origin label ────────────────────────────────────────────────────────
    _drawLabel(
      canvas,
      '0',
      Offset(axisX + 3, axisY + 3),
      textStyle,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset position, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return true;
  }
}
