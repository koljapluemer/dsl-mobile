import 'dart:io';
import 'dart:math';

import 'package:dsl_zero/zero_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  void write(String name, String text) =>
      File(p.join(dir.path, name)).writeAsStringSync(text);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dsl-zero-');
    write('a.txt', 'A\ntags zero\n');
    write('b.txt', 'B\ntags other zero\n');
    write('c.txt', 'C\ntags other\n');
    write('d.txt', 'D #zero\n');
    write('e.txt', 'E\ntags zero-ish\n');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<ZeroRepository> open() async {
    SharedPreferences.setMockInitialValues({'data_folder': dir.path});
    final repo = ZeroRepository(cached: false, random: Random(1));
    await repo.init();
    await repo.loadFromDisk();
    return repo;
  }

  List<String> names(ZeroRepository repo) => [
    for (final i in repo.ordered) i.name,
  ];

  test('shows only items tagged zero', () async {
    final repo = await open();
    expect(names(repo).toSet(), {'a.txt', 'b.txt'});
  });

  test('markDone moves an item to the bottom, once', () async {
    final repo = await open();
    final first = names(repo).first;
    var notified = 0;
    repo.addListener(() => notified++);
    repo.markDone(first);
    expect(names(repo).last, first);
    expect(repo.isDone(first), isTrue);
    repo.markDone(first);
    expect(notified, 1);
  });

  test('a rescan keeps the order and adds new items', () async {
    final repo = await open();
    final before = names(repo);
    write('f.txt', 'F\ntags zero\n');
    await repo.loadFromDisk();
    final after = names(repo);
    expect(after.toSet(), {...before, 'f.txt'});
    expect(after.where(before.contains).toList(), before);
  });

  test('never writes to the folder', () async {
    final before = {
      for (final f in dir.listSync().cast<File>()) f.path: f.readAsStringSync(),
    };
    final repo = await open();
    for (final i in repo.ordered) {
      repo.markDone(i.name);
    }
    final after = {
      for (final f in dir.listSync().cast<File>()) f.path: f.readAsStringSync(),
    };
    expect(after, before);
  });
}
