import 'package:flutter/material.dart';

import '../models/item.dart';

/// One item as listed under a day: its heading, the rest of its body muted
/// beneath it, and a "weekly" marker on recurring items.
class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.outline);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(item.heading)),
              if (item.kind is Recurring)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'weekly',
                    style: theme.textTheme.labelSmall?.merge(muted),
                  ),
                ),
            ],
          ),
          if (item.details.isNotEmpty)
            Text(
              item.details.join('\n'),
              style: theme.textTheme.bodySmall?.merge(muted),
            ),
        ],
      ),
    );
  }
}
