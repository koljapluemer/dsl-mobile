import 'date_only.dart';
import 'document.dart';
import 'schema.dart';

/// Text edits behind the editor's quick buttons. Each works on the whole item
/// text and returns the new text plus where the cursor should go. They touch
/// only whole keyword lines, so everything else in the file stays verbatim.
typedef TextEdit = ({String text, int cursor});

/// `yy-mm-dd`.
String formatDate(DateOnly date) =>
    '${(date.year % 100).toString().padLeft(2, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// A `path` value as a token: quoted when it contains whitespace or quotes.
String formatPath(String path) =>
    RegExp(r'[\s"]').hasMatch(path) ? '"${path.replaceAll('"', r'\"')}"' : path;

/// Sets [keyword]'s clause to [clause] (a whole line, e.g.
/// `appointment 26-10-12`). Replaces the keyword-section line that starts with
/// [keyword] when no other clause shares it; otherwise adds [clause] as a new
/// line at the end of the keyword section.
///
/// With no body yet, the clause goes on the second line and the cursor on the
/// empty first one: the first line is always body.
TextEdit setClause(Schema schema, String text, String keyword, String clause) {
  if (text.trim().isEmpty) return (text: '\n$clause\n', cursor: 0);
  final lines = text.split('\n');
  final doc = parseDocument(schema, text);
  final at = _ownLine(doc, lines, keyword);
  if (at != null) {
    lines[at] = clause;
    return (text: lines.join('\n'), cursor: _endOfLine(lines, at));
  }
  final insertAt = _sectionEnd(doc, lines);
  lines.insert(insertAt, clause);
  return (text: lines.join('\n'), cursor: _endOfLine(lines, insertAt));
}

/// Removes the keyword-section line that starts with [keyword], when no other
/// clause shares it. Returns null when there's no such line.
TextEdit? removeClause(Schema schema, String text, String keyword) {
  final lines = text.split('\n');
  final at = _ownLine(parseDocument(schema, text), lines, keyword);
  if (at == null) return null;
  lines.removeAt(at);
  return (
    text: lines.join('\n'),
    cursor: at == 0 ? 0 : _endOfLine(lines, at - 1),
  );
}

/// Adds the `extra` keyword at the end when there is none; the cursor goes to
/// the end of the text, where the extra content is typed.
TextEdit ensureExtra(Schema schema, String text) {
  if (parseDocument(schema, text).extraMarker != null) {
    return (text: text, cursor: text.length);
  }
  final trimmed = text.trimRight();
  final next = '$trimmed\nextra\n';
  return (text: next, cursor: next.length);
}

/// The keyword-section line (0-based) whose first token is [keyword], unless
/// another clause shares it. Lines inside blocks are skipped.
int? _ownLine(Document doc, List<String> lines, String keyword) {
  final starts = RegExp('^${RegExp.escape(keyword)}(?=\\s|\$)');
  for (var i = doc.sectionStart; i < lines.length; i++) {
    final block = doc.blocks.where((b) => b.line == i).firstOrNull;
    if (block != null) {
      i = block.end - 1;
      continue;
    }
    if (!starts.hasMatch(lines[i].trim())) continue;
    final shared = doc.clauses.any(
      (c) => c.line == i + 1 && c.keyword != keyword,
    );
    return shared ? null : i;
  }
  return null;
}

/// Where a new keyword line goes: after the last non-blank line before the
/// first block (or the end of the file).
int _sectionEnd(Document doc, List<String> lines) {
  var end = doc.firstBlock ?? lines.length;
  while (end > 0 && lines[end - 1].trim().isEmpty) {
    end--;
  }
  return end;
}

int _endOfLine(List<String> lines, int index) =>
    lines.take(index + 1).fold(0, (n, l) => n + l.length + 1) - 1;
