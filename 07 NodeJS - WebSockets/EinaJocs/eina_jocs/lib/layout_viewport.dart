import 'package:flutter/cupertino.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'game_level.dart';
import 'widgets/editor_labeled_field.dart';
import 'widgets/section_help_button.dart';

// Adaptation mode options shown in the selector.
const List<String> _adaptationLabels = ['Letterbox', 'Expand', 'Stretch'];
const List<String> _adaptationValues = ['letterbox', 'expand', 'stretch'];

// Reference screen aspect ratio used for the preview (16:9).
const double _referenceScreenAspect = 16.0 / 9.0;

class LayoutViewport extends StatefulWidget {
  const LayoutViewport({super.key});

  @override
  LayoutViewportState createState() => LayoutViewportState();
}

class LayoutViewportState extends State<LayoutViewport> {
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _xController = TextEditingController();
  final TextEditingController _yController = TextEditingController();

  // Tracks which level the controllers are currently reflecting.
  int _syncedLevel = -2;

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _xController.dispose();
    _yController.dispose();
    super.dispose();
  }

  void _syncControllers(GameLevel level) {
    _widthController.text = level.viewportWidth.toString();
    _heightController.text = level.viewportHeight.toString();
    _xController.text = level.viewportX.toString();
    _yController.text = level.viewportY.toString();
  }

  /// Called from layout.dart during viewport drag to sync X/Y fields live.
  void syncDragPosition(int x, int y) {
    if (!mounted) return;
    _xController.text = x.toString();
    _yController.text = y.toString();
  }

  int _parseInt(String text, int fallback) {
    return int.tryParse(text.trim()) ?? fallback;
  }

  void _applyChanges(AppData appData) {
    if (appData.selectedLevel == -1) return;
    final level = appData.gameData.levels[appData.selectedLevel];
    final int w = _parseInt(_widthController.text, level.viewportWidth);
    final int h = _parseInt(_heightController.text, level.viewportHeight);
    final int x = _parseInt(_xController.text, level.viewportX);
    final int y = _parseInt(_yController.text, level.viewportY);
    if (w == level.viewportWidth &&
        h == level.viewportHeight &&
        x == level.viewportX &&
        y == level.viewportY) {
      return;
    }
    appData.pushUndo();
    level.viewportWidth = w.clamp(1, 99999);
    level.viewportHeight = h.clamp(1, 99999);
    level.viewportX = x;
    level.viewportY = y;
    appData.update();
    appData.queueAutosave();
  }

  void _setAdaptation(AppData appData, String value) {
    if (appData.selectedLevel == -1) return;
    final level = appData.gameData.levels[appData.selectedLevel];
    if (level.viewportAdaptation == value) return;
    appData.pushUndo();
    level.viewportAdaptation = value;
    appData.update();
    appData.queueAutosave();
  }

  void _setOrientation(AppData appData, bool portrait) {
    if (appData.selectedLevel == -1) return;
    final level = appData.gameData.levels[appData.selectedLevel];
    final bool isPortrait = level.viewportHeight > level.viewportWidth;
    if (portrait == isPortrait) return;
    appData.pushUndo();
    final int tmp = level.viewportWidth;
    level.viewportWidth = level.viewportHeight;
    level.viewportHeight = tmp;
    _widthController.text = level.viewportWidth.toString();
    _heightController.text = level.viewportHeight.toString();
    appData.update();
    appData.queueAutosave();
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);
    final TextStyle sectionTitleStyle = typography.title.copyWith(
      fontSize: (typography.title.fontSize ?? 17) + 2,
    );

    final int selectedLevel = appData.selectedLevel;
    final bool hasLevel = selectedLevel != -1 &&
        selectedLevel < appData.gameData.levels.length;

    // Keep text controllers in sync when the selected level changes.
    if (hasLevel && selectedLevel != _syncedLevel) {
      _syncedLevel = selectedLevel;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncControllers(appData.gameData.levels[selectedLevel]);
          setState(() {});
        }
      });
    } else if (!hasLevel && _syncedLevel != -1) {
      _syncedLevel = -1;
    }

    final GameLevel? level =
        hasLevel ? appData.gameData.levels[selectedLevel] : null;
    final int adaptationIndex = level == null
        ? 0
        : _adaptationValues.indexOf(level.viewportAdaptation).clamp(0, 2);
    final bool isPortrait =
        level != null && level.viewportHeight > level.viewportWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Row(
            children: [
              CDKText(
                'Viewport',
                role: CDKTextRole.title,
                style: sectionTitleStyle,
              ),
              const SizedBox(width: 6),
              const SectionHelpButton(
                message:
                    'The Viewport defines the area of the level that the game camera shows. '
                    'Set its size (in pixels), initial position, and how it adapts when the '
                    'screen is a different resolution or orientation than expected. '
                    'Drag the blue rectangle on the canvas to reposition it.',
              ),
            ],
          ),
        ),

        // ── Empty state ──────────────────────────────────────────────────────
        if (!hasLevel)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CDKText(
                'Select a Level to configure its Viewport.',
                role: CDKTextRole.caption,
                secondary: true,
              ),
            ),
          )
        else
          Expanded(
            child: CupertinoScrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Orientation toggle ───────────────────────────────────
                    EditorLabeledField(
                      label: 'Orientation',
                      child: CDKButtonSelect(
                        selectedIndex: isPortrait ? 1 : 0,
                        options: const ['Landscape', 'Portrait'],
                        onSelected: (int index) {
                          _setOrientation(appData, index == 1);
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Preview ──────────────────────────────────────────────
                    EditorLabeledField(
                      label: 'Screen preview',
                      child: SizedBox(
                        width: double.infinity,
                        height: 110,
                        child: CustomPaint(
                          painter: _ViewportPreviewPainter(
                            viewportW: level!.viewportWidth,
                            viewportH: level.viewportHeight,
                            adaptation: level.viewportAdaptation,
                            isPortrait: isPortrait,
                            backgroundColor: cdkColors.background,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Viewport size ────────────────────────────────────────
                    CDKText(
                      'Viewport size (px)',
                      role: CDKTextRole.caption,
                      color: cdkColors.colorText.withValues(alpha: 0.55),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: EditorLabeledField(
                            label: 'Width',
                            child: CDKFieldText(
                              placeholder: 'Width',
                              controller: _widthController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _applyChanges(appData),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: EditorLabeledField(
                            label: 'Height',
                            child: CDKFieldText(
                              placeholder: 'Height',
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _applyChanges(appData),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Initial position ─────────────────────────────────────
                    CDKText(
                      'Initial position (px)',
                      role: CDKTextRole.caption,
                      color: cdkColors.colorText.withValues(alpha: 0.55),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: EditorLabeledField(
                            label: 'X',
                            child: CDKFieldText(
                              placeholder: 'X',
                              controller: _xController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _applyChanges(appData),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: EditorLabeledField(
                            label: 'Y',
                            child: CDKFieldText(
                              placeholder: 'Y',
                              controller: _yController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _applyChanges(appData),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Screen adaptation mode ───────────────────────────────
                    EditorLabeledField(
                      label: 'Screen adaptation',
                      child: CDKButtonSelect(
                        selectedIndex: adaptationIndex,
                        options: _adaptationLabels,
                        onSelected: (int index) {
                          _setAdaptation(appData, _adaptationValues[index]);
                        },
                      ),
                    ),

                    const SizedBox(height: 6),
                    CDKText(
                      _adaptationDescription(adaptationIndex),
                      role: CDKTextRole.caption,
                      secondary: true,
                    ),

                    const SizedBox(height: 14),

                    // ── Hint ─────────────────────────────────────────────────
                    CDKText(
                      'Drag the blue rectangle on the canvas to reposition the viewport. '
                      'Scroll to zoom the editor view.',
                      role: CDKTextRole.caption,
                      secondary: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _adaptationDescription(int index) {
    switch (index) {
      case 0:
        return 'Letterbox: keeps the aspect ratio and adds bars on the sides or top/bottom.';
      case 1:
        return 'Expand: enlarges the visible area to fill the screen without distortion.';
      case 2:
        return 'Stretch: scales the viewport to fill the screen, ignoring aspect ratio.';
      default:
        return '';
    }
  }
}

// ── Preview painter ─────────────────────────────────────────────────────────

class _ViewportPreviewPainter extends CustomPainter {
  final int viewportW;
  final int viewportH;
  final String adaptation;
  final bool isPortrait;
  final Color backgroundColor;

  const _ViewportPreviewPainter({
    required this.viewportW,
    required this.viewportH,
    required this.adaptation,
    required this.isPortrait,
    required this.backgroundColor,
  });

  bool get _isDark => backgroundColor.computeLuminance() < 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    // Screen aspect ratio used in the preview
    final double screenAspect =
        isPortrait ? 1.0 / _referenceScreenAspect : _referenceScreenAspect;

    // Fit the "screen" rectangle into the available size with some margin
    const double margin = 6.0;
    final double availW = size.width - margin * 2;
    final double availH = size.height - margin * 2;

    late double screenW, screenH;
    if (availW / screenAspect <= availH) {
      screenW = availW;
      screenH = availW / screenAspect;
    } else {
      screenH = availH;
      screenW = availH * screenAspect;
    }

    final double screenL = (size.width - screenW) / 2;
    final double screenT = (size.height - screenH) / 2;
    final Rect screenRect = Rect.fromLTWH(screenL, screenT, screenW, screenH);

    // Screen background
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect, const Radius.circular(4)),
      Paint()
        ..color = _isDark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFE8E8E8)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect, const Radius.circular(4)),
      Paint()
        ..color = _isDark
            ? const Color(0xFF555555)
            : const Color(0xFFBBBBBB)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // Viewport rect inside the screen — depends on adaptation mode
    final double vpAspect = viewportW <= 0 || viewportH <= 0
        ? 1.0
        : viewportW / viewportH;

    late Rect vpRect;
    switch (adaptation) {
      case 'letterbox':
        // Fit entirely inside screen, maintain aspect — bars show as background
        double w, h;
        if (vpAspect >= screenAspect) {
          w = screenW;
          h = screenW / vpAspect;
        } else {
          h = screenH;
          w = screenH * vpAspect;
        }
        vpRect = Rect.fromLTWH(
          screenL + (screenW - w) / 2,
          screenT + (screenH - h) / 2,
          w,
          h,
        );
      case 'expand':
        // Fill screen, maintain aspect — may overflow (clipped to screen)
        double w, h;
        if (vpAspect <= screenAspect) {
          w = screenW;
          h = screenW / vpAspect;
        } else {
          h = screenH;
          w = screenH * vpAspect;
        }
        vpRect = Rect.fromLTWH(
          screenL + (screenW - w) / 2,
          screenT + (screenH - h) / 2,
          w,
          h,
        );
      default: // 'stretch'
        vpRect = screenRect;
    }

    // Clip to screen before drawing viewport fill (for 'expand' overflow)
    canvas.save();
    canvas.clipRRect(
        RRect.fromRectAndRadius(screenRect, const Radius.circular(4)));

    canvas.drawRect(
      vpRect,
      Paint()
        ..color = const Color(0x332196F3)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      vpRect,
      Paint()
        ..color = const Color(0xFF2196F3)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Dashed overflow indicator lines for 'expand'
    if (adaptation == 'expand') {
      final Paint dashPaint = Paint()
        ..color = const Color(0x882196F3)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      // top/bottom overflow lines
      if (vpRect.top < screenT) {
        _drawDashedLine(
            canvas, Offset(vpRect.left, screenT), Offset(vpRect.right, screenT),
            dashPaint);
      }
      if (vpRect.bottom > screenRect.bottom) {
        _drawDashedLine(canvas, Offset(vpRect.left, screenRect.bottom),
            Offset(vpRect.right, screenRect.bottom), dashPaint);
      }
      // left/right overflow lines
      if (vpRect.left < screenL) {
        _drawDashedLine(
            canvas, Offset(screenL, vpRect.top), Offset(screenL, vpRect.bottom),
            dashPaint);
      }
      if (vpRect.right > screenRect.right) {
        _drawDashedLine(canvas, Offset(screenRect.right, vpRect.top),
            Offset(screenRect.right, vpRect.bottom), dashPaint);
      }
    }

    canvas.restore();

    // Size label inside the viewport rect
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '$viewportW×$viewportH',
        style: const TextStyle(
          color: Color(0xFF2196F3),
          fontSize: 8,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: vpRect.width - 4);
    if (tp.width + 4 <= vpRect.width && tp.height + 4 <= vpRect.height) {
      tp.paint(canvas,
          Offset(vpRect.left + 3, vpRect.top + 3));
    }
  }

  void _drawDashedLine(
      Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashLen = 4.0;
    const double gapLen = 3.0;
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double len = (Offset(dx, dy)).distance;
    if (len == 0) return;
    final double ux = dx / len;
    final double uy = dy / len;
    double dist = 0;
    bool drawing = true;
    while (dist < len) {
      final double segLen =
          drawing ? dashLen : gapLen;
      final double end = (dist + segLen).clamp(0, len);
      if (drawing) {
        canvas.drawLine(
          Offset(p1.dx + ux * dist, p1.dy + uy * dist),
          Offset(p1.dx + ux * end, p1.dy + uy * end),
          paint,
        );
      }
      dist += segLen;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(_ViewportPreviewPainter old) =>
      old.viewportW != viewportW ||
      old.viewportH != viewportH ||
      old.adaptation != adaptation ||
      old.isPortrait != isPortrait ||
      old.backgroundColor != backgroundColor;
}
