import 'package:dsl/dsl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startOfWeek of a Sunday is itself', () {
    expect(
      const DateOnly(2026, 10, 11).startOfWeek(),
      const DateOnly(2026, 10, 11),
    );
  });

  test('startOfWeek of a Saturday is the Sunday before', () {
    expect(
      const DateOnly(2026, 10, 17).startOfWeek(),
      const DateOnly(2026, 10, 11),
    );
  });

  test('addDays crosses month and year ends', () {
    expect(const DateOnly(2026, 12, 31).addDays(1), const DateOnly(2027, 1, 1));
    expect(const DateOnly(2026, 3, 1).addDays(-1), const DateOnly(2026, 2, 28));
  });
}
