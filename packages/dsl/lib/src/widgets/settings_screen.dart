import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../folder_repository.dart';

/// The data folder, its load state, its invalid files and warnings, and (on
/// Android) the storage permission.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.writes,
    this.sections = const [],
  });

  final FolderRepository repository;

  /// Whether the app writes to the folder; only changes the permission text.
  final bool writes;

  /// App-specific settings, shown below the folder controls.
  final List<Widget> sections;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _pickFolder() async {
    setState(() => _busy = true);
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path != null) await widget.repository.setFolder(path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestPermission() async {
    await Permission.manageExternalStorage.request();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final repo = widget.repository;
    final theme = Theme.of(context);
    final invalid = repo.items.where((i) => !i.isValid).toList();
    final warned = repo.items
        .where((i) => i.isValid && i.doc.warnings.isNotEmpty)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Data folder', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(repo.folderPath ?? 'Not set'),
        const SizedBox(height: 4),
        Text(
          repo.isLoading
              ? 'Loading… (${repo.count} items so far)'
              : '${repo.count} items loaded',
          style: theme.textTheme.bodySmall,
        ),
        if (repo.loadError != null) ...[
          const SizedBox(height: 8),
          Text(
            repo.loadError!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _pickFolder,
          child: Text(_busy ? 'Loading…' : 'Choose folder'),
        ),
        if (repo.folderPath != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: repo.isLoading ? null : repo.loadFromDisk,
            child: Text(repo.isLoading ? 'Reloading…' : 'Reload'),
          ),
        ],
        for (final section in widget.sections) ...[
          const SizedBox(height: 32),
          section,
        ],
        if (invalid.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(
            'Invalid files (${invalid.length})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final item in invalid)
            _Problem(
              name: item.name,
              lines: [
                ?item.readError,
                for (final d in item.doc.errors) d.toString(),
              ],
              color: theme.colorScheme.error,
            ),
        ],
        if (warned.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(
            'Warnings (${warned.length})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final item in warned)
            _Problem(
              name: item.name,
              lines: [for (final d in item.doc.warnings) d.toString()],
              color: theme.colorScheme.outline,
            ),
        ],
        if (Platform.isAndroid) ...[
          const SizedBox(height: 32),
          Text('Storage permission', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            widget.writes
                ? 'Full disk access is required to read and write the data '
                      'folder wherever it lives on the device.'
                : 'Full disk access is required to read the data folder '
                      'wherever it lives on the device.',
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _requestPermission,
            child: const Text('Grant full disk access'),
          ),
        ],
      ],
    );
  }
}

/// A file name with one line per problem, e.g. `invalid_value · line 2 · "26-02-30"`.
class _Problem extends StatelessWidget {
  const _Problem({
    required this.name,
    required this.lines,
    required this.color,
  });

  final String name;
  final List<String> lines;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name),
          for (final line in lines) Text(line, style: style),
        ],
      ),
    );
  }
}
