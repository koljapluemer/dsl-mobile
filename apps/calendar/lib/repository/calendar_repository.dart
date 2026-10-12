import 'package:dsl/dsl.dart';

import '../models/item.dart';
import '../models/item_parser.dart';

/// The data folder, cached between launches, plus the items that fall on
/// some day.
class CalendarRepository extends FolderRepository {
  CalendarRepository() : super(cached: true);

  List<Item> _items = [];

  /// Items that fall on some day. Plain notes in the same folder (no primary
  /// keyword the calendar knows) and invalid files aren't included.
  List<Item> get calendarItems => _items;

  @override
  void didChangeItems() {
    _items = [
      for (final file in items)
        if (file.readError == null)
          if (calendarItem(file.name, file.doc) case ParsedItem(
            :final item,
          ) when item.kind != null)
            item,
    ];
  }

  /// Every item occurring on [day], sorted by heading.
  List<Item> itemsOn(DateOnly day) =>
      _items.where((i) => i.occursOn(day)).toList()
        ..sort((a, b) => a.heading.compareTo(b.heading));
}
