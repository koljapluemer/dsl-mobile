import 'package:dsl/dsl.dart';
import 'package:flutter/widgets.dart';

import '../edit_repository.dart';
import 'dsl_text_controller.dart';

/// One editing of one item's text: the controller, and the attachments
/// imported into `images/` along the way, so the ones that end up unused can
/// be deleted again.
class EditorSession {
  EditorSession(this.repository, {String text = ''})
    : controller = DslTextController(schema: repository.schema, text: text);

  final EditRepository repository;
  final DslTextController controller;
  final List<String> _imported = [];

  Schema get schema => repository.schema;

  /// Replaces the text and moves the cursor, as one undoable change.
  void apply(TextEdit edit) {
    controller.value = TextEditingValue(
      text: edit.text,
      selection: TextSelection.collapsed(offset: edit.cursor),
    );
  }

  void noteImported(String relativePath) => _imported.add(relativePath);

  /// Deletes the imported attachments the text no longer refers to; with
  /// [all], every one (the edit is being thrown away).
  Future<void> discardUnused({bool all = false}) async {
    final kept = all ? null : controller.document.clause('media');
    final keptPath = switch (kept) {
      Clause(args: [PathValue(:final text)]) => text,
      _ => null,
    };
    for (final path in _imported) {
      if (path != keptPath) await repository.discardMedia(path);
    }
    _imported.clear();
  }

  void dispose() => controller.dispose();
}
