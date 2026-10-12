/// A calendar date with no time component. Two [DateOnly] values are equal when
/// they fall on the same calendar day.
class DateOnly implements Comparable<DateOnly> {
  const DateOnly(this.year, this.month, this.day);

  factory DateOnly.fromDateTime(DateTime dt) =>
      DateOnly(dt.year, dt.month, dt.day);

  static DateOnly today() => DateOnly.fromDateTime(DateTime.now());

  final int year;
  final int month;
  final int day;

  DateTime toDateTime() => DateTime(year, month, day);

  /// 1 = Mon .. 7 = Sun, as [DateTime.weekday].
  int get weekday => toDateTime().weekday;

  /// Built from calendar components (not a [Duration]) so DST shifts can't
  /// land it on the wrong day.
  DateOnly addDays(int days) =>
      DateOnly.fromDateTime(DateTime(year, month, day + days));

  /// The Sunday on or before this date — weeks start on Sunday.
  DateOnly startOfWeek() => addDays(-(weekday % 7));

  /// `YYYY-MM-DD`.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(DateOnly other) => toDateTime().compareTo(other.toDateTime());

  @override
  bool operator ==(Object other) =>
      other is DateOnly &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
