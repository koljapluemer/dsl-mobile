import 'dart:math';

import 'package:dsl/dsl.dart';

/// The tag that puts an item on the list.
const zeroTag = 'zero';

/// The folder's items tagged [zeroTag]. Which of them are done, and their
/// order, live only in memory for this session; nothing is written anywhere.
class ZeroRepository extends FolderRepository {
  ZeroRepository({super.cached = true, Random? random})
    : _random = random ?? Random();

  final Random _random;

  /// Random sort key per file name, drawn once per session, so a rescan keeps
  /// the cards in place and a new item lands at a random position.
  final Map<String, double> _rank = {};

  final Set<String> _done = {};

  @override
  bool isVisible(ItemFile item) => item.tags.contains(zeroTag);

  @override
  void didChangeItems() {
    for (final item in items) {
      _rank.putIfAbsent(item.name, _random.nextDouble);
    }
  }

  bool isDone(String name) => _done.contains(name);

  /// Greys [name] out until the app restarts. Done can't be undone.
  void markDone(String name) {
    if (_done.add(name)) notifyListeners();
  }

  /// [items] in session order, done items last.
  List<ItemFile> get ordered {
    int byRank(ItemFile a, ItemFile b) =>
        _rank[a.name]!.compareTo(_rank[b.name]!);
    return [
      ...items.where((i) => !isDone(i.name)).toList()..sort(byRank),
      ...items.where((i) => isDone(i.name)).toList()..sort(byRank),
    ];
  }
}
