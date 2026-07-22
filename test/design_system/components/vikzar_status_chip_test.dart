import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/design_system/components/vikzar_status_chip.dart';
import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/design_system/theme/brand_colors.dart';

void main() {
  group('VikzarStatusChip', () {
    testWidgets('renders its label and defaults to Mineral Blue', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: VikzarStatusChip(label: 'Fully Available')),
        ),
      );

      expect(find.text('Fully Available'), findsOneWidget);
      final text = tester.widget<Text>(find.text('Fully Available'));
      expect(text.style?.color, BrandColors.mineralBlue);
    });

    testWidgets('accepts an explicit colour override', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: VikzarStatusChip(label: 'Unavailable', color: Colors.red),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Unavailable'));
      expect(text.style?.color, Colors.red);
    });

    testWidgets('renders an optional leading icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: VikzarStatusChip(label: 'Connected', icon: Icons.sensors),
          ),
        ),
      );

      expect(find.byIcon(Icons.sensors), findsOneWidget);
    });
  });
}
