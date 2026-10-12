import 'package:flutter/material.dart';

import '../date_labels.dart';
import 'package:dsl/dsl.dart';
import '../repository/calendar_repository.dart';
import 'item_tile.dart';

/// First tab: the items of a single day, starting on today. The bar on top
/// steps a day back/forward, picks a date, or jumps back to today.
class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.repository});

  final CalendarRepository repository;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  DateOnly _day = DateOnly.today();

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

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.toDateTime(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _day = DateOnly.fromDateTime(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateOnly.today();
    final items = widget.repository.itemsOn(_day);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous day',
                onPressed: () => setState(() => _day = _day.addDays(-1)),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDay,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _day == today
                        ? 'Today — ${formatDayHeading(_day)}'
                        : formatDayHeading(_day),
                  ),
                ),
              ),
              TextButton(
                onPressed: _day == today
                    ? null
                    : () => setState(() => _day = today),
                child: const Text('Today'),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next day',
                onPressed: () => setState(() => _day = _day.addDays(1)),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    'Nothing on this day',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    88,
                  ), // clear of the FAB
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => ItemTile(item: items[i]),
                ),
        ),
      ],
    );
  }
}
