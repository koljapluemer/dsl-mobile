import 'package:dsl/dsl.dart';
import 'package:flutter/material.dart';

import 'repository/calendar_repository.dart';
import 'screens/home_shell.dart';

void main() {
  final repository = CalendarRepository();
  runApp(
    DslApp(
      title: 'Calendar',
      repository: repository,
      writes: false,
      home: (_) => HomeShell(repository: repository),
    ),
  );
}
