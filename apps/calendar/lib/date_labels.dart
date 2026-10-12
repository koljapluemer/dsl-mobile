import 'package:dsl/dsl.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// e.g. `Fri, 29 Aug 2026`. [DateTime.weekday] is 1 = Mon .. 7 = Sun.
String formatDayHeading(DateOnly date) {
  final dt = date.toDateTime();
  return '${_weekdays[dt.weekday - 1]}, ${date.day} '
      '${_months[date.month - 1]} ${date.year}';
}

/// e.g. `29 Aug 2026`.
String formatShortDate(DateOnly date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';
