import 'dart:async';

import 'package:dsl/dsl.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../edit_repository.dart';
import '../editor/editor_session.dart';
import '../editor/item_editor.dart';

/// Opens [name] in the editor, starting from its text on disk.
Future<void> openEditor(
  BuildContext context,
  EditRepository repository,
  String name,
) async {
  final ItemFile item;
  try {
    item = await repository.readFresh(name);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $name: $e')));
    }
    return;
  }
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => EditScreen(repository: repository, item: item),
    ),
  );
}

/// One existing item's text. Saved with the check button, or by going back;
/// the hold-to-cancel button throws the changes away. A save never
/// overwrites a file that changed on disk since it was opened without asking.
class EditScreen extends StatefulWidget {
  const EditScreen({super.key, required this.repository, required this.item});

  final EditRepository repository;

  /// The item as read when the screen opened.
  final ItemFile item;

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late ItemFile _base = widget.item;
  late final _session = EditorSession(widget.repository, text: _base.text);
  bool _saving = false;

  static const _cancelHoldDuration = Duration(milliseconds: 300);
  Timer? _cancelHoldTimer;

  bool get _dirty => _session.controller.text != _base.text;

  @override
  void dispose() {
    _cancelHoldTimer?.cancel();
    _session.dispose();
    super.dispose();
  }

  void _startCancelHold() {
    _cancelHoldTimer?.cancel();
    _cancelHoldTimer = Timer(_cancelHoldDuration, () {
      _cancelHoldTimer = null;
      if (!mounted || _saving) return;
      unawaited(_session.discardUnused(all: true));
      Navigator.pop(context);
    });
  }

  void _cancelCancelHold() {
    _cancelHoldTimer?.cancel();
    _cancelHoldTimer = null;
  }

  /// Saves and leaves the screen, unless the save was refused or the user
  /// chose to stay.
  Future<void> _saveAndClose() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (await _save() && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Whether the text is on disk now.
  Future<bool> _save() async {
    final text = _session.controller.text;
    if (!_dirty) {
      await _session.discardUnused();
      return true;
    }
    final saved = await widget.repository.save(_base, text);
    if (saved != null) {
      _base = saved;
      await _session.discardUnused();
      return true;
    }
    if (!mounted) return false;
    switch (await _askConflict()) {
      case _Conflict.overwrite:
        _base = await widget.repository.overwrite(_base.name, text);
        await _session.discardUnused();
        return true;
      case _Conflict.reload:
        final fresh = await widget.repository.readFresh(_base.name);
        setState(() {
          _base = fresh;
          _session.controller.text = fresh.text;
        });
        return false;
      case _Conflict.stay || null:
        return false;
    }
  }

  Future<_Conflict?> _askConflict() => showDialog<_Conflict>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Changed elsewhere'),
      content: Text(
        '${_base.name} changed or was deleted on disk since you opened it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, _Conflict.stay),
          child: const Text('Keep editing'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, _Conflict.reload),
          child: const Text('Load theirs'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, _Conflict.overwrite),
          child: const Text('Overwrite'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Going back saves first; leaving is done by [_saveAndClose].
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_base.name)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ItemEditor(
              session: _session,
              autofocus: true,
              mediaStem: p.basenameWithoutExtension(_base.name),
              actions: [
                Listener(
                  onPointerDown: (_) => _startCancelHold(),
                  onPointerUp: (_) => _cancelCancelHold(),
                  onPointerCancel: (_) => _cancelCancelHold(),
                  child: IconButton.outlined(
                    onPressed: _saving ? null : () {},
                    tooltip: 'Hold to discard changes',
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _saving ? null : _saveAndClose,
                  tooltip: 'Save',
                  icon: const Icon(Icons.check),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Conflict { stay, reload, overwrite }
