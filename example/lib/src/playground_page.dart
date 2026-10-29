import 'dart:math';

import 'package:diff_animated_list/diff_animated_list.dart';
import 'package:flutter/material.dart';

import 'task.dart';

/// Shuffle, sort, filter, add, remove and swipe-to-dismiss on one list.
class PlaygroundPage extends StatefulWidget {
  /// Creates the page.
  const PlaygroundPage({super.key});

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  final _controller = DiffAnimatedListController();
  final _rnd = Random(4);
  late List<Task> _all = [for (var i = 0; i < 8; i++) makeTask(i)];
  String? _filter;
  int _next = 8;

  List<Task> get _visible => [
        for (final t in _all)
          if (_filter == null || t.tag == _filter) t
      ];

  void _shuffle() => setState(() => _all = List.of(_all)..shuffle(_rnd));
  void _sort() => setState(
      () => _all = List.of(_all)..sort((a, b) => a.title.compareTo(b.title)));
  void _add() => setState(() {
        _all = List.of(_all)
          ..insert(_rnd.nextInt(_all.length + 1), makeTask(_next++));
      });
  void _removeFirst() {
    final v = _visible;
    if (v.isEmpty) return;
    setState(() => _all = _all.where((t) => t.id != v.first.id).toList());
  }

  void _remove(Task t) =>
      setState(() => _all = _all.where((e) => e.id != t.id).toList());

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
            for (final tag in tagColors.keys) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(tag),
                selected: _filter == tag,
                onSelected: (_) => setState(() => _filter = tag),
              ),
            ],
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(spacing: 8, children: [
          FilledButton.tonalIcon(
              key: const ValueKey('shuffle'),
              onPressed: _shuffle,
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle')),
          FilledButton.tonalIcon(
              key: const ValueKey('sort'),
              onPressed: _sort,
              icon: const Icon(Icons.sort_by_alpha),
              label: const Text('Sort')),
          FilledButton.tonalIcon(
              key: const ValueKey('add'),
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add')),
          FilledButton.tonalIcon(
              key: const ValueKey('remove'),
              onPressed: _removeFirst,
              icon: const Icon(Icons.remove),
              label: const Text('Remove')),
        ]),
      ),
      Expanded(
        child: DiffAnimatedList<Task>(
          items: _visible,
          itemKey: (t) => t.id,
          controller: _controller,
          animation: const DiffAnimationConfig(
            moveBuilder: _lift,
            stagger: Duration(milliseconds: 40),
          ),
          // Swipe to dismiss: the Dismissible already collapsed itself, so
          // tell the list not to animate the removal a second time.
          itemBuilder: (context, task, index) => Dismissible(
            key: ValueKey('dismiss${task.id}'),
            onDismissed: (_) {
              _controller.skipNextAnimations();
              _remove(task);
            },
            child: TaskCard(
              task: task,
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _remove(task),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

Widget _lift(BuildContext context, Widget child, Animation<double> a) =>
    AnimatedBuilder(
      animation: a,
      child: child,
      builder: (context, child) =>
          Transform.scale(scale: 1 + 0.03 * sin(pi * a.value), child: child),
    );
