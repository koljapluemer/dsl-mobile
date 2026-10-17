import 'package:dsl/dsl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'card_color.dart';
import 'zero_repository.dart';

/// The app's one screen: a card per item tagged `zero`, in a random order
/// drawn per session. Tapping a card greys it out and moves it to the bottom
/// until the app restarts. Read-only: nothing here writes to the folder.
class ZeroScreen extends StatelessWidget {
  const ZeroScreen({super.key, required this.repository});

  final ZeroRepository repository;

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: SettingsScreen(repository: repository, writes: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('zero'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      floatingActionButton: RefreshFab(repository: repository),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: repository,
          builder: (context, _) => _buildList(context),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final repo = repository;
    final items = repo.ordered;
    return Column(
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
                  // Bottom padding keeps the last card clear of the FAB.
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ItemCard(
                    key: ValueKey(items[i].name),
                    item: items[i],
                    done: repo.isDone(items[i].name),
                    onTap: () => repo.markDone(items[i].name),
                  ),
                ),
        ),
      ],
    );
  }
}

/// An item's body as Markdown on a card whose hue comes from its file name.
/// A file without a body (e.g. unreadable) shows its raw text instead.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.done,
    required this.onTap,
  });

  final ItemFile item;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = item.body;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: done ? 0.4 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cardColorFor(item.name),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(
              data: body.trim().isEmpty ? item.readError ?? item.text : body,
              softLineBreak: true,
              styleSheet: _markdownStyle(Theme.of(context)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything on a card is black. The card colors are always light, so code
/// backgrounds are a black tint instead of the (possibly dark) theme surface,
/// and links are marked by an underline rather than a color.
MarkdownStyleSheet _markdownStyle(ThemeData theme) {
  final black = theme.copyWith(
    textTheme: theme.textTheme.apply(
      bodyColor: Colors.black,
      displayColor: Colors.black,
    ),
  );
  final base = MarkdownStyleSheet.fromTheme(black);
  final codeBackground = Colors.black.withValues(alpha: 0.08);
  return base.copyWith(
    a: const TextStyle(
      color: Colors.black,
      decoration: TextDecoration.underline,
    ),
    code: base.code!.copyWith(backgroundColor: codeBackground),
    codeblockDecoration: BoxDecoration(
      color: codeBackground,
      borderRadius: BorderRadius.circular(4),
    ),
    checkbox: base.checkbox!.copyWith(color: Colors.black),
    blockquoteDecoration: BoxDecoration(
      color: codeBackground,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}
