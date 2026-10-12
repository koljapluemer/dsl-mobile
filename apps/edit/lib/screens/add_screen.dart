import 'dart:async';

import 'package:flutter/material.dart';

import '../edit_repository.dart';
import '../editor/editor_session.dart';
import '../editor/item_editor.dart';

/// The start screen: an empty editor; "Add" writes it as a new item file.
class AddScreen extends StatefulWidget {
  const AddScreen({super.key, required this.repository});

  final EditRepository repository;

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  late EditorSession _session = EditorSession(widget.repository);
  bool _saving = false;

  /// The clear button must be held this long, so a stray tap can't wipe the
  /// text.
  static const _clearHoldDuration = Duration(milliseconds: 300);
  Timer? _clearHoldTimer;

  @override
  void dispose() {
    _clearHoldTimer?.cancel();
    _session.dispose();
    super.dispose();
  }

  void _startClearHold() {
    _clearHoldTimer?.cancel();
    _clearHoldTimer = Timer(_clearHoldDuration, () {
      _clearHoldTimer = null;
      if (mounted && !_saving) _reset(discardAll: true);
    });
  }

  void _cancelClearHold() {
    _clearHoldTimer?.cancel();
    _clearHoldTimer = null;
  }

  /// Starts over with an empty editor; the old session's unused attachments
  /// are deleted.
  void _reset({required bool discardAll}) {
    final old = _session;
    unawaited(old.discardUnused(all: discardAll));
    setState(() => _session = EditorSession(widget.repository));
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _add() async {
    final text = _session.controller.text;
    if (text.trim().isEmpty) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final item = await widget.repository.create(text);
      if (!mounted) return;
      _reset(discardAll: false);
      final errors = item.doc.errors.length;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            errors == 0
                ? 'Added ${item.name}'
                : 'Added ${item.name} with $errors '
                      '${errors == 1 ? 'error' : 'errors'}',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not add: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: ItemEditor(
        key: ObjectKey(_session),
        session: _session,
        actions: [
          Listener(
            onPointerDown: (_) => _startClearHold(),
            onPointerUp: (_) => _cancelClearHold(),
            onPointerCancel: (_) => _cancelClearHold(),
            child: IconButton.outlined(
              // The hold timer does the work; this keeps the button
              // enabled-looking and gives tap feedback.
              onPressed: _saving ? null : () {},
              tooltip: 'Hold to clear',
              icon: const Icon(Icons.backspace_outlined),
              style: IconButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
          ),
          const SizedBox(width: 8),
          ListenableBuilder(
            listenable: _session.controller,
            builder: (context, _) => IconButton.filled(
              onPressed: _saving || _session.controller.text.trim().isEmpty
                  ? null
                  : _add,
              tooltip: 'Add',
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
          ),
        ],
      ),
    );
  }
}
