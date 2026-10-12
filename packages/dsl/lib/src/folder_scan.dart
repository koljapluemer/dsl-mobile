import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'document.dart';
import 'item.dart';
import 'schema.dart';

/// What a scan needs; a record so it can go to an isolate via `compute`.
typedef ScanRequest = ({
  Schema schema,
  String folder,

  /// The previous scan's (or the cache's) files: unchanged ones aren't read
  /// again.
  List<ItemFile> previous,
});

/// Whether [name] is an item file: `*.txt`, not hidden (temp files of
/// in-progress writes are hidden).
bool isItemFileName(String name) =>
    name.toLowerCase().endsWith('.txt') && !name.startsWith('.');

/// Every item file directly inside the folder, sorted by name. A file whose
/// modification time and size match [ScanRequest.previous] isn't read again,
/// so a rescan of a large folder mostly costs one stat per file. A file that
/// can't be read becomes an [ItemFile] with a `readError`, never a failure of
/// the whole scan. Throws when the folder itself can't be listed.
List<ItemFile> scanFolder(ScanRequest request) {
  final (:schema, :folder, :previous) = request;
  final known = {for (final item in previous) item.name: item};
  final results = <ItemFile>[];
  for (final entity in Directory(folder).listSync()) {
    final name = p.basename(entity.path);
    if (entity is! File || !isItemFileName(name)) continue;
    final FileStat stat;
    try {
      stat = entity.statSync();
    } catch (_) {
      continue; // deleted between listing and stat
    }
    final modified = stat.modified.microsecondsSinceEpoch;
    final old = known[name];
    if (old != null &&
        old.readError == null &&
        old.modified == modified &&
        old.size == stat.size) {
      results.add(old);
      continue;
    }
    results.add(readItem(schema, entity, modified: modified, size: stat.size));
  }
  results.sort((a, b) => a.name.compareTo(b.name));
  return results;
}

/// Reads and parses one item file. Never throws.
ItemFile readItem(
  Schema schema,
  File file, {
  required int modified,
  required int size,
}) {
  final name = p.basename(file.path);
  try {
    final text = utf8.decode(file.readAsBytesSync());
    return itemFromText(schema, name, text, modified: modified, size: size);
  } catch (e) {
    return ItemFile(
      name: name,
      modified: modified,
      size: size,
      text: '',
      doc: const Document(),
      readError: '$e',
    );
  }
}

ItemFile itemFromText(
  Schema schema,
  String name,
  String text, {
  required int modified,
  required int size,
}) => ItemFile(
  name: name,
  modified: modified,
  size: size,
  text: text,
  doc: parseDocument(schema, text),
);
