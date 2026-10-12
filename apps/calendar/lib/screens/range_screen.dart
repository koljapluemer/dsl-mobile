import 'package:flutter/material.dart';

import '../date_labels.dart';
import 'package:dsl/dsl.dart';
import '../repository/calendar_repository.dart';
import 'item_tile.dart';

/// Second tab: every day of an explicit From..To range (inclusive), each with
/// its items — empty days included. Defaults to the current Sunday-to-Saturday
/// week.
class RangeScreen extends StatefulWidget {
  const RangeScreen({super.key, required this.repository});

  final CalendarRepository repository;

  @override
  State<RangeScreen> createState() => _RangeScreenState();
}

class _RangeScreenState extends State<RangeScreen> {
  late DateOnly _from = DateOnly.today().startOfWeek();
  late DateOnly _to = _from.addDays(6);

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<DateOnly?> _pick(DateOnly initial) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.toDateTime(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    return picked == null ? null : DateOnly.fromDateTime(picked);
  }

  /// A From after To drags To along with it, so the range is never empty.
  Future<void> _pickFrom() async {
    final picked = await _pick(_from);
    if (picked == null) return;
    setState(() {
      _from = picked;
      if (_to.compareTo(_from) < 0) _to = _from;
    });
  }

  /// A To before From drags From along with it.
  Future<void> _pickTo() async {
    final picked = await _pick(_to);
    if (picked == null) return;
    setState(() {
      _to = picked;
      if (_from.compareTo(_to) > 0) _from = _to;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateOnly.today();
    final days = [
      for (var d = _from; d.compareTo(_to) <= 0; d = d.addDays(1)) d,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickFrom,
                  child: Text('From ${formatShortDate(_from)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickTo,
                  child: Text('To ${formatShortDate(_to)}'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              88,
            ), // clear of the FAB
            children: [
              for (final day in days) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    day == today
                        ? 'Today — ${formatDayHeading(day)}'
                        : formatDayHeading(day),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: day == today ? theme.colorScheme.primary : null,
                      fontWeight: day == today ? FontWeight.bold : null,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ..._dayBody(day, theme),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _dayBody(DateOnly day, ThemeData theme) {
    final items = widget.repository.itemsOn(day);
    if (items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Nothing',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
      ];
    }
    return [for (final item in items) ItemTile(item: item)];
  }
}
