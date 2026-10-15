import 'dart:io';

import 'package:dsl/dsl.dart';
import 'package:dsl_queue/blacklist.dart';
import 'package:dsl_queue/queue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final schema = Schema.fromYaml(
    File('../../packages/dsl/assets/keywords.yaml').readAsStringSync(),
  );

  ItemFile item(String text) => ItemFile(
    name: 'x.txt',
    modified: 0,
    size: 0,
    text: text,
    doc: parseDocument(schema, text),
  );

  group('hides', () {
    const blacklist = Blacklist(types: {'appointment'}, tags: {'break'});

    test('by primary type', () {
      expect(
        blacklist.hides(item('Dentist\nappointment 26-10-12'), schema),
        isTrue,
      );
      expect(blacklist.hides(item('Lecture\nrecurring mo'), schema), isFalse);
    });

    test('by any tag', () {
      expect(blacklist.hides(item('Note\ntags x break'), schema), isTrue);
      expect(blacklist.hides(item('Note\ntags x'), schema), isFalse);
      expect(blacklist.hides(item('Note'), schema), isFalse);
    });
  });

  group('QueueRepository', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dsl-queue-');
      File(p.join(dir.path, 'a.txt')).writeAsStringSync('A\ntags break\n');
      File(
        p.join(dir.path, 'b.txt'),
      ).writeAsStringSync('B\nappointment 26-10-12\n');
      File(p.join(dir.path, 'c.txt')).writeAsStringSync('C\ntags keep\n');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Future<QueueRepository> open(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues({
        'data_folder': dir.path,
        ...prefs,
      });
      final repo = QueueRepository(cached: false);
      await repo.init();
      await repo.loadFromDisk();
      return repo;
    }

    test(
      'leaves out blacklisted items, and keeps them for suggestions',
      () async {
        final repo = await open({
          'blacklist_types': ['appointment'],
          'blacklist_tags': ['break'],
        });
        expect([for (final i in repo.items) i.name], ['c.txt']);
        expect(repo.count, 1);
        expect(repo.itemNamed('a.txt'), isNull);
        expect(repo.allItems, hasLength(3));
        expect(repo.knownTypes, ['appointment']);
        expect(repo.knownTags, ['break', 'keep']);
      },
    );

    test('setBlacklist refilters and persists', () async {
      final repo = await open({});
      expect(repo.items, hasLength(3));
      await repo.setBlacklist(const Blacklist(tags: {'keep'}));
      expect([for (final i in repo.items) i.name], ['a.txt', 'b.txt']);
      expect((await Blacklist.load()).tags, {'keep'});
    });
  });
}
