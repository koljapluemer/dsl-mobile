import 'package:path/path.dart' as p;

import 'document.dart';
import 'media.dart';
import 'schema.dart';

/// One `*.txt` file of the data folder, parsed.
class ItemFile {
  const ItemFile({
    required this.name,
    required this.modified,
    required this.size,
    required this.text,
    required this.doc,
    this.readError,
  });

  /// The file name with `.txt`: the item's id. Relationships refer to it
  /// without the extension.
  final String name;

  /// The file's modification time (microseconds since epoch) and size when
  /// [text] was read; a scan re-reads the file only when either changes.
  final int modified;
  final int size;

  final String text;
  final Document doc;

  /// Set when the file couldn't be read; [text] is then empty.
  final String? readError;

  bool get isValid => readError == null && doc.isValid;

  /// Has errors or warnings, or couldn't be read.
  bool get needsAttention => !isValid || doc.warnings.isNotEmpty;

  /// The body lines joined, verbatim.
  String get body => doc.body.join('\n');

  /// The extra content, or null when there is none.
  String? get extra => doc.extra?.join('\n');

  /// The `media` path as written, relative to the data folder.
  String? get media => switch (doc.clause('media')) {
    Clause(args: [PathValue(:final text)]) => text,
    _ => null,
  };

  /// The attachment's absolute path in [folder], or null when the item has
  /// none or it isn't an image or video.
  String? mediaPathIn(String folder) {
    final path = media;
    if (path == null || !isMediaFilename(path)) return null;
    return p.joinAll([folder, ...path.split('/')]);
  }

  bool get hasVideo => isVideoFilename(media ?? '');

  /// The item's type: its first `primary` keyword, or null for a plain note.
  String? primaryKeyword(Schema schema) => doc.clauses
      .where((c) => schema.keywords[c.keyword]?.role == Role.primary)
      .firstOrNull
      ?.keyword;

  /// The tags of its `tags` line, in order; empty when it has none.
  List<String> get tags => [
    for (final value in doc.clause('tags')?.args ?? const <Value>[]) value.text,
  ];

  /// The first body line, trimmed; or the file name when there is none.
  String get heading {
    final first = doc.body.firstOrNull?.trim() ?? '';
    return first.isEmpty ? name : first;
  }
}
