import 'package:yaml/yaml.dart';

import 'date_only.dart';
import 'schema.dart';

/// A parsed argument or option value. [text] is its token text.
sealed class Value {
  const Value(this.text);

  final String text;
}

/// `yy-mm-dd`.
class DateValue extends Value {
  const DateValue(super.text, this.date);

  final DateOnly date;
}

/// `yy-mm` — a whole month.
class MonthValue extends Value {
  const MonthValue(super.text, this.year, this.month);

  final int year;
  final int month;

  DateOnly get lastDay => DateOnly.fromDateTime(DateTime(year, month + 1, 0));
}

/// `mo`..`su`, as [weekday] 1 = Mon .. 7 = Sun.
class WeekdayValue extends Value {
  const WeekdayValue(super.text, this.weekday);

  final int weekday;
}

/// A file path relative to the item's folder.
class PathValue extends Value {
  const PathValue(super.text);
}

/// The rest of the line, for a `text` argument.
class TextValue extends Value {
  const TextValue(super.text);
}

/// One `keyword arg* (option value)*` clause from the keyword section, or the
/// clause of a `( … )` state line.
class Clause {
  const Clause({
    required this.keyword,
    required this.line,
    required this.args,
    required this.options,
  });

  final String keyword;
  final int line;
  final List<Value> args;
  final Map<String, Value> options;
}

/// `-> label @target`. An empty [label] means the relationship is unlabeled.
class Relation {
  const Relation({
    required this.label,
    required this.target,
    required this.line,
  });

  final String label;

  /// The other item's file name without extension.
  final String target;
  final int line;
}

/// The error and warning codes from the dsl spec's `language.md`.
enum DiagnosticCode {
  empty('empty'),
  missingArg('missing_arg'),
  invalidValue('invalid_value'),
  unexpectedToken('unexpected_token'),
  duplicateKeyword('duplicate_keyword'),
  conflictingKeywords('conflicting_keywords'),
  invalidRelation('invalid_relation'),
  invalidState('invalid_state'),
  emptyExtra('empty_extra'),
  emptyData('empty_data'),
  invalidYaml('invalid_yaml'),
  unknownKeyword('unknown_keyword', isError: false);

  const DiagnosticCode(this.code, {this.isError = true});

  /// The spec's name, e.g. `missing_arg`.
  final String code;
  final bool isError;
}

class Diagnostic {
  const Diagnostic(this.code, {this.line, this.detail, this.from, this.to});

  final DiagnosticCode code;

  /// 1-based line number in the file, when the problem has one.
  final int? line;

  /// The offending keyword or token.
  final String? detail;

  /// The offending stretch of the text as offsets (end exclusive), for
  /// editors; set whenever [line] is.
  final int? from;
  final int? to;

  @override
  String toString() => [
    code.code,
    if (line != null) 'line $line',
    if (detail != null) '"$detail"',
  ].join(' · ');
}

/// What a stretch of item text is, for highlighting. The keyword kinds are
/// named after [Role]s, the value kinds after [ValueType]s.
enum SpanKind {
  primary,
  property,
  modifier,
  state,
  option,
  date,
  month,
  weekday,
  path,
  text,

  /// The `->` of a relationship line.
  relation,

  /// A relationship's `@target`.
  target,

  /// A block keyword (`data`, `extra`).
  blockMarker,

  /// A block's content.
  block,

  /// An unknown keyword and the rest of its line, or a whole unknown state
  /// line.
  unknown,
}

/// A highlighted stretch of the text, as offsets (end exclusive).
class Span {
  const Span(this.from, this.to, this.kind);

  final int from;
  final int to;
  final SpanKind kind;
}

/// A block keyword and its content: [line] is the keyword's 0-based line,
/// [end] the 0-based line after the content.
class BlockRange {
  const BlockRange(this.keyword, this.line, this.end);

  final String keyword;
  final int line;
  final int end;
}

/// A file parsed per the dsl spec, before any frontend gives its keywords
/// meaning. When [isValid] is false, [clauses] may be incomplete.
class Document {
  const Document({
    this.body = const [],
    this.clauses = const [],
    this.relations = const [],
    this.state = const [],
    this.unknownLines = const [],
    this.extra,
    this.data,
    this.dataValue,
    this.blocks = const [],
    this.diagnostics = const [],
    this.spans = const [],
    this.sectionStart = 0,
  });

  /// Verbatim body lines; blank lines inside kept. Empty only for an empty
  /// file.
  final List<String> body;

  final List<Clause> clauses;
  final List<Relation> relations;
  final List<Clause> state;

  /// Unknown keywords, each with the rest of its line, and whole unknown state
  /// lines, kept raw.
  final List<String> unknownLines;

  /// Verbatim `extra` lines, or null when the file has no `extra` block.
  final List<String>? extra;

  /// Verbatim `data` lines, or null when the file has no `data` block.
  final List<String>? data;

  /// The `data` block as plain maps and lists; null when absent or invalid.
  final Map<String, Object?>? dataValue;

  /// Every block, in text order.
  final List<BlockRange> blocks;

  final List<Diagnostic> diagnostics;

  /// Keywords, options, values, relationships and blocks, in text order. Body lines have none.
  final List<Span> spans;

  /// 0-based index of the line the keyword section starts at (the boundary),
  /// or the line count when there is none.
  final int sectionStart;

  /// 0-based index of the `extra` keyword's line, or null.
  int? get extraMarker =>
      blocks.where((b) => b.keyword == 'extra').firstOrNull?.line;

  /// 0-based index of the first block keyword's line, or null.
  int? get firstBlock => blocks.firstOrNull?.line;

  Iterable<Diagnostic> get errors => diagnostics.where((d) => d.code.isError);
  Iterable<Diagnostic> get warnings =>
      diagnostics.where((d) => !d.code.isError);
  bool get isValid => errors.isEmpty;

  Clause? clause(String keyword) =>
      clauses.where((c) => c.keyword == keyword).firstOrNull;
}

final _keywordToken = RegExp(r'^[a-z]+$');
final _keywordOpener = RegExp(r'^([a-z]+)(?=\s|$)');
final _stateOpener = RegExp(r'^\(([a-z]+)(?=[\s)]|$)');
final _relationOpener = RegExp(r'^->\s');

/// The block keyword a line consists of, or null.
String? _blockKeyword(Schema schema, String line) {
  final name = line.trimRight();
  return schema.keywords[name]?.block == null ? null : name;
}

/// Whether a line at column 0 is a keyword, relationship or state line whose
/// keyword role passes [roleCounts]. Block keywords count only alone on their
/// line.
bool _startsLine(Schema schema, String line, bool Function(Role) roleCounts) {
  if (_relationOpener.hasMatch(line)) {
    return line.trim().split(RegExp(r'\s+')).last.startsWith('@');
  }
  final state = _stateOpener.firstMatch(line)?.group(1);
  if (state != null) {
    return schema.keywords[state]?.role == Role.state && roleCounts(Role.state);
  }
  final keyword = _keywordOpener.firstMatch(line)?.group(1);
  final spec = schema.keywords[keyword];
  if (spec == null || !roleCounts(spec.role)) return false;
  return spec.block == null || line.trimRight() == keyword;
}

/// Whether a body line (other than the first) starts the keyword section.
bool _isSectionOpener(Schema schema, String line) =>
    _startsLine(schema, line, (r) => r.opensSection);

/// Whether a line terminates a block.
bool _endsBlock(Schema schema, String line) =>
    _startsLine(schema, line, (_) => true);

/// Parses one item file. Never throws — problems become [Diagnostic]s.
Document parseDocument(Schema schema, String text) {
  final rawLines = text.split('\n');
  final starts = <int>[];
  var at = 0;
  for (final l in rawLines) {
    starts.add(at);
    at += l.length + 1;
  }
  final lines = rawLines.map((l) => l.replaceAll('\r', '')).toList();

  final first = lines.indexWhere((l) => l.trim().isNotEmpty);
  if (first == -1) {
    return const Document(diagnostics: [Diagnostic(DiagnosticCode.empty)]);
  }

  final boundary = _indexFrom(
    lines,
    first + 1,
    (l) => _isSectionOpener(schema, l),
  );

  final parser = _SectionParser(schema);
  final blocks = <BlockRange>[];
  final contents = <String, List<String>>{};
  var i = boundary;
  while (i < lines.length) {
    final keyword = _blockKeyword(schema, lines[i]);
    if (keyword == null) {
      parser.parseLine(lines[i], i + 1, starts[i]);
      i++;
      continue;
    }
    final end = _indexFrom(lines, i + 1, (l) => _endsBlock(schema, l));
    final keywordEnd = starts[i] + lines[i].trimRight().length;
    blocks.add(BlockRange(keyword, i, end));
    parser.spans.add(Span(starts[i], keywordEnd, SpanKind.blockMarker));
    if (parser.claimBlock(keyword, i + 1, starts[i], keywordEnd)) {
      final content = _trimBlankEnds(lines.sublist(i + 1, end));
      contents[keyword] = content;
      parser.checkBlock(keyword, content, i + 1, starts[i], keywordEnd);
      if (content.isNotEmpty) {
        final to = end < lines.length ? starts[end] - 1 : text.length;
        parser.spans.add(Span(starts[i + 1], to, SpanKind.block));
      }
    }
    i = end;
  }
  parser.checkExcludes();

  return Document(
    body: _trimBlankEnds(lines.sublist(first, boundary)),
    clauses: parser.clauses,
    relations: parser.relations,
    state: parser.state,
    unknownLines: parser.unknownLines,
    extra: contents['extra'],
    data: contents['data'],
    dataValue: parser.dataValue,
    blocks: blocks,
    diagnostics: parser.diagnostics,
    spans: parser.spans,
    sectionStart: boundary,
  );
}

/// First index at or after [from] whose line satisfies [test], or
/// `lines.length`.
int _indexFrom(List<String> lines, int from, bool Function(String) test) {
  for (var i = from; i < lines.length; i++) {
    if (test(lines[i])) return i;
  }
  return lines.length;
}

List<String> _trimBlankEnds(List<String> lines) {
  var start = 0;
  var end = lines.length;
  while (start < end && lines[start].trim().isEmpty) {
    start++;
  }
  while (end > start && lines[end - 1].trim().isEmpty) {
    end--;
  }
  return lines.sublist(start, end);
}

class _Token {
  const _Token(this.text, this.start, this.end, {required this.quoted});

  final String text;

  /// Offsets in the tokenized string (end exclusive), quotes included.
  final int start;
  final int end;
  final bool quoted;
}

/// Whitespace-separated tokens; a token starting with `"` runs to the next
/// unescaped `"` (or the end of the line) and may contain spaces.
List<_Token> _tokenize(String line) {
  final tokens = <_Token>[];
  var i = 0;
  bool isSpace(int at) => line[at].trim().isEmpty;
  while (i < line.length) {
    if (isSpace(i)) {
      i++;
      continue;
    }
    final start = i;
    if (line[i] == '"') {
      final buf = StringBuffer();
      i++;
      while (i < line.length && line[i] != '"') {
        if (line[i] == r'\' && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i += 2;
        } else {
          buf.write(line[i]);
          i++;
        }
      }
      if (i < line.length) i++; // the closing quote
      tokens.add(_Token(buf.toString(), start, i, quoted: true));
    } else {
      while (i < line.length && !isSpace(i)) {
        i++;
      }
      tokens.add(_Token(line.substring(start, i), start, i, quoted: false));
    }
  }
  return tokens;
}

class _SectionParser {
  _SectionParser(this.schema);

  final Schema schema;
  final clauses = <Clause>[];
  final relations = <Relation>[];
  final state = <Clause>[];
  final unknownLines = <String>[];
  final diagnostics = <Diagnostic>[];
  final spans = <Span>[];
  final _seen = <String>{};

  /// The parsed `data` block, when it is a valid mapping.
  Map<String, Object?>? dataValue;

  /// Offsets of each of [clauses]' keyword token, for [checkExcludes].
  final _clauseKeywords = <(int, int)>[];

  /// Offsets of the current trimmed line in the text.
  int _from = 0;
  int _to = 0;

  bool _isKnownKeyword(_Token t) =>
      !t.quoted && schema.keywords.containsKey(t.text);

  /// Registers a block keyword; false (with an error) when it appeared before.
  bool claimBlock(String keyword, int lineNo, int from, int to) {
    if (_seen.add(keyword)) return true;
    _error(DiagnosticCode.duplicateKeyword, lineNo, keyword, from, to);
    return false;
  }

  /// Reports an empty block, or a `yaml` block that isn't a YAML mapping.
  void checkBlock(
    String keyword,
    List<String> content,
    int lineNo,
    int from,
    int to,
  ) {
    final kind = schema.keywords[keyword]!.block!;
    if (content.isEmpty) {
      final code = kind == BlockKind.yaml
          ? DiagnosticCode.emptyData
          : DiagnosticCode.emptyExtra;
      _error(code, lineNo, keyword, from, to);
    } else if (kind == BlockKind.yaml) {
      final value = _yamlMapping(content.join('\n'));
      if (value == null) {
        _error(DiagnosticCode.invalidYaml, lineNo, keyword, from, to);
      } else if (keyword == 'data') {
        dataValue = value;
      }
    }
  }

  /// [lineStart] is the offset of [rawLine] in the text.
  void parseLine(String rawLine, int lineNo, int lineStart) {
    final line = rawLine.trim();
    if (line.isEmpty) return;
    _from = lineStart + rawLine.indexOf(line);
    _to = _from + line.length;

    if (line == '->' || _relationOpener.hasMatch(line)) {
      _relation(line, lineNo);
    } else if (line.startsWith('(')) {
      _stateLine(line, lineNo);
    } else {
      _clauseLine(line, lineNo);
    }
  }

  void _relation(String line, int lineNo) {
    final rest = line.substring(2).trim();
    final target = rest.isEmpty ? '' : rest.split(RegExp(r'\s+')).last;
    if (target.length < 2 ||
        !target.startsWith('@') ||
        target.contains('/') ||
        target.contains(r'\')) {
      _error(DiagnosticCode.invalidRelation, lineNo, line);
      return;
    }
    relations.add(
      Relation(
        label: rest.substring(0, rest.length - target.length).trim(),
        target: target.substring(1),
        line: lineNo,
      ),
    );
    spans
      ..add(Span(_from, _from + 2, SpanKind.relation))
      ..add(Span(_to - target.length, _to, SpanKind.target));
  }

  void _stateLine(String line, int lineNo) {
    if (!line.endsWith(')')) {
      _error(DiagnosticCode.invalidState, lineNo, line);
      return;
    }
    final tokens = _tokenize(line.substring(1, line.length - 1));
    final keyword = tokens.firstOrNull;
    if (keyword == null ||
        keyword.quoted ||
        !_keywordToken.hasMatch(keyword.text)) {
      _error(DiagnosticCode.invalidState, lineNo, line);
      return;
    }
    final spec = schema.keywords[keyword.text];
    if (spec == null) {
      _unknown(line, lineNo, keyword.text, _from);
      return;
    }
    if (spec.role != Role.state) {
      _error(DiagnosticCode.invalidState, lineNo, line);
      return;
    }
    // Token offsets are relative to the text inside the parentheses.
    final base = _from + 1;
    final parsed = _clause(tokens, 0, lineNo, base, line.substring(1, line.length - 1));
    if (parsed == null) return;
    if (parsed.next < tokens.length) {
      final t = tokens[parsed.next];
      _error(DiagnosticCode.unexpectedToken, lineNo, t.text, base + t.start);
      return;
    }
    state.add(parsed.clause);
  }

  void _clauseLine(String line, int lineNo) {
    final tokens = _tokenize(line);
    var i = 0;
    while (i < tokens.length) {
      final token = tokens[i];
      final from = _from + token.start;
      if (token.quoted || !_keywordToken.hasMatch(token.text)) {
        _error(DiagnosticCode.unexpectedToken, lineNo, token.text, from);
        return;
      }
      final spec = schema.keywords[token.text];
      if (spec == null) {
        _unknown(line.substring(token.start), lineNo, token.text, from);
        return;
      }
      if (spec.role == Role.state || spec.block != null) {
        _error(DiagnosticCode.unexpectedToken, lineNo, token.text, from);
        return;
      }
      final parsed = _clause(tokens, i, lineNo, _from, line);
      if (parsed == null) return;
      clauses.add(parsed.clause);
      _clauseKeywords.add((from, _from + token.end));
      i = parsed.next;
    }
  }

  /// The clause whose keyword is `tokens[i]`, and the index after it; null
  /// (with an error reported) when it's malformed. [base] is the offset in
  /// the text that the tokens' offsets are relative to, and [source] the
  /// string the tokens were cut from.
  ({Clause clause, int next})? _clause(
    List<_Token> tokens,
    int i,
    int lineNo,
    int base,
    String source,
  ) {
    final spec = schema.keywords[tokens[i].text]!;
    final keyword = tokens[i];
    i++;
    if (!_seen.add(spec.name)) {
      _error(
        DiagnosticCode.duplicateKeyword,
        lineNo,
        spec.name,
        base + keyword.start,
      );
      return null;
    }
    _span(keyword, base, SpanKind.values.byName(spec.role.name));

    final args = <Value>[];
    for (final arg in spec.args) {
      if (arg.types.length == 1 && arg.types.single == ValueType.text) {
        if (i >= tokens.length) {
          _error(
            DiagnosticCode.missingArg,
            lineNo,
            spec.name,
            base + keyword.start,
            base + keyword.end,
          );
          return null;
        }
        final rest = source.substring(tokens[i].start).trim();
        spans.add(
          Span(
            base + tokens[i].start,
            base + tokens[i].start + rest.length,
            SpanKind.text,
          ),
        );
        args.add(TextValue(rest));
        i = tokens.length;
        continue;
      }
      if (i >= tokens.length || _isKnownKeyword(tokens[i])) {
        _error(
          DiagnosticCode.missingArg,
          lineNo,
          spec.name,
          base + keyword.start,
          base + keyword.end,
        );
        return null;
      }
      final value = _value(tokens[i], arg);
      if (value == null) {
        _error(
          DiagnosticCode.invalidValue,
          lineNo,
          tokens[i].text,
          base + tokens[i].start,
        );
        return null;
      }
      _span(tokens[i], base, _valueKind(value));
      args.add(value);
      i++;
    }

    final options = <String, Value>{};
    while (i < tokens.length &&
        !tokens[i].quoted &&
        spec.options.containsKey(tokens[i].text)) {
      final option = tokens[i];
      final name = option.text;
      i++;
      if (options.containsKey(name)) {
        _error(
          DiagnosticCode.duplicateKeyword,
          lineNo,
          name,
          base + option.start,
        );
        return null;
      }
      _span(option, base, SpanKind.option);
      if (i >= tokens.length || _isKnownKeyword(tokens[i])) {
        _error(
          DiagnosticCode.missingArg,
          lineNo,
          name,
          base + option.start,
          base + option.end,
        );
        return null;
      }
      final value = _value(tokens[i], spec.options[name]!);
      if (value == null) {
        _error(
          DiagnosticCode.invalidValue,
          lineNo,
          tokens[i].text,
          base + tokens[i].start,
        );
        return null;
      }
      _span(tokens[i], base, _valueKind(value));
      options[name] = value;
      i++;
    }

    return (
      clause: Clause(
        keyword: spec.name,
        line: lineNo,
        args: args,
        options: options,
      ),
      next: i,
    );
  }

  /// Reports each excluded pair once, on the later clause's keyword.
  void checkExcludes() {
    for (var a = 0; a < clauses.length; a++) {
      for (var b = a + 1; b < clauses.length; b++) {
        final first = clauses[a].keyword;
        final second = clauses[b].keyword;
        final excluded =
            schema.keywords[first]!.excludes.contains(second) ||
            schema.keywords[second]!.excludes.contains(first);
        if (excluded) {
          final (from, to) = _clauseKeywords[b];
          diagnostics.add(
            Diagnostic(
              DiagnosticCode.conflictingKeywords,
              line: clauses[b].line,
              detail: '$first, $second',
              from: from,
              to: to,
            ),
          );
        }
      }
    }
  }

  void _span(_Token token, int base, SpanKind kind) =>
      spans.add(Span(base + token.start, base + token.end, kind));

  static SpanKind _valueKind(Value value) => switch (value) {
    DateValue() => SpanKind.date,
    MonthValue() => SpanKind.month,
    WeekdayValue() => SpanKind.weekday,
    PathValue() => SpanKind.path,
    TextValue() => SpanKind.text,
  };

  /// By default the problem runs from [from] (the line's start) to the end
  /// of the line, as the rest of the line is skipped.
  void _error(
    DiagnosticCode code,
    int line,
    String detail, [
    int? from,
    int? to,
  ]) => diagnostics.add(
    Diagnostic(
      code,
      line: line,
      detail: detail,
      from: from ?? _from,
      to: to ?? _to,
    ),
  );

  void _unknown(String raw, int line, String keyword, int from) {
    unknownLines.add(raw);
    spans.add(Span(from, _to, SpanKind.unknown));
    diagnostics.add(
      Diagnostic(
        DiagnosticCode.unknownKeyword,
        line: line,
        detail: keyword,
        from: from,
        to: _to,
      ),
    );
  }

  /// Only a `path` may be quoted.
  Value? _value(_Token token, ValueSpec spec) {
    for (final type in spec.types) {
      if (token.quoted && type != ValueType.path) continue;
      final value = switch (type) {
        ValueType.date => _date(token.text),
        ValueType.month => _month(token.text),
        ValueType.weekday => _weekday(token.text),
        ValueType.path => _path(token.text),
        ValueType.text => null,
      };
      if (value != null) return value;
    }
    return null;
  }
}

const _weekdays = {
  'mo': DateTime.monday,
  'tu': DateTime.tuesday,
  'we': DateTime.wednesday,
  'th': DateTime.thursday,
  'fr': DateTime.friday,
  'sa': DateTime.saturday,
  'su': DateTime.sunday,
};

/// `yy-mm-dd`, year 20yy, only when it's a real calendar date.
DateValue? _date(String text) {
  final match = RegExp(r'^(\d{2})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) return null;
  final y = 2000 + int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  final d = int.parse(match.group(3)!);
  final date = DateOnly.fromDateTime(DateTime(y, m, d));
  return date == DateOnly(y, m, d) ? DateValue(text, date) : null;
}

/// `yy-mm`, year 20yy.
MonthValue? _month(String text) {
  final match = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) return null;
  final m = int.parse(match.group(2)!);
  if (m < 1 || m > 12) return null;
  return MonthValue(text, 2000 + int.parse(match.group(1)!), m);
}

WeekdayValue? _weekday(String text) {
  final weekday = _weekdays[text];
  return weekday == null ? null : WeekdayValue(text, weekday);
}

/// Relative to the item's folder: not empty, no leading `/`, no `\`, no `..`
/// segment.
PathValue? _path(String text) {
  final valid =
      text.isNotEmpty &&
      !text.startsWith('/') &&
      !text.contains(r'\') &&
      !text.split('/').contains('..');
  return valid ? PathValue(text) : null;
}

/// The YAML mapping in [text] as plain maps and lists, or null when it is not
/// valid YAML or not a mapping.
Map<String, Object?>? _yamlMapping(String text) {
  try {
    final value = _plain(loadYaml(text));
    return value is Map<String, Object?> ? value : null;
  } on YamlException {
    return null;
  }
}

Object? _plain(Object? node) => switch (node) {
  YamlMap() => {for (final e in node.entries) '${e.key}': _plain(e.value)},
  YamlList() => [for (final e in node) _plain(e)],
  _ => node,
};
