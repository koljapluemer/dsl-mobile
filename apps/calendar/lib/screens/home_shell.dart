import 'package:dsl/dsl.dart';
import 'package:flutter/material.dart';

import '../repository/calendar_repository.dart';
import 'day_screen.dart';
import 'range_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repository});

  final CalendarRepository repository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DayScreen(repository: widget.repository),
      RangeScreen(repository: widget.repository),
      SettingsScreen(repository: widget.repository, writes: false),
    ];
    return Scaffold(
      // Day and Range show the items; Settings has its own Reload button.
      floatingActionButton: _index < 2
          ? RefreshFab(repository: widget.repository)
          : null,
      body: SafeArea(
        child: Column(
          children: [
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.today), label: 'Day'),
                NavigationDestination(
                  icon: Icon(Icons.date_range),
                  label: 'Range',
                ),
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
