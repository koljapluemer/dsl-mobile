import 'package:dsl/dsl.dart';
import 'package:flutter/material.dart';

import 'edit_repository.dart';
import 'screens/home_shell.dart';

void main() {
  initMediaPlayback();
  final repository = EditRepository();
  runApp(
    DslApp(
      title: 'Items',
      repository: repository,
      writes: true,
      // Counts taps anywhere in the app, so a pending delete's undo window
      // closes after a couple of interactions elsewhere.
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => repository.registerInteraction(),
        child: child,
      ),
      home: (_) => HomeShell(repository: repository),
    ),
  );
}
