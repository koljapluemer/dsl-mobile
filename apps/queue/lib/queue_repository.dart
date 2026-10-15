import 'package:dsl/dsl.dart';

import 'blacklist.dart';

/// The folder's items minus those the [blacklist] hides; hidden items are
/// left out of [items], so nothing in the app sees them.
class QueueRepository extends FolderRepository {
  QueueRepository({super.cached = true});

  Blacklist blacklist = const Blacklist();

  @override
  Future<void> init() async {
    blacklist = await Blacklist.load();
    await super.init();
  }

  Future<void> setBlacklist(Blacklist next) async {
    blacklist = next;
    refilter();
    await next.save();
  }

  @override
  bool isVisible(ItemFile item) => !blacklist.hides(item, schema);

  /// Every primary keyword used in the folder, hidden items included, sorted.
  List<String> get knownTypes =>
      {for (final i in allItems) ?i.primaryKeyword(schema)}.toList()..sort();

  /// Every tag used in the folder, hidden items included, sorted.
  List<String> get knownTags =>
      {for (final i in allItems) ...i.tags}.toList()..sort();
}
