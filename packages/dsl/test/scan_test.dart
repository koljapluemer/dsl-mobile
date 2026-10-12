import 'dart:io';

import 'package:dsl/dsl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

final _schema = Schema.fromYaml(
  File('assets/keywords.yaml').readAsStringSync(),
);

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('dsl-scan-'));
  tearDown(() => dir.deleteSync(recursive: true));

  void write(String name, String text) =>
      File(p.join(dir.path, name)).writeAsStringSync(text);

  List<ItemFile> scan([List<ItemFile> previous = const []]) =>
      scanFolder((schema: _schema, folder: dir.path, previous: previous));

  test('reads item files only, sorted by name', () {
    write('b.txt', 'B\nappointment 26-10-12\n');
    write('a.txt', 'A\n');
    write('.a.txt.tmp', 'temp');
    write('.hidden.txt', 'hidden');
    write('c.json', '{}');
    Directory(p.join(dir.path, 'images.txt')).createSync();

    final items = scan();
    expect(items.map((i) => i.name), ['a.txt', 'b.txt']);
    expect(items[1].doc.clause('appointment'), isNotNull);
    expect(items[1].heading, 'B');
  });

  test('rescans only changed files and drops deleted ones', () {
    write('a.txt', 'A\n');
    write('b.txt', 'B\n');
    final first = scan();

    write('b.txt', 'B changed\n');
    File(
      p.join(dir.path, 'b.txt'),
    ).setLastModifiedSync(DateTime.now().add(const Duration(seconds: 5)));
    write('c.txt', 'C\n');
    File(p.join(dir.path, 'a.txt')).deleteSync();
    final oldB = first[1];
    write('d.txt', 'D\n');

    final second = scan(first);
    expect(second.map((i) => i.name), ['b.txt', 'c.txt', 'd.txt']);
    expect(second[0].body, 'B changed');
    expect(identical(second[0], oldB), isFalse);

    final third = scan(second);
    expect(identical(third[1], second[1]), isTrue);
  });

  test('an unreadable file is an item with a read error', () {
    File(p.join(dir.path, 'bad.txt')).writeAsBytesSync([0xff, 0xfe, 0x00]);
    final [item] = scan();
    expect(item.readError, isNotNull);
    expect(item.isValid, isFalse);
  });

  test('media path resolves against the folder', () {
    write('m.txt', 'M\nmedia "images/a b.webp"\n');
    write('n.txt', 'N\nmedia notes/readme.md\n');
    final [m, n] = scan();
    expect(m.mediaPathIn('/data'), p.join('/data', 'images', 'a b.webp'));
    expect(n.media, 'notes/readme.md');
    expect(n.mediaPathIn('/data'), isNull);
  });

  group('ItemCache', () {
    test('round-trips one folder, without unreadable files', () async {
      write('a.txt', 'A\nappointment 26-10-12\n');
      File(p.join(dir.path, 'bad.txt')).writeAsBytesSync([0xff]);
      final items = scan();
      final cache = ItemCache(File(p.join(dir.path, 'cache', 'c.json')));
      await cache.save(dir.path, items);

      final loaded = await cache.load(_schema, dir.path);
      expect(loaded.map((i) => i.name), ['a.txt']);
      expect(loaded[0].modified, items[0].modified);
      expect(loaded[0].doc.clause('appointment'), isNotNull);

      expect(await cache.load(_schema, '/elsewhere'), isEmpty);
    });

    test('a missing or broken cache is empty', () async {
      final file = File(p.join(dir.path, 'c.json'));
      expect(await ItemCache(file).load(_schema, dir.path), isEmpty);
      file.writeAsStringSync('{nope');
      expect(await ItemCache(file).load(_schema, dir.path), isEmpty);
    });
  });
}
