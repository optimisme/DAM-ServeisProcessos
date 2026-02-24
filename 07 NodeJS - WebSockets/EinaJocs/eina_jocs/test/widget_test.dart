// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:eina_jocs/app.dart';
import 'package:eina_jocs/app_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App renders editor layout', (WidgetTester tester) async {
    final appData = AppData()
      ..storageReady = true
      ..projectsPath = '/tmp/eina_jocs_test_projects';

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => appData,
        child: const App(),
      ),
    );

    await tester.pump();

    expect(find.text('Projects'), findsWidgets);
    expect(find.text('Import ZIP'), findsNWidgets(2));
    expect(find.text('Export ZIP'), findsNWidgets(2));
  });
}
