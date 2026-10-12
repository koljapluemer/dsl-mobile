import 'dart:async';

import 'package:flutter/material.dart';

import 'edit_repository.dart';

/// A small "Item deleted" toast pinned to the top-right of the screen, with
/// an Undo action and a close button. Auto-dismisses after 15 seconds, or
/// sooner if [repository] finalizes the pending delete first (two app-wide
/// interactions elsewhere — see [EditRepository.registerInteraction]).
class DeleteItemNotification {
  DeleteItemNotification({
    required BuildContext context,
    required this.repository,
    required this.pendingId,
  }) {
    _entry = OverlayEntry(builder: _build);
    Overlay.of(context).insert(_entry);
    _timer = Timer(const Duration(seconds: 15), _dismiss);
    repository.addListener(_onRepositoryChanged);
  }

  final EditRepository repository;
  final int pendingId;

  late final OverlayEntry _entry;
  Timer? _timer;
  bool _removed = false;

  void _onRepositoryChanged() {
    if (!repository.isPendingActive(pendingId)) _dismiss();
  }

  void _undo() {
    repository.cancelPending(pendingId);
    _dismiss();
  }

  void _dismiss() {
    if (_removed) return;
    _removed = true;
    _timer?.cancel();
    repository.removeListener(_onRepositoryChanged);
    _entry.remove();
  }

  Widget _build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 12,
      child: Material(
        color: colors.inverseSurface,
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Item deleted',
                  style: TextStyle(color: colors.onInverseSurface),
                ),
                TextButton(
                  onPressed: _undo,
                  child: Text(
                    'Undo',
                    style: TextStyle(color: colors.inversePrimary),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.onInverseSurface),
                  tooltip: 'Dismiss',
                  onPressed: _dismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
