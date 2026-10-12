import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'folder_scan.dart';
import 'item.dart';
import 'item_cache.dart';
import 'schema.dart';

const _prefsFolderKey = 'data_folder';
const _schemaAsset = 'packages/dsl/assets/keywords.yaml';

/// The data folder's items, held in memory. [init] restores the folder (and,
/// with [cached], the last scan) before the first frame; [loadFromDisk] then
/// rescans in the background, re-reading only files that changed.
class FolderRepository extends ChangeNotifier {
  FolderRepository({required this.cached});

  /// Whether the last scan is kept in app storage and shown on the next start.
  final bool cached;

  String? folderPath;
  bool isLoading = false;

  /// Whether a scan has finished since launch (or since the folder changed).
  bool hasLoaded = false;
  String? loadError;

  late final Schema schema;
  ItemCache? _cache;

  List<ItemFile> _items = [];

  /// Changes made through [putItem]/[removeItem] while a scan runs: the scan
  /// may have listed the folder before them, so they're applied on top of
  /// its result. A null value is a removal.
  final Map<String, ItemFile?> _changedDuringLoad = {};

  /// Every item file, sorted by name.
  List<ItemFile> get items => _items;

  int get count => _items.length;

  Future<void> init() async {
    schema = Schema.fromYaml(await rootBundle.loadString(_schemaAsset));
    final prefs = await SharedPreferences.getInstance();
    folderPath = prefs.getString(_prefsFolderKey);
    if (cached) {
      final dir = await getApplicationSupportDirectory();
      _cache = ItemCache(File(p.join(dir.path, 'items-cache.json')));
      final folder = folderPath;
      if (folder != null) _setItems(await _cache!.load(schema, folder));
    }
  }

  Future<void> setFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsFolderKey, path);
    folderPath = path;
    hasLoaded = false;
    loadError = null;
    _setItems(await _cache?.load(schema, path) ?? []);
    notifyListeners();
    isLoading = false; // a scan of the old folder is discarded when it lands
    await loadFromDisk();
  }

  /// Rescans the folder. Ignored while a scan runs, so a refresh button can
  /// be tapped repeatedly. A failed scan keeps the items shown.
  Future<void> loadFromDisk() async {
    final folder = folderPath;
    if (folder == null || isLoading) return;
    isLoading = true;
    loadError = null;
    _changedDuringLoad.clear();
    notifyListeners();

    try {
      final scanned = await compute(scanFolder, (
        schema: schema,
        folder: folder,
        previous: _items,
      ));
      if (folderPath != folder) return;
      final byName = {for (final i in scanned) i.name: i};
      for (final MapEntry(:key, :value) in _changedDuringLoad.entries) {
        if (value == null) {
          byName.remove(key);
        } else {
          byName[key] = value;
        }
      }
      _setItems(byName.values.toList());
      hasLoaded = true;
      await _cache?.save(folder, _items);
    } catch (e) {
      if (folderPath == folder) loadError = '$e';
    } finally {
      if (folderPath == folder) {
        isLoading = false;
        _changedDuringLoad.clear();
        notifyListeners();
      }
    }
  }

  /// Adds or replaces an item after this app wrote its file.
  void putItem(ItemFile item) {
    if (isLoading) _changedDuringLoad[item.name] = item;
    final next = _items.where((i) => i.name != item.name).toList()..add(item);
    _setItems(next);
    notifyListeners();
  }

  /// Drops an item after this app deleted its file.
  void removeItem(String name) {
    if (isLoading) _changedDuringLoad[name] = null;
    _setItems(_items.where((i) => i.name != name).toList());
    notifyListeners();
  }

  ItemFile? itemNamed(String name) {
    for (final item in _items) {
      if (item.name == name) return item;
    }
    return null;
  }

  void _setItems(List<ItemFile> items) {
    _items = items..sort((a, b) => a.name.compareTo(b.name));
    didChangeItems();
  }

  /// Called whenever [items] changes, before listeners are notified; for
  /// subclasses that derive views from the items.
  @protected
  void didChangeItems() {}
}
