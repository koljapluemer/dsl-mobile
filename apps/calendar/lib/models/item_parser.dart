import 'package:dsl/dsl.dart';
import 'item.dart';

sealed class ParseResult {
  const ParseResult();
}

class ParsedItem extends ParseResult {
  const ParsedItem(this.item);

  final Item item;
}

/// A file that isn't a valid item, with the errors that make it so — or, when
/// it couldn't even be read, [readError].
class ParseError extends ParseResult {
  const ParseError(this.path, this.errors, {this.readError});

  final String path;
  final List<Diagnostic> errors;
  final String? readError;
}

/// Parses one item file per [schema] and gives the keywords the calendar knows
/// their meaning. Never throws.
ParseResult parseItem(Schema schema, String path, String text) =>
    calendarItem(path, parseDocument(schema, text));

/// Gives an already parsed item file the calendar's meaning. Never throws.
ParseResult calendarItem(String path, Document doc) {
  if (!doc.isValid) return ParseError(path, doc.errors.toList());
  return ParsedItem(
    Item(
      path: path,
      heading: doc.body.first.trim(),
      details: doc.body.sublist(1),
      kind: _kind(doc),
      warnings: doc.warnings.toList(),
    ),
  );
}

/// Matches on value shapes rather than casting, so a schema change the
/// calendar hasn't caught up with yields "no kind" instead of a crash.
ItemKind? _kind(Document doc) {
  if (doc.clause('appointment') case Clause(args: [DateValue(:final date)])) {
    return Appointment(date);
  }
  if (doc.clause('recurring') case Clause(
    args: [WeekdayValue(:final weekday)],
    :final options,
  )) {
    final until = switch (options['until']) {
      DateValue(:final date) => date,
      MonthValue month => month.lastDay,
      _ => null,
    };
    return Recurring(weekday, until: until);
  }
  return null;
}
