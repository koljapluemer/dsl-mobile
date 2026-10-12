import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'folder_scan.dart';
import 'item.dart';
import 'schema.dart';

/// The last scan of one data folder, as a JSON file in the app's own storage,
/// so an app can show its items right away and rescan in the background.
///
/// It holds each file's raw text, not a parse: on load the text is parsed
/// with the current schema, so a newer `keywords.yaml` applies to cached
/// items too. Files that couldn't be read aren't cached.
class ItemCache {
  const ItemCache(this.file);

  final File file;

  /// The cached items for [folder]: empty when there's no cache, it's for
  /// another folder, or it can't be decoded. Runs in an isolate.
  Future<List<ItemFile>> load(Schema schema, String folder) =>
      compute(_load, (schema: schema, path: file.path, folder: folder));

  /// Replaces the cache with [items] of [folder]. Encodes in an isolate and
  /// writes through a temp file, so a crash can't leave half a cache.
  Future<void> save(String folder, List<ItemFile> items) => compute(_save, (
    path: file.path,
    folder: folder,
    entries: [
      for (final i in items)
        if (i.readError == null) (i.name, i.modified, i.size, i.text),
    ],
  ));
}

List<ItemFile> _load(({Schema schema, String path, String folder}) args) {
  try {
    final file = File(args.path);
    if (!file.existsSync()) return [];
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    if (json['folder'] != args.folder) return [];
    return [
      for (final e in (json['items'] as List).cast<List<dynamic>>())
        itemFromText(
          args.schema,
          e[0] as String,
          e[3] as String,
          modified: e[1] as int,
          size: e[2] as int,
        ),
    ];
  } catch (_) {
    return [];
  }
}

Future<void> _save(
  ({String path, String folder, List<(String, int, int, String)> entries}) args,
) async {
  final json = jsonEncode({
    'folder': args.folder,
    'items': [
      for (final (name, modified, size, text) in args.entries)
        [name, modified, size, text],
    ],
  });
  final file = File(args.path);
  await file.parent.create(recursive: true);
  final tmp = File('${args.path}.tmp');
  await tmp.writeAsString(json, flush: true);
  await tmp.rename(args.path);
}
