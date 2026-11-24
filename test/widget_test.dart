import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/main.dart';

void main() {
  testWidgets('Shows the city search and validates empty input', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Weather App'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a city name with at least two letters.'),
      findsOneWidget,
    );
  });
}