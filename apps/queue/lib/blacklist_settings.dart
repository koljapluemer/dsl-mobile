import 'package:flutter/material.dart';

import 'blacklist.dart';
import 'queue_repository.dart';

/// Settings section: the item types and tags the queue ignores.
class BlacklistSettings extends StatelessWidget {
  const BlacklistSettings({super.key, required this.repository});

  final QueueRepository repository;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final blacklist = repository.blacklist;
    // Blacklisted types no longer in the folder stay listed, so they can be
    // un-blacklisted.
    final types = {...repository.knownTypes, ...blacklist.types}.toList()
      ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hidden types', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (types.isEmpty)
          Text('No typed items', style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final type in types)
                FilterChip(
                  label: Text(type),
                  selected: blacklist.types.contains(type),
                  onSelected: (selected) => repository.setBlacklist(
                    blacklist.copyWith(
                      types: selected
                          ? {...blacklist.types, type}
                          : ({...blacklist.types}..remove(type)),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 24),
        Text('Hidden tags', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TagInput(
          tags: blacklist.tags,
          suggestions: repository.knownTags,
          onChanged: (tags) =>
              repository.setBlacklist(blacklist.copyWith(tags: tags)),
        ),
      ],
    );
  }
}

/// Removable chips for [tags], and a field that adds one on enter, space or
/// comma, suggesting from [suggestions]. Input is lowercased; anything that
/// isn't a valid tag is not added.
class TagInput extends StatefulWidget {
  const TagInput({
    super.key,
    required this.tags,
    required this.suggestions,
    required this.onChanged,
  });

  final Set<String> tags;
  final List<String> suggestions;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final tag = raw.trim().toLowerCase();
    if (tag.isEmpty) return;
    if (!tagPattern.hasMatch(tag)) {
      setState(() => _error = 'Tags are a-z, 0-9 and -');
      return;
    }
    _controller.clear();
    setState(() => _error = null);
    if (!widget.tags.contains(tag)) widget.onChanged({...widget.tags, tag});
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.tags.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in tags)
                InputChip(
                  label: Text(tag),
                  onDeleted: () =>
                      widget.onChanged({...widget.tags}..remove(tag)),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        RawAutocomplete<String>(
          textEditingController: _controller,
          focusNode: _focusNode,
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return const [];
            return widget.suggestions.where(
              (t) => t.startsWith(query) && !widget.tags.contains(t),
            );
          },
          onSelected: _add,
          fieldViewBuilder: (context, controller, focusNode, _) => TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(hintText: 'Add tag', errorText: _error),
            onChanged: (text) {
              if (text.endsWith(' ') || text.endsWith(',')) {
                _add(text.substring(0, text.length - 1));
              }
            },
            onSubmitted: (text) {
              _add(text);
              focusNode.requestFocus();
            },
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final option in options)
                      ListTile(
                        title: Text(option),
                        onTap: () => onSelected(option),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
