import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../folder_repository.dart';
import 'settings_screen.dart';

/// The bootstrap every dsl-mobile app shares: asks for storage access on
/// Android, restores the folder (and cache), paints [home] right away and
/// scans the folder in the background. Without a folder it shows the
/// settings screen to pick one.
class DslApp extends StatefulWidget {
  const DslApp({
    super.key,
    required this.title,
    required this.repository,
    required this.writes,
    required this.home,
    this.builder,
  });

  final String title;
  final FolderRepository repository;

  /// Whether the app writes to the folder (see [SettingsScreen.writes]).
  final bool writes;
  final WidgetBuilder home;

  /// Passed on to [MaterialApp.builder].
  final TransitionBuilder? builder;

  @override
  State<DslApp> createState() => _DslAppState();
}

class _DslAppState extends State<DslApp> {
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepositoryChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    widget.repository.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() => setState(() {});

  Future<void> _bootstrap() async {
    if (Platform.isAndroid) {
      // Full disk access, so the data folder can live anywhere on device.
      await Permission.manageExternalStorage.request();
    }
    await widget.repository.init();
    if (!mounted) return;
    // Started before the first build so a refresh button is already
    // spinning; screens fill in (or update their cached items) when it lands.
    unawaited(widget.repository.loadFromDisk());
    setState(() => _bootstrapped = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: widget.title,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      builder: widget.builder,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_bootstrapped) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (widget.repository.folderPath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose a data folder')),
        body: SettingsScreen(
          repository: widget.repository,
          writes: widget.writes,
        ),
      );
    }
    return Builder(builder: widget.home);
  }
}
