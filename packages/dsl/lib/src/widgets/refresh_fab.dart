import 'package:flutter/material.dart';

import '../folder_repository.dart';

/// Rescans the data folder; spins while a scan runs.
class RefreshFab extends StatelessWidget {
  const RefreshFab({super.key, required this.repository});

  final FolderRepository repository;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) => FloatingActionButton(
        tooltip: 'Reload',
        // Re-entrant taps are ignored by the repository while a scan runs.
        onPressed: repository.loadFromDisk,
        child: repository.isLoading
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : const Icon(Icons.refresh),
      ),
    );
  }
}
