import 'dart:io';

import 'package:dsl/dsl.dart';
import 'package:dsl_note/editor/dsl_text_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _schema = Schema.fromYaml(
  File('../../packages/dsl/assets/keywords.yaml').readAsStringSync(),
);

void main() {
  testWidgets('highlights without changing the text', (tester) async {
    const text =
        'Note\nmedia "images/a b.png" Bad\nappointment 26-10-12\n'
        '-> see @other\nextra\nmore\n';
    final controller = DslTextController(schema: _schema, text: text);
    late TextSpan span;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              withComposing: false,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(span.toPlainText(), text);
    final pieces = {
      for (final child in span.children!.cast<TextSpan>())
        child.text!: child.style!,
    };
    expect(pieces['appointment']!.fontWeight, FontWeight.bold);
    expect(pieces['26-10-12']!.color, isNotNull);
    expect(pieces['Bad']!.decorationStyle, TextDecorationStyle.wavy);
    expect(pieces['Note\n']!.color, isNull);
  });
}
