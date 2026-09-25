import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practsearch/features/research/presentation/pages/ask_page.dart';

void main() {
  testWidgets('Ask screen rejects a question too short to retrieve against',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AskPage())),
    );

    await tester.enterText(find.byType(TextField), 'fake news');
    await tester.tap(find.text('Research'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.textContaining('Ask a fuller question'),
      findsOneWidget,
      reason: 'Validation lives in the use case and must surface in the field',
    );
  });
}
