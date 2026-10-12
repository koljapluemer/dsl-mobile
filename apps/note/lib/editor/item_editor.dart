import 'dart:io';
import 'dart:typed_data';

import 'package:dsl/dsl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;

import 'editor_session.dart';

/// The item's whole text in one highlighted field, its errors and warnings
/// beneath (tap one to jump to it), and a toolbar of quick edits: set the
/// date, attach media, start the extra block. [actions] go at the toolbar's
/// end.
class ItemEditor extends StatefulWidget {
  const ItemEditor({
    super.key,
    required this.session,
    required this.actions,
    this.autofocus = false,
    this.mediaStem,
  });

  final EditorSession session;
  final List<Widget> actions;
  final bool autofocus;

  /// Prefix for attachment file names; by default the slug of the first line.
  final String? mediaStem;

  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  final _focus = FocusNode();
  bool _busy = false;

  EditorSession get _session => widget.session;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _apply(TextEdit? edit) {
    if (edit == null) return;
    _session.apply(edit);
    _focus.requestFocus();
  }

  String get _text => _session.controller.text;

  void _setDate(DateOnly date) => _apply(
    setClause(
      _session.schema,
      _text,
      'appointment',
      'appointment ${formatDate(date)}',
    ),
  );

  Future<void> _pickDate() async {
    final current = switch (_session.controller.document.clause(
      'appointment',
    )) {
      Clause(args: [DateValue(:final date)]) => date.toDateTime(),
      _ => DateTime.now(),
    };
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2099, 12, 31),
    );
    if (picked != null) _setDate(DateOnly.fromDateTime(picked));
  }

  String? get _mediaPath =>
      switch (_session.controller.document.clause('media')) {
        Clause(args: [PathValue(:final text)]) => text,
        _ => null,
      };

  String? get _absoluteMediaPath {
    final path = _mediaPath;
    final folder = _session.repository.folderPath;
    if (path == null || folder == null || !isMediaFilename(path)) return null;
    return p.joinAll([folder, ...path.split('/')]);
  }

  Future<void> _media() async {
    final absolute = _absoluteMediaPath;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (absolute != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: MediaPreview(path: absolute),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_full),
                title: const Text('View'),
                onTap: () => Navigator.pop(sheetContext, 'view'),
              ),
            ],
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(absolute == null ? 'Choose file' : 'Replace'),
              onTap: () => Navigator.pop(sheetContext, 'pick'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('Paste image'),
              onTap: () => Navigator.pop(sheetContext, 'paste'),
            ),
            if (_mediaPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'view':
        await showMediaViewer(
          context,
          File(absolute!),
          isVideo: isVideoFilename(absolute),
        );
      case 'pick':
        await _pickMedia();
      case 'paste':
        await _pasteImage();
      case 'remove':
        _apply(removeClause(_session.schema, _text, 'media'));
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        for (final ext in supportedMediaExtensions) ext.substring(1),
      ],
    );
    final path = result?.files.single.path;
    if (!mounted || path == null) return;
    if (!isMediaFilename(path)) return _toast('Unsupported media type');
    final isVideo = isVideoFilename(path);
    final length = await File(path).length();
    if (length > (isVideo ? maxVideoBytes : maxImageBytes)) {
      return _toast(isVideo ? 'Video is too large' : 'Image is too large');
    }
    await _attach(File(path));
  }

  /// Takes a bitmap (PNG bytes) off the clipboard. No platform clipboard
  /// carries videos.
  Future<void> _pasteImage() async {
    Uint8List? bytes;
    try {
      bytes = await Pasteboard.image;
    } catch (_) {
      bytes = null;
    }
    if (!mounted) return;
    if (bytes == null) return _toast('No image on the clipboard');
    if (bytes.length > maxImageBytes) return _toast('Image is too large');
    final dir = await Directory.systemTemp.createTemp('dsl_paste');
    final file = File(p.join(dir.path, 'clipboard.png'));
    await file.writeAsBytes(bytes, flush: true);
    await _attach(file);
    await dir.delete(recursive: true);
  }

  /// Copies [source] into the folder's `images/` and points the `media` line
  /// at it.
  Future<void> _attach(File source) async {
    setState(() => _busy = true);
    try {
      final repo = _session.repository;
      final stem = widget.mediaStem ?? repo.mediaStem(_text);
      final relative = await repo.importMedia(source, stem);
      _session.noteImported(relative);
      if (!mounted) return;
      _apply(
        setClause(
          _session.schema,
          _text,
          'media',
          'media ${formatPath(relative)}',
        ),
      );
    } catch (e) {
      if (mounted) _toast('Could not attach: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _jumpTo(Diagnostic d) {
    _session.controller.selection = TextSelection(
      baseOffset: d.from!,
      extentOffset: d.to!,
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _session.controller,
      builder: (context, _) {
        final doc = _session.controller.document;
        final problems = _text.trim().isEmpty
            ? const <Diagnostic>[]
            : doc.diagnostics.where((d) => d.from != null).toList();
        final hasDate = doc.clause('appointment') != null;
        final media = _absoluteMediaPath;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _session.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'First line, then more text or keyword lines…',
                  border: InputBorder.none,
                ),
              ),
            ),
            if (problems.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 96),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final d in problems)
                      InkWell(
                        onTap: () => _jumpTo(d),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            d.toString(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: d.code.isError
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Date',
                  enabled: !_busy,
                  onSelected: (choice) => switch (choice) {
                    'today' => _setDate(DateOnly.today()),
                    'pick' => _pickDate(),
                    _ => _apply(
                      removeClause(_session.schema, _text, 'appointment'),
                    ),
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'today', child: Text('Today')),
                    const PopupMenuItem(
                      value: 'pick',
                      child: Text('Pick date…'),
                    ),
                    if (hasDate)
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove date'),
                      ),
                  ],
                  child: IgnorePointer(
                    child: _ToolButton(
                      icon: hasDate ? Icons.event : Icons.event_outlined,
                      selected: hasDate,
                      onPressed: _busy ? null : () {},
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ToolButton(
                  icon: Icons.perm_media_outlined,
                  selected: media != null,
                  tooltip: 'Media',
                  onPressed: _busy ? null : _media,
                  thumbnail: media == null || isVideoFilename(media)
                      ? null
                      : File(media),
                ),
                const SizedBox(width: 8),
                _ToolButton(
                  icon: doc.extraMarker == null
                      ? Icons.notes_outlined
                      : Icons.notes,
                  selected: doc.extraMarker != null,
                  tooltip: 'Extra',
                  onPressed: _busy
                      ? null
                      : () => _apply(ensureExtra(_session.schema, _text)),
                ),
                const Spacer(),
                ...widget.actions,
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.tooltip,
    this.thumbnail,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// An image shown instead of [icon].
  final File? thumbnail;

  @override
  Widget build(BuildContext context) {
    final image = thumbnail;
    return IconButton.outlined(
      onPressed: onPressed,
      tooltip: tooltip,
      isSelected: selected,
      icon: image == null
          ? Icon(icon)
          : SizedBox.square(
              dimension: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  image,
                  fit: BoxFit.cover,
                  cacheWidth: 96,
                  errorBuilder: (_, _, _) => Icon(icon),
                ),
              ),
            ),
      style: IconButton.styleFrom(padding: const EdgeInsets.all(16)),
    );
  }
}
