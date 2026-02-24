import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'app_data.dart';

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

      for (int li = 0; li < level.layers.length; li++) {
        final layer = level.layers[li];
        if (!appData.imagesCache.containsKey(layer.tilesSheetFile)) continue;

        final bool hidden = layer.visible == false;
        final ui.Image tilesetImg = appData.imagesCache[layer.tilesSheetFile]!;
        final double tw = layer.tilesWidth.toDouble();
        final double th = layer.tilesHeight.toDouble();
        final int tsetCols = (tilesetImg.width / tw).floor();
        if (tsetCols == 0) continue;

        final int rows = layer.tileMap.length;
        final int cols = layer.tileMap.isNotEmpty ? layer.tileMap[0].length : 0;
        final double lx = layer.x.toDouble();
        final double ly = layer.y.toDouble();
        final double lw = cols * tw;
        final double lh = rows * th;

        // Hidden layers: draw at 25% opacity
        final tilePaint = Paint()
          ..color = hidden
              ? const Color(0x40FFFFFF)
              : const Color(0xFFFFFFFF);

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
                lx + col * tw,
                ly + row * th,
                tw,
                th,
              ),
              tilePaint,
            );
          }
        }

        // Draw grid lines over the layer
        final Paint gridPaint = Paint()
          ..color = hidden
              ? const Color(0x1A000000)
              : const Color(0x33000000)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;
        for (int r = 0; r <= rows; r++) {
          canvas.drawLine(Offset(lx, ly + r * th), Offset(lx + lw, ly + r * th), gridPaint);
        }
        for (int c = 0; c <= cols; c++) {
          canvas.drawLine(Offset(lx + c * tw, ly), Offset(lx + c * tw, ly + lh), gridPaint);
        }

        // Hidden layers: diagonal hatch overlay
        if (hidden) {
          final Paint hatchPaint = Paint()
            ..color = const Color(0x22000000)
            ..strokeWidth = 1.0 / vScale
            ..style = PaintingStyle.stroke;
          final double step = tw;
          for (double d = -lh; d < lw; d += step) {
            final double x1 = lx + d;
            final double y1 = ly;
            final double x2 = lx + d + lh;
            final double y2 = ly + lh;
            canvas.drawLine(Offset(x1, y1), Offset(x2, y2), hatchPaint);
          }
          // "Hidden" label in centre of the layer bounds
          if (lw > 0 && lh > 0) {
            final tp = TextPainter(
              text: TextSpan(
                text: layer.name.isNotEmpty ? '${layer.name} (hidden)' : '(hidden)',
                style: TextStyle(
                  color: const Color(0x88000000),
                  fontSize: 11.0 / vScale,
                  fontFamily: 'monospace',
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: lw);
            tp.paint(
              canvas,
              Offset(lx + (lw - tp.width) / 2, ly + (lh - tp.height) / 2),
            );
          }
        }

        // Draw selection border for selected layer
        if (li == appData.selectedLayer) {
          final Paint selPaint = Paint()
            ..color = const Color(0xFF2196F3)
            ..strokeWidth = 2.0 / vScale
            ..style = PaintingStyle.stroke;
          canvas.drawRect(Rect.fromLTWH(lx + 1, ly + 1, lw - 2, lh - 2), selPaint);
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
