import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'app_data.dart';
import 'app.dart';

const _windowTitle = 'Games Tool';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureDesktopWindow();
  final appData = AppData();
  await appData.initializeStorage();

  runApp(
    ChangeNotifierProvider.value(
      value: appData,
      child: const App(),
    ),
  );
}

Future<void> _configureDesktopWindow() async {
  if (kIsWeb) return;

  final isDesktop = defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  if (!isDesktop) return;

  try {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      title: _windowTitle,
      size: Size(1600, 980),
      minimumSize: Size(1280, 820),
      center: true,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    await windowManager.setTitle(_windowTitle);
  } catch (_) {
    // Ignore when desktop window APIs are unavailable at runtime.
  }
}
