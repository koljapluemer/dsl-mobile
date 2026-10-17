import 'package:dsl/dsl.dart';
import 'package:flutter/material.dart';

import 'zero_repository.dart';
import 'zero_screen.dart';

void main() {
  initMediaPlayback();
  final repository = ZeroRepository();
  runApp(
    DslApp(
      title: 'zero',
      repository: repository,
      writes: false,
      home: (_) => ZeroScreen(repository: repository),
    ),
  );
}
