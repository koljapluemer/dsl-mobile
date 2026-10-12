import 'package:dsl/dsl.dart';
import 'package:flutter/material.dart';

/// A text controller that highlights item text as the user types: keywords,
/// options and values by type, relationships, the extra block, and a wavy
/// underline under each error or warning. The parse is redone only when the
/// text changes.
class DslTextController extends TextEditingController {
  DslTextController({required this.schema, super.text});

  final Schema schema;

  String? _parsedText;
  Document _doc = const Document();

  /// The current text, parsed.
  Document get document {
    if (_parsedText != text) {
      _doc = parseDocument(schema, text);
      _parsedText = text;
    }
    return _doc;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final doc = document;
    final colors = Theme.of(context).colorScheme;
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;

    // Every offset where some style starts or ends; between two of them the
    // style is constant.
    final cuts = <int>{0, text.length};
    for (final s in doc.spans) {
      cuts.addAll([s.from, s.to]);
    }
    final problems = [
      for (final d in doc.diagnostics)
        if (d.from != null && d.to != null) d,
    ];
    for (final d in problems) {
      cuts.addAll([d.from!, d.to!]);
    }
    if (composing.isValid) cuts.addAll([composing.start, composing.end]);
    final sorted = cuts.where((c) => c >= 0 && c <= text.length).toList()
      ..sort();

    final children = <TextSpan>[];
    for (var i = 0; i + 1 < sorted.length; i++) {
      final from = sorted[i];
      final to = sorted[i + 1];
      if (from == to) continue;
      final span = doc.spans
          .where((s) => s.from <= from && to <= s.to)
          .lastOrNull;
      final problem = problems
          .where((d) => d.from! <= from && to <= d.to!)
          .firstOrNull;
      final inComposing =
          composing.isValid && composing.start <= from && to <= composing.end;
      var segment = span == null
          ? const TextStyle()
          : _style(span.kind, colors);
      if (problem != null || inComposing) {
        segment = segment.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: problem != null ? TextDecorationStyle.wavy : null,
          decorationColor: problem == null
              ? null
              : problem.code.isError
              ? colors.error
              : colors.outline,
        );
      }
      children.add(TextSpan(text: text.substring(from, to), style: segment));
    }
    return TextSpan(style: style, children: children);
  }

  static TextStyle _style(SpanKind kind, ColorScheme colors) => switch (kind) {
    SpanKind.primary || SpanKind.property || SpanKind.extraMarker => TextStyle(
      color: colors.primary,
      fontWeight: FontWeight.bold,
    ),
    SpanKind.modifier || SpanKind.option => TextStyle(color: colors.primary),
    SpanKind.state || SpanKind.unknown => TextStyle(
      color: colors.outline,
      fontStyle: FontStyle.italic,
    ),
    SpanKind.date ||
    SpanKind.month ||
    SpanKind.weekday ||
    SpanKind.path => TextStyle(color: colors.tertiary),
    SpanKind.relation || SpanKind.target => TextStyle(color: colors.secondary),
    SpanKind.extra => TextStyle(color: colors.onSurfaceVariant),
  };
}
