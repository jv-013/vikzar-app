import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/design_system/components/vikzar_otp_field.dart';
import 'package:vikzar/design_system/theme/app_theme.dart';

void main() {
  group('VikzarOtpField', () {
    testWidgets('renders 6 boxes by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: VikzarOtpField(onCompleted: (_) {})),
        ),
      );

      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('typing into the first box distributes a pasted code across '
        'all boxes and fires onCompleted', (tester) async {
      String? completed;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: VikzarOtpField(onCompleted: (value) => completed = value),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pumpAndSettle();

      expect(completed, '123456');
      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields.map((f) => f.controller?.text).toList(), [
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
      ]);
    });

    testWidgets('shows the error text when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: VikzarOtpField(onCompleted: (_) {}, errorText: 'Try again'),
          ),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
