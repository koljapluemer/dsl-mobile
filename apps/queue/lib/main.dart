import 'package:dsl/dsl.dart';
import 'package:flutter/material.dart';

import 'queue_screen.dart';

void main() {
  initMediaPlayback();
  final repository = FolderRepository(cached: true);
  runApp(
    DslApp(
      title: 'queue',
      repository: repository,
      writes: false,
      home: (_) => QueueScreen(repository: repository),
    ),
  );
}
