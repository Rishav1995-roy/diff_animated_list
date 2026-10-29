import 'package:flutter/material.dart';

import 'src/customize_page.dart';
import 'src/grid_page.dart';
import 'src/playground_page.dart';

void main() => runApp(const ExampleApp());

/// Example app for `diff_animated_list`.
class ExampleApp extends StatelessWidget {
  /// Creates the app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF4F46E5),
          brightness: b,
        );
    return MaterialApp(
      title: 'diff_animated_list',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const Home(),
    );
  }
}

/// Tabs: playground, grid, customization.
class Home extends StatelessWidget {
  /// Creates the home screen.
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('diff_animated_list'),
          bottom: const TabBar(tabs: [
            Tab(text: 'List'),
            Tab(text: 'Grid'),
            Tab(text: 'Customize'),
          ]),
        ),
        body: const TabBarView(
          children: [PlaygroundPage(), GridPage(), CustomizePage()],
        ),
      ),
    );
  }
}
