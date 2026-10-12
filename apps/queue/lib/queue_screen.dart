import 'dart:math';

import 'package:dsl/dsl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// The app's one screen: a few random items from the whole folder, and a
/// "Next" button to draw others. Read-only: nothing here writes to the
/// folder.
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key, required this.repository});

  final FolderRepository repository;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  static const _batchSize = 3;

  final _random = Random();

  /// File names of the batch on screen; resolved against the repository on
  /// every build, so a reload shows fresh text and drops deleted files.
  List<String> _batch = [];

  @override
  void initState() {
    super.initState();
    _batch = _draw();
    widget.repository.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  List<String> _draw() {
    final names = [for (final i in widget.repository.items) i.name]
      ..shuffle(_random);
    return names.take(_batchSize).toList();
  }

  /// The first batch is drawn before the cache or a scan has items on a
  /// first start; draw one once they arrive. A batch on screen stays.
  void _onRepositoryChanged() {
    if (!mounted) return;
    setState(() {
      if (_resolved().isEmpty) _batch = _draw();
    });
  }

  List<ItemFile> _resolved() => [
    for (final name in _batch) ?widget.repository.itemNamed(name),
  ];

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: SettingsScreen(repository: widget.repository, writes: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    final items = _resolved();
    final folder = repo.folderPath!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      floatingActionButton: RefreshFab(repository: repo),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (repo.loadError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  repo.loadError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        repo.isLoading ? 'Loading items…' : 'No items found',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 32),
                      itemBuilder: (_, i) => _ItemCard(
                        key: ValueKey(items[i].name),
                        item: items[i],
                        folder: folder,
                      ),
                    ),
            ),
            Padding(
              // Right inset keeps the button clear of the FAB.
              padding: const EdgeInsets.fromLTRB(16, 8, 88, 16),
              child: FilledButton.icon(
                onPressed: repo.items.isEmpty
                    ? null
                    : () => setState(() => _batch = _draw()),
                icon: const Icon(Icons.skip_next),
                label: const Text('Next'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One item: its body, its attachment, and its extra content behind a
/// toggle. Keyword lines and relationships aren't shown. A file that isn't a
/// valid item is shown as its raw text, marked invalid.
class _ItemCard extends StatelessWidget {
  const _ItemCard({super.key, required this.item, required this.folder});

  final ItemFile item;
  final String folder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!item.isValid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invalid: ${item.name}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 4),
          Text(item.readError ?? item.text),
        ],
      );
    }
    final media = item.mediaPathIn(folder);
    final extra = item.extra;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Body and extra lines are kept verbatim, so line breaks show.
        MarkdownBody(data: item.body, softLineBreak: true),
        if (media != null) ...[
          const SizedBox(height: 12),
          MediaPreview(path: media),
        ],
        if (extra != null)
          Theme(
            // No divider lines around the expander.
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text('More', style: theme.textTheme.labelLarge),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [MarkdownBody(data: extra, softLineBreak: true)],
            ),
          ),
      ],
    );
  }
}
