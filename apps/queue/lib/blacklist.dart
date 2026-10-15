import 'package:dsl/dsl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsTypesKey = 'blacklist_types';
const _prefsTagsKey = 'blacklist_tags';

/// A tag as the spec allows it: `a-z`, `0-9` and `-`.
final tagPattern = RegExp(r'^[a-z0-9-]+$');

/// Primary keywords and tags whose items the queue ignores entirely.
class Blacklist {
  const Blacklist({this.types = const {}, this.tags = const {}});

  final Set<String> types;
  final Set<String> tags;

  /// Whether [item]'s type is blacklisted, or it has a blacklisted tag.
  bool hides(ItemFile item, Schema schema) =>
      types.contains(item.primaryKeyword(schema)) ||
      item.tags.any(tags.contains);

  Blacklist copyWith({Set<String>? types, Set<String>? tags}) =>
      Blacklist(types: types ?? this.types, tags: tags ?? this.tags);

  static Future<Blacklist> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Blacklist(
      types: {...?prefs.getStringList(_prefsTypesKey)},
      tags: {...?prefs.getStringList(_prefsTagsKey)},
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsTypesKey, types.toList()..sort());
    await prefs.setStringList(_prefsTagsKey, tags.toList()..sort());
  }
}
