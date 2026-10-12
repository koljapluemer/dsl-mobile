import 'dart:io';
import 'dart:math';

import 'package:dsl/dsl.dart';
import 'package:path/path.dart' as p;

/// The data folder, loaded in the background on every start and never cached
/// (this app writes, so a stale cache could hide what's on disk), plus the
/// writes: create, save, delete, and attachment files.
class EditRepository extends FolderRepository {
  EditRepository() : super(cached: false);

  final _random = Random();

  final List<_PendingDelete> _pending = [];
  int _nextPendingId = 0;

  String get _folder {
    final folder = folderPath;
    if (folder == null) throw StateError('no data folder set');
    return folder;
  }

  /// Items not waiting to be deleted.
  List<ItemFile> get visibleItems => [
    for (final i in items)
      if (!_pending.any((d) => d.name == i.name)) i,
  ];

  /// Writes [text] as a new item, named `<slug of its first line>-<6 hex>.txt`.
  /// The name never changes afterwards: other items refer to it.
  Future<ItemFile> create(String text) async {
    final content = _withNewline(text);
    final slug = _slug(parseDocument(schema, content).body.firstOrNull ?? '');
    File file;
    do {
      file = File(p.join(_folder, '$slug-${_hex(6)}.txt'));
    } while (await file.exists());
    await _write(file, content);
    return _reread(file);
  }

  /// The file's current text and modification time, read from disk — what
  /// the editor starts from, rather than a possibly stale scan.
  Future<ItemFile> readFresh(String name) =>
      _reread(File(p.join(_folder, name)));

  /// Writes [text] to item [base] unless the file changed or was deleted on
  /// disk since [base] was read; then returns null and writes nothing. Leaves
  /// a file whose text is already [text] untouched, so its modification time
  /// keeps meaning "last edited".
  Future<ItemFile?> save(ItemFile base, String text) async {
    final file = File(p.join(_folder, base.name));
    final content = _withNewline(text);
    final ItemFile current;
    try {
      current = await _reread(file);
    } on FileSystemException {
      removeItem(base.name);
      return null;
    }
    if (current.modified != base.modified || current.size != base.size) {
      return null;
    }
    if (current.text == content) return current;
    await _write(file, content);
    return _reread(file);
  }

  /// Writes [text] to item [name] regardless of what's on disk.
  Future<ItemFile> overwrite(String name, String text) async {
    final file = File(p.join(_folder, name));
    await _write(file, _withNewline(text));
    return _reread(file);
  }

  /// Copies [source] into `images/` as `<stem>-<epochMillis><ext>` and returns
  /// its path relative to the data folder, for a `media` line.
  Future<String> importMedia(File source, String stem) async {
    final dir = Directory(p.join(_folder, 'images'));
    await dir.create(recursive: true);
    final ext = p.extension(source.path).toLowerCase();
    final name = '$stem-${DateTime.now().millisecondsSinceEpoch}$ext';
    await source.copy(p.join(dir.path, name));
    return 'images/$name';
  }

  /// Deletes an attachment this app imported but that ended up unused (the
  /// editor was cleared, or another file was attached instead), unless some
  /// item refers to it after all.
  Future<void> discardMedia(String relativePath) async {
    if (_isReferenced(relativePath, except: null)) return;
    await _deleteMediaFile(relativePath);
  }

  /// A slug for attachment file names, from an item's text.
  String mediaStem(String text) =>
      _slug(parseDocument(schema, text).body.firstOrNull ?? '');

  // Deletes are deferred: the item is hidden right away, and its file is only
  // deleted after two more interactions anywhere in the app without an undo.

  /// Hides [name] and returns an id for [cancelPending] / [isPendingActive].
  int beginPendingDelete(String name) {
    for (final d in _pending) {
      if (d.name == name) return d.id;
    }
    final id = _nextPendingId++;
    _pending.add(_PendingDelete(id: id, name: name));
    notifyListeners();
    return id;
  }

  bool isPendingActive(int id) => _pending.any((d) => d.id == id);

  void cancelPending(int id) {
    final before = _pending.length;
    _pending.removeWhere((d) => d.id == id);
    if (_pending.length != before) notifyListeners();
  }

  /// Counts a pointer-down anywhere in the app.
  void registerInteraction() {
    if (_pending.isEmpty) return;
    final ready = <_PendingDelete>[];
    for (final d in _pending) {
      if (++d.interactions >= 2) ready.add(d);
    }
    if (ready.isEmpty) return;
    _pending.removeWhere(ready.contains);
    for (final d in ready) {
      _finalizeDelete(d.name);
    }
  }

  /// Deletes the item's file, and its attachment when that lives directly in
  /// `images/` and no other item refers to it. The reference check needs a
  /// complete scan; without one the attachment is left behind.
  Future<void> _finalizeDelete(String name) async {
    final item = itemNamed(name);
    final file = File(p.join(_folder, name));
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      loadError = 'Could not delete $name: $e';
      notifyListeners();
      return;
    }
    final media = item?.media;
    final canCheck = hasLoaded && !isLoading;
    if (media != null && canCheck && !_isReferenced(media, except: name)) {
      await _deleteMediaFile(media);
    }
    removeItem(name);
  }

  bool _isReferenced(String media, {required String? except}) =>
      items.any((i) => i.name != except && i.media == media);

  Future<void> _deleteMediaFile(String relativePath) async {
    final parts = relativePath.split('/');
    if (parts.length != 2 || parts[0] != 'images') return;
    try {
      await File(p.join(_folder, 'images', parts[1])).delete();
    } catch (_) {
      // Best effort: an orphaned attachment is harmless.
    }
  }

  /// Reads [file] into an [ItemFile] and puts it into [items].
  Future<ItemFile> _reread(File file) async {
    final stat = await file.stat();
    if (stat.type == FileSystemEntityType.notFound) {
      throw FileSystemException('File not found', file.path);
    }
    final item = readItem(
      schema,
      file,
      modified: stat.modified.microsecondsSinceEpoch,
      size: stat.size,
    );
    putItem(item);
    return item;
  }

  /// Writes through a hidden temp file + rename, so a crash can't leave half
  /// an item behind and a scan never sees the temp file as an item.
  static Future<void> _write(File file, String text) async {
    final tmp = File(p.join(file.parent.path, '.${p.basename(file.path)}.tmp'));
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(file.path);
  }

  static String _withNewline(String text) =>
      text.endsWith('\n') ? text : '$text\n';

  /// Lowercase `a-z0-9` words joined by `-`, at most 40 characters; `item`
  /// when nothing is left.
  static String _slug(String line) {
    var slug = line
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.length > 40) {
      slug = slug.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
    }
    return slug.isEmpty ? 'item' : slug;
  }

  String _hex(int length) => [
    for (var i = 0; i < length; i++) _random.nextInt(16).toRadixString(16),
  ].join();
}

class _PendingDelete {
  _PendingDelete({required this.id, required this.name});

  final int id;
  final String name;
  int interactions = 0;
}
