import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';

class LayoutTilemaps extends StatefulWidget {
  const LayoutTilemaps({super.key});

  @override
  LayoutTilemapsState createState() => LayoutTilemapsState();
}

class LayoutTilemapsState extends State<LayoutTilemaps> {
  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    final typography = CDKThemeNotifier.typographyTokensOf(context);

    final bool hasLevel = appData.selectedLevel != -1;
    final bool hasLayer = hasLevel && appData.selectedLayer != -1;

    String message;
    if (!hasLevel) {
      message = 'Select a level to edit tilemaps.';
    } else if (!hasLayer) {
      message = 'Select a layer to edit its tilemap.';
    } else {
      message = '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: CDKText(
            'Tilemap',
            role: CDKTextRole.title,
            style: typography.title.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (hasLayer)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CDKText(
              'Layer: ${appData.gameData.levels[appData.selectedLevel].layers[appData.selectedLayer].name}',
              role: CDKTextRole.bodyStrong,
              color: cdkColors.colorText,
            ),
          ),
        Expanded(
          child: Center(
            child: CDKText(
              hasLayer
                  ? 'Use the canvas to paint tiles and the tileset to pick indices.'
                  : message,
              role: CDKTextRole.body,
              secondary: !hasLayer,
              color: hasLayer ? cdkColors.colorText : null,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
