import 'package:dsl/dsl.dart';
import 'package:flutter/material.dart';

import '../edit_repository.dart';
import 'add_screen.dart';
import 'list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repository});

  final EditRepository repository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      AddScreen(repository: widget.repository),
      ListScreen(repository: widget.repository),
      SettingsScreen(repository: widget.repository, writes: true),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.add), label: 'Add'),
                NavigationDestination(icon: Icon(Icons.list), label: 'List'),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
            Expanded(
              child: IndexedStack(index: _index, children: pages),
            ),
          ],
        ),
      ),
    );
  }
}
