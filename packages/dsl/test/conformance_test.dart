import 'dart:convert';
import 'dart:io';

import 'package:dsl/dsl.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sibling dsl repo's conformance cases (see its language.md,
/// "Conformance").
final _examples = Directory('../../../dsl/spec/examples');
final _upstreamSchema = File('../../../dsl/spec/keywords.yaml');
final _schema = Schema.fromYaml(
  File('assets/keywords.yaml').readAsStringSync(),
);

Map<String, Object?> _clause(Clause c) => {
  'keyword': c.keyword,
  'line': c.line,
  'args': [for (final a in c.args) a.text],
  'options': {for (final e in c.options.entries) e.key: e.value.text},
};

List<Map<String, Object?>> _diagnostics(Iterable<Diagnostic> ds) =>
    [
      for (final d in ds) {'code': d.code.code, 'line': d.line},
    ]..sort((a, b) {
      final byLine = ((a['line'] as int?) ?? 0) - ((b['line'] as int?) ?? 0);
      return byLine != 0
          ? byLine
          : (a['code'] as String).compareTo(b['code'] as String);
    });

Map<String, Object?> _result(Document doc) => {
  'body': doc.body.isEmpty ? null : doc.body.join('\n'),
  'clauses': [for (final c in doc.clauses) _clause(c)],
  'relations': [
    for (final r in doc.relations)
      {'label': r.label, 'target': r.target, 'line': r.line},
  ],
  'state': [for (final c in doc.state) _clause(c)],
  'unknown': doc.unknownLines,
  'extra': doc.extra?.join('\n'),
  'errors': _diagnostics(doc.errors),
  'warnings': _diagnostics(doc.warnings),
};

void main() {
  final cases = _examples.existsSync()
      ? (_examples.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.txt'),
        )).toList()
      : <File>[];

  group('dsl conformance examples', () {
    for (final file in cases) {
      final name = file.uri.pathSegments.last;
      test(name, () {
        final expected =
            jsonDecode(
                  File(
                    file.path.replaceFirst(RegExp(r'\.txt$'), '.json'),
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        final actual = _result(parseDocument(_schema, file.readAsStringSync()));
        expect({for (final key in expected.keys) key: actual[key]}, expected);
      });
    }
  }, skip: cases.isEmpty ? 'no ../dsl' : false);

  test(
    'vendored schema matches the sibling dsl repo',
    () => expect(
      File('assets/keywords.yaml').readAsStringSync(),
      _upstreamSchema.readAsStringSync(),
      reason: 'run `just sync-spec`',
    ),
    skip: _upstreamSchema.existsSync() ? false : 'no ../dsl',
  );
}
