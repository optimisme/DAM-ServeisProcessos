import 'package:flutter/cupertino.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'layout.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const CDKApp(
      defaultAppearance: CDKThemeAppearance.system,
      defaultColor: "systemBlue",
      child: Layout(title: "Level builder"),
    );
  }
}
