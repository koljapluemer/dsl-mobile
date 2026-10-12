import 'package:dsl/dsl.dart';

/// When an item shows up in the calendar — the calendar's meaning for the
/// primary keywords it knows.
sealed class ItemKind {
  const ItemKind();

  bool occursOn(DateOnly day);
}

/// `appointment <date>` — a single day.
class Appointment extends ItemKind {
  const Appointment(this.date);

  final DateOnly date;

  @override
  bool occursOn(DateOnly day) => day == date;
}

/// `recurring <weekday> [until <date|month>]` — every [weekday] (1 = Mon ..
/// 7 = Sun), with no start bound, up to and including [until] when set.
class Recurring extends ItemKind {
  const Recurring(this.weekday, {this.until});

  final int weekday;
  final DateOnly? until;

  @override
  bool occursOn(DateOnly day) =>
      day.weekday == weekday && (until == null || day.compareTo(until!) <= 0);
}

/// One valid item file. See the dsl repo's `spec/language.md` for the format.
class Item {
  const Item({
    required this.path,
    required this.heading,
    required this.kind,
    this.details = const [],
    this.warnings = const [],
  });

  final String path;

  /// The first body line, trimmed.
  final String heading;

  /// The remaining body lines, verbatim.
  final List<String> details;

  /// Null for a valid item without a primary keyword the calendar knows: a
  /// plain note, or a type added to the schema later. It falls on no day.
  final ItemKind? kind;

  /// E.g. unknown keywords. They don't make the item invalid.
  final List<Diagnostic> warnings;

  bool occursOn(DateOnly day) => kind?.occursOn(day) ?? false;
}
