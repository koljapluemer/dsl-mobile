import 'dart:io';

import 'package:dsl/dsl.dart';
import 'package:flutter_test/flutter_test.dart';

final _schema = Schema.fromYaml(
  File('assets/keywords.yaml').readAsStringSync(),
);

String _set(String text, String keyword, String clause) =>
    setClause(_schema, text, keyword, clause).text;

void main() {
  test('formatDate', () {
    expect(formatDate(const DateOnly(2026, 3, 7)), '26-03-07');
  });

  test('formatPath quotes spaces and escapes quotes', () {
    expect(formatPath('images/a.png'), 'images/a.png');
    expect(formatPath('images/a b.png'), '"images/a b.png"');
    expect(formatPath('images/a"b.png'), r'"images/a\"b.png"');
  });

  group('setClause', () {
    test('appends after the body when there is no section', () {
      final edit = setClause(
        _schema,
        'Note\nmore\n\n',
        'appointment',
        'appointment 26-10-12',
      );
      expect(edit.text, 'Note\nmore\nappointment 26-10-12\n\n');
      expect(
        edit.text.substring(0, edit.cursor),
        'Note\nmore\nappointment 26-10-12',
      );
    });

    test('replaces the keyword\'s own line', () {
      expect(
        _set(
          'Note\nappointment 26-01-01\nmedia a.png\n',
          'appointment',
          'appointment 26-10-12',
        ),
        'Note\nappointment 26-10-12\nmedia a.png\n',
      );
    });

    test('replaces a malformed line of the keyword too', () {
      expect(
        _set('Note\nappointment\n', 'appointment', 'appointment 26-10-12'),
        'Note\nappointment 26-10-12\n',
      );
    });

    test('goes before the extra marker', () {
      expect(
        _set(
          'Note\nmedia a.png\n\nextra\nmedia b.png\n',
          'appointment',
          'appointment 26-10-12',
        ),
        'Note\nmedia a.png\nappointment 26-10-12\n\nextra\nmedia b.png\n',
      );
    });

    test('never touches a body line that looks like the keyword', () {
      expect(
        _set('Note\n media x.png\n', 'media', 'media a.png'),
        'Note\n media x.png\nmedia a.png\n',
      );
    });

    test('adds a line when another clause shares the keyword\'s line', () {
      expect(
        _set('Note\nmedia a.png recurring mo\n', 'media', 'media b.png'),
        'Note\nmedia a.png recurring mo\nmedia b.png\n',
      );
    });

    test('with no body, leaves the first line for it', () {
      final edit = setClause(
        _schema,
        '  ',
        'appointment',
        'appointment 26-10-12',
      );
      expect(edit, (text: '\nappointment 26-10-12\n', cursor: 0));
    });
  });

  test('removeClause', () {
    expect(
      removeClause(
        _schema,
        'Note\nappointment 26-10-12\nmedia a.png\n',
        'appointment',
      )?.text,
      'Note\nmedia a.png\n',
    );
    expect(removeClause(_schema, 'Note\n', 'appointment'), isNull);
  });

  test('ensureExtra', () {
    expect(ensureExtra(_schema, 'Note\n\n').text, 'Note\nextra\n');
    expect(ensureExtra(_schema, 'Note\nextra\nx\n').text, 'Note\nextra\nx\n');
  });
}
