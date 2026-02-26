import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:game_example/main.dart';

void main() {
  testWidgets('renders level menu screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GamesToolExampleApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
