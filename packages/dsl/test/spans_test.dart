import 'dart:io';

import 'package:dsl/dsl.dart';
import 'package:flutter_test/flutter_test.dart';

final _schema = Schema.fromYaml(
  File('assets/keywords.yaml').readAsStringSync(),
);
final _examples = Directory('../../../dsl/spec/examples');

/// Each span as `kind:text`.
List<String> _spans(String text) => [
  for (final s in parseDocument(_schema, text).spans)
    '${s.kind.name}:${text.substring(s.from, s.to)}',
];

/// Each diagnostic as `code:text`.
List<String> _ranges(String text) => [
  for (final d in parseDocument(_schema, text).diagnostics)
    '${d.code.code}:${text.substring(d.from!, d.to!)}',
];

void main() {
  test('spans of every part', () {
    expect(
      _spans(
        'Everything\nsecond line\nrecurring tu until 27-03\n'
        'media "images/a b.webp"\n-> part of @collection-ffffff\n'
        'extra\nDetails.\n',
      ),
      [
        'primary:recurring',
        'weekday:tu',
        'option:until',
        'month:27-03',
        'property:media',
        'path:"images/a b.webp"',
        'relation:->',
        'target:@collection-ffffff',
        'blockMarker:extra',
        'block:Details.\n',
      ],
    );
  });

  test('CRLF line ends keep offsets', () {
    expect(_spans('x\r\nappointment 26-10-12\r\n'), [
      'primary:appointment',
      'date:26-10-12',
    ]);
  });

  test('diagnostic ranges', () {
    expect(_ranges('x\nappointment\nrecurring xx until'), [
      'missing_arg:appointment',
      'invalid_value:xx until',
    ]);
    expect(_ranges('x\nappointment 26-10-12\nrecurring mo'), [
      'conflicting_keywords:recurring',
    ]);
    expect(_ranges('x\nmedia a.png Foo\nzap 1 2\n-> nope'), [
      'unexpected_token:Foo',
      'unknown_keyword:zap 1 2',
      'invalid_relation:-> nope',
    ]);
    expect(_ranges('x\nextra\n  \n'), ['empty_extra:extra']);
    expect(_ranges('x\nmedia a.png\n(media b.png)'), [
      'invalid_state:(media b.png)',
    ]);
  });

  test(
    'every conformance diagnostic with a line has a range on it',
    () {
      final cases = _examples.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.txt'),
      );
      for (final file in cases) {
        final text = file.readAsStringSync();
        final lines = text.split('\n');
        for (final d in parseDocument(_schema, text).diagnostics) {
          if (d.line == null) continue;
          final lineStart = lines
              .take(d.line! - 1)
              .fold(0, (n, l) => n + l.length + 1);
          final lineEnd = lineStart + lines[d.line! - 1].length;
          expect(
            d.from! >= lineStart && d.from! < d.to! && d.to! <= lineEnd,
            isTrue,
            reason: '${file.path}: $d',
          );
        }
      }
    },
    skip: _examples.existsSync() ? false : 'no ../dsl',
  );
}
