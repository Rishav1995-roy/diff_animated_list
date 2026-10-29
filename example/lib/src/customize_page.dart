import 'package:diff_animated_list/diff_animated_list.dart';
import 'package:flutter/material.dart';

import 'task.dart';

/// Pick transitions, timings, staggering and a change animation live.
class CustomizePage extends StatefulWidget {
  /// Creates the page.
  const CustomizePage({super.key});

  @override
  State<CustomizePage> createState() => _CustomizePageState();
}

class _CustomizePageState extends State<CustomizePage> {
  List<Task> _items = [for (var i = 0; i < 5; i++) makeTask(i)];
  int _next = 5;
  int _renames = 0;
  String _transition = 'Size + fade';
  double _ms = 300;
  bool _stagger = false;
  bool _crossFade = true;

  static final _transitions = <String, DiffTransitionBuilder>{
    'Size + fade': DiffTransitions.sizeAndFade,
    'Fade': DiffTransitions.fade,
    'Scale': DiffTransitions.scaleAndFade,
    'Slide': DiffTransitions.slideAndFade,
    'Custom (flip)': (context, child, a) => AnimatedBuilder(
          animation: a,
          child: child,
          builder: (context, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX((1 - a.value) * 1.4),
            child: SizeTransition(sizeFactor: a, child: child),
          ),
        ),
  };

  @override
  Widget build(BuildContext context) {
    final t = _transitions[_transition]!;
    final d = Duration(milliseconds: _ms.round());
    final config = DiffAnimationConfig(
      insertTransition: t,
      removeTransition: t,
      insertDuration: d,
      removeDuration: d,
      moveDuration: d * 1.2,
      stagger: _stagger ? const Duration(milliseconds: 80) : Duration.zero,
      changeTransition: _crossFade
          ? DiffChangeTransitions.crossFade
          : DiffChangeTransitions.none,
    );
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, children: [
            for (final name in _transitions.keys)
              ChoiceChip(
                label: Text(name),
                selected: name == _transition,
                onSelected: (_) => setState(() => _transition = name),
              ),
          ]),
          Row(children: [
            const Text('Duration'),
            Expanded(
              child: Slider(
                min: 0,
                max: 1000,
                divisions: 20,
                label: '${_ms.round()} ms',
                value: _ms,
                onChanged: (v) => setState(() => _ms = v),
              ),
            ),
          ]),
          Wrap(spacing: 12, children: [
            FilterChip(
                label: const Text('Stagger'),
                selected: _stagger,
                onSelected: (v) => setState(() => _stagger = v)),
            FilterChip(
                label: const Text('Cross-fade changes'),
                selected: _crossFade,
                onSelected: (v) => setState(() => _crossFade = v)),
          ]),
          Wrap(spacing: 8, children: [
            FilledButton.tonal(
                onPressed: () => setState(() => _items = [
                      for (var i = 0; i < 4; i++) makeTask(_next++),
                      ..._items,
                    ]),
                child: const Text('Add 4 on top')),
            FilledButton.tonal(
                onPressed: () => setState(() => _items = []),
                child: const Text('Clear')),
            FilledButton.tonal(
                onPressed: _items.isEmpty
                    ? null
                    : () => setState(() {
                          _renames++;
                          _items = [
                            _items.first.rename('Renamed #$_renames'),
                            ..._items.skip(1),
                          ];
                        }),
                child: const Text('Rename first')),
          ]),
        ]),
      ),
      Expanded(
        child: DiffAnimatedList<Task>(
          items: _items,
          itemKey: (t) => t.id,
          animation: config,
          itemBuilder: (context, task, i) => TaskCard(task: task),
        ),
      ),
    ]);
  }
}
