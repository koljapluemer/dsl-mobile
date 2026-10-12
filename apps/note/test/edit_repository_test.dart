import 'dart:io';

import 'package:dsl_note/edit_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late EditRepository repo;

  File file(String name) => File(p.join(dir.path, name));

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('dsl-note-');
    SharedPreferences.setMockInitialValues({'data_folder': dir.path});
    repo = EditRepository();
    await repo.init();
    await repo.loadFromDisk();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'create names the file after the first line and adds a newline',
    () async {
      final item = await repo.create('Buy Milk & eggs!\nappointment 26-10-12');
      expect(item.name, matches(RegExp(r'^buy-milk-eggs-[0-9a-f]{6}\.txt$')));
      expect(
        file(item.name).readAsStringSync(),
        'Buy Milk & eggs!\nappointment 26-10-12\n',
      );
      expect(repo.itemNamed(item.name), isNotNull);
      expect(dir.listSync().whereType<File>().map((f) => p.basename(f.path)), [
        item.name,
      ]);
    },
  );

  test(
    'create falls back to "item" for a first line without letters',
    () async {
      final item = await repo.create('😀\n');
      expect(item.name, startsWith('item-'));
    },
  );

  test('save writes, and skips an unchanged text', () async {
    final item = await repo.create('A');
    final saved = await repo.save(item, 'A\nmore');
    expect(saved, isNotNull);
    expect(file(item.name).readAsStringSync(), 'A\nmore\n');

    final again = await repo.save(saved!, 'A\nmore\n');
    expect(again!.modified, saved.modified);
  });

  test('save refuses when the file changed or vanished on disk', () async {
    final item = await repo.create('A');
    file(item.name).writeAsStringSync('A changed elsewhere, and longer\n');
    expect(await repo.save(item, 'B'), isNull);
    expect(
      file(item.name).readAsStringSync(),
      'A changed elsewhere, and longer\n',
    );

    final fresh = await repo.readFresh(item.name);
    file(item.name).deleteSync();
    expect(await repo.save(fresh, 'B'), isNull);
    expect(repo.itemNamed(item.name), isNull);

    await repo.overwrite(item.name, 'B');
    expect(file(item.name).readAsStringSync(), 'B\n');
  });

  test('delete waits for two interactions and can be undone', () async {
    final item = await repo.create('A');
    final id = repo.beginPendingDelete(item.name);
    expect(repo.visibleItems, isEmpty);
    repo.cancelPending(id);
    expect(repo.visibleItems.map((i) => i.name), [item.name]);

    repo.beginPendingDelete(item.name);
    repo.registerInteraction();
    expect(file(item.name).existsSync(), isTrue);
    repo.registerInteraction();
    await pumpEventQueue();
    expect(file(item.name).existsSync(), isFalse);
    expect(repo.itemNamed(item.name), isNull);
  });

  test('delete removes the attachment unless another item uses it', () async {
    final source = File(p.join(dir.path, 'src.png'))..writeAsBytesSync([1]);
    final media = await repo.importMedia(source, 'a');
    expect(media, startsWith('images/a-'));
    final a = await repo.create('A\nmedia $media');
    final b = await repo.create('B\nmedia $media');

    repo.beginPendingDelete(a.name);
    repo.registerInteraction();
    repo.registerInteraction();
    await pumpEventQueue();
    expect(file(media).existsSync(), isTrue);

    repo.beginPendingDelete(b.name);
    repo.registerInteraction();
    repo.registerInteraction();
    await pumpEventQueue();
    expect(file(media).existsSync(), isFalse);
  });

  test('discardMedia keeps referenced attachments', () async {
    final source = File(p.join(dir.path, 'src.png'))..writeAsBytesSync([1]);
    final used = await repo.importMedia(source, 'a');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final unused = await repo.importMedia(source, 'a');
    await repo.create('A\nmedia $used');
    await repo.discardMedia(used);
    await repo.discardMedia(unused);
    expect(file(used).existsSync(), isTrue);
    expect(file(unused).existsSync(), isFalse);
  });
}
