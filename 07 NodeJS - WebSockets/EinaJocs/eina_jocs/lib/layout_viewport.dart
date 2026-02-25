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
                    'screen is a different resolution or orientation than expected.',
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
                          _setAdaptation(
                              appData, _adaptationValues[index]);
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

                    // ── Preview info ─────────────────────────────────────────
                    CDKText(
                      'The main area shows the level rendered through the viewport. '
                      'Drag to move the viewport position. Scroll to zoom the editor view.',
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
