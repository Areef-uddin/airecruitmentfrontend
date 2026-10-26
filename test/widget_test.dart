import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/shared/widgets/app_button.dart';
import 'package:frontend/shared/widgets/status_badge.dart';
import 'package:frontend/shared/widgets/score_gauge.dart';

void main() {
  testWidgets('AppButton renders label and triggers callback', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Get Started',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Get Started'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    expect(tapped, isTrue);
  });

  testWidgets('StatusBadge displays correct text and styling', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StatusBadge(status: 'SHORTLISTED'),
              StatusBadge(status: 'INTERVIEW'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Shortlisted'), findsOneWidget);
    expect(find.text('Interview'), findsOneWidget);
  });

  testWidgets('ScoreGauge displays score value correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScoreGauge(score: 93),
        ),
      ),
    );

    expect(find.text('93'), findsOneWidget);
  });
}
