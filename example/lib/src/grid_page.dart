import 'dart:math';

import 'package:diff_animated_list/diff_animated_list.dart';
import 'package:flutter/material.dart';

import 'task.dart';

/// The same idea on a grid.
class GridPage extends StatefulWidget {
  /// Creates the page.
  const GridPage({super.key});

  @override
  State<GridPage> createState() => _GridPageState();
}

class _GridPageState extends State<GridPage> {
  final _rnd = Random(9);
  List<Task> _items = [for (var i = 0; i < 11; i++) makeTask(i)];
  int _next = 11;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(spacing: 8, children: [
          FilledButton.tonal(
              onPressed: () =>
                  setState(() => _items = List.of(_items)..shuffle(_rnd)),
              child: const Text('Shuffle')),
          FilledButton.tonal(
              onPressed: () => setState(() => _items = List.of(_items)
                ..insert(_rnd.nextInt(_items.length + 1), makeTask(_next++))),
              child: const Text('Add')),
          FilledButton.tonal(
              onPressed: () => setState(() {
                    if (_items.isNotEmpty) {
                      _items = List.of(_items)
                        ..removeAt(_rnd.nextInt(_items.length));
                      }
                  }),
              child: const Text('Remove')),
        ]),
      ),
      Expanded(
        child: DiffAnimatedGrid<Task>(
          items: _items,
          itemKey: (t) => t.id,
          padding: const EdgeInsets.all(12),
          header: const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Header scrolls with the grid'),
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, t, i) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.color, t.color.withValues(alpha: 0.6)],
              ),
            ),
            child: Center(
              child: Text('${t.id}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    ]);
  }
}
