import 'dart:io';

import 'package:dsl/dsl.dart';
import 'package:flutter/material.dart';

import '../delete_item_notification.dart';
import '../edit_repository.dart';
import 'edit_screen.dart';

/// Every item, filterable by text and by "needs attention", with per-row
/// edit and delete.
class ListScreen extends StatefulWidget {
  const ListScreen({super.key, required this.repository});

  final EditRepository repository;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final _filterController = TextEditingController();
  final _filterFocus = FocusNode();
  String _query = '';
  bool _attentionOnly = false;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepositoryChanged);
    // Filter on blur/submit rather than on every keystroke.
    _filterFocus.addListener(() {
      if (!_filterFocus.hasFocus) _applyFilter();
    });
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    _filterController.dispose();
    _filterFocus.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() => setState(() {});

  void _applyFilter() {
    final query = _filterController.text.trim().toLowerCase();
    if (query != _query) setState(() => _query = query);
  }

  List<ItemFile> _visible() => [
    for (final item in widget.repository.visibleItems)
      if ((!_attentionOnly || item.needsAttention) &&
          (_query.isEmpty || item.text.toLowerCase().contains(_query)))
        item,
  ];

  void _delete(ItemFile item) {
    final id = widget.repository.beginPendingDelete(item.name);
    DeleteItemNotification(
      context: context,
      repository: widget.repository,
      pendingId: id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    final items = _visible();
    final flagged = repo.items.where((i) => i.needsAttention).length;
    return Scaffold(
      floatingActionButton: RefreshFab(repository: repo),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _filterController,
                    focusNode: _filterFocus,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _applyFilter(),
                    decoration: const InputDecoration(
                      hintText: 'Filter items…',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  isSelected: _attentionOnly,
                  tooltip: 'Needs attention ($flagged)',
                  icon: Badge.count(
                    count: flagged,
                    isLabelVisible: flagged > 0,
                    child: const Icon(Icons.warning_amber),
                  ),
                  onPressed: () =>
                      setState(() => _attentionOnly = !_attentionOnly),
                ),
              ],
            ),
            if (repo.loadError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  repo.loadError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        repo.isLoading ? 'Loading items…' : 'No items found',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88), // the FAB
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) => _row(items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ItemFile item) {
    final theme = Theme.of(context);
    final media = item.mediaPathIn(widget.repository.folderPath!);
    final problems = [
      ?item.readError,
      for (final d in item.doc.diagnostics) d.toString(),
    ];
    return ListTile(
      key: ValueKey(item.name),
      contentPadding: EdgeInsets.zero,
      onTap: () => openEditor(context, widget.repository, item.name),
      leading: media == null
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: isVideoFilename(media)
                  ? Container(
                      width: 40,
                      height: 40,
                      color: Colors.black26,
                      child: const Icon(Icons.play_circle_outline),
                    )
                  : Image.file(
                      File(media),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      cacheWidth: 96,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
      title: Text(item.heading, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: problems.isEmpty
          ? null
          : Text(
              problems.join('\n'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: item.isValid
                    ? theme.colorScheme.outline
                    : theme.colorScheme.error,
              ),
            ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete',
        onPressed: () => _delete(item),
      ),
    );
  }
}
