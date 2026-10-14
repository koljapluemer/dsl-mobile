import 'package:yaml/yaml.dart';

/// The value types from the dsl spec's `language.md`.
enum ValueType { date, month, weekday, path, text }

/// How a block keyword's content is read (`block` in `keywords.yaml`).
enum BlockKind { text, yaml }

/// A keyword's `role` in `keywords.yaml`.
enum Role {
  /// The item's type; opens the keyword section.
  primary,

  /// Not a type, but opens the keyword section too.
  property,

  /// Only inside the keyword section.
  modifier,

  /// Machine-maintained; only inside a `( … )` state line.
  state;

  /// Whether a keyword of this role may start the keyword section at column 0.
  bool get opensSection => this == primary || this == property;
}

/// One positional argument, or the value of an option.
class ValueSpec {
  const ValueSpec(this.name, this.types);

  final String name;

  /// Any of these is accepted; the value's form decides which it is.
  final List<ValueType> types;
}

class KeywordSpec {
  const KeywordSpec({
    required this.name,
    required this.role,
    this.args = const [],
    this.options = const {},
    this.excludes = const {},
    this.block,
  });

  final String name;

  final Role role;

  final List<ValueSpec> args;
  final Map<String, ValueSpec> options;
  final Set<String> excludes;

  /// Set for keywords holding a multi-line block (`data`, `extra`).
  final BlockKind? block;
}

/// The dsl repo's `spec/keywords.yaml`, which the parser reads instead of
/// hardcoding keywords. Throws [FormatException] when it's malformed — that's a
/// broken build, not a broken data file.
class Schema {
  const Schema({required this.version, required this.keywords});

  factory Schema.fromYaml(String source) {
    final root = loadYaml(source);
    if (root is! YamlMap) throw const FormatException('Schema is not a map');
    final version = root['version'];
    final keywords = root['keywords'];
    if (version is! int) throw const FormatException('Schema has no version');
    if (keywords is! YamlMap) {
      throw const FormatException('Schema has no keywords');
    }
    return Schema(
      version: version,
      keywords: {
        for (final MapEntry(:key, :value) in keywords.entries)
          key as String: _keyword(key, value as YamlMap),
      },
    );
  }

  final int version;
  final Map<String, KeywordSpec> keywords;

  static KeywordSpec _keyword(String name, YamlMap map) {
    final role = Role.values.where((r) => r.name == map['role']).firstOrNull;
    if (role == null) {
      throw FormatException(
        'Keyword "$name" has an invalid role: ${map['role']}',
      );
    }
    final args = (map['args'] as YamlList?) ?? YamlList();
    final options = (map['options'] as YamlMap?) ?? YamlMap();
    final excludes = (map['excludes'] as YamlList?) ?? YamlList();
    final blockName = map['block'];
    final block = blockName == null
        ? null
        : BlockKind.values.where((b) => b.name == blockName).firstOrNull;
    if (blockName != null && block == null) {
      throw FormatException('Keyword "$name" has an invalid block: $blockName');
    }
    return KeywordSpec(
      name: name,
      role: role,
      args: [
        for (final arg in args.cast<YamlMap>())
          ValueSpec(arg['name'] as String, _types(name, arg['type'])),
      ],
      options: {
        for (final MapEntry(:key, :value) in options.entries)
          key as String: ValueSpec(
            key,
            _types(name, (value as YamlMap)['type']),
          ),
      },
      excludes: {...excludes.cast<String>()},
      block: block,
    );
  }

  /// `type: date` or `type: [date, month]`.
  static List<ValueType> _types(String keyword, Object? raw) {
    final names = raw is YamlList ? raw.cast<String>().toList() : [raw];
    return [
      for (final n in names)
        ValueType.values.firstWhere(
          (t) => t.name == n,
          orElse: () =>
              throw FormatException('Keyword "$keyword" has unknown type: $n'),
        ),
    ];
  }
}
