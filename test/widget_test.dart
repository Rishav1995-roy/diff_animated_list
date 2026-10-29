import 'dart:math';

import 'package:diff_animated_list/diff_animated_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 600, child: child)),
    );

Widget tile(BuildContext c, int i, int index) => SizedBox(
      key: ValueKey('tile$i'),
      height: 50,
      child: Text('item $i'),
    );

Widget list(List<int> items,
        {DiffAnimationConfig? anim,
        DiffAnimatedListController? controller,
        DiffItemBuilder<int>? builder,
        DiffItemBuilder<int>? removed,
        int? threshold = 1000}) =>
    host(DiffAnimatedList<int>(
      items: items,
      itemKey: (i) => i,
      animation: anim,
      controller: controller,
      isolateThreshold: threshold,
      removedItemBuilder: removed,
      itemBuilder: builder ?? tile,
    ));

List<int> shown(WidgetTester t) => [
      for (final w in t.widgetList<SizedBox>(find.byWidgetPredicate(
          (w) => w is SizedBox && w.key is ValueKey<String>)))
        int.parse((w.key! as ValueKey<String>).value.substring(4)),
    ];

double top(WidgetTester t, int i) =>
    t.getTopLeft(find.byKey(ValueKey('tile$i'))).dy;

void main() {
  testWidgets('initial items render without animation', (t) async {
    await t.pumpWidget(list([1, 2, 3]));
    expect(find.text('item 2'), findsOneWidget);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('insert animates in and settles', (t) async {
    await t.pumpWidget(list([1, 2]));
    await t.pumpWidget(list([1, 5, 2]));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('item 5'), findsOneWidget);
    expect(top(t, 2), lessThan(100)); // still making room
    await t.pumpAndSettle();
    expect(top(t, 2), 100);
    expect(top(t, 5), 50);
  });

  testWidgets('remove keeps a ghost that fades out, then disappears',
      (t) async {
    await t.pumpWidget(list([1, 2, 3]));
    await t.pumpWidget(list([1, 3]));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('item 2'), findsOneWidget);
    await t.pumpAndSettle();
    expect(find.text('item 2'), findsNothing);
    expect(top(t, 3), 50);
  });

  testWidgets('CORE 5: a move really animates its position', (t) async {
    await t.pumpWidget(list([1, 2, 3, 4]));
    expect(top(t, 4), 150);
    await t.pumpWidget(list([4, 1, 2, 3]));
    await t.pump(); // settle captures the jump
    await t.pump(const Duration(milliseconds: 100));
    final mid = top(t, 4);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(150), reason: 'item 4 is travelling, not teleported');
    await t.pumpAndSettle();
    expect(top(t, 4), 0);
    expect(top(t, 1), 50);
    expect(top(t, 3), 150);
  });

  testWidgets('shuffle ends in the right order with state intact', (t) async {
    final items = List.generate(10, (i) => i);
    await t.pumpWidget(list(items));
    final next = List.of(items)..shuffle(Random(3));
    await t.pumpWidget(list(next));
    await t.pumpAndSettle();
    for (var i = 0; i < next.length; i++) {
      expect(top(t, next[i]), i * 50.0);
    }
  });

  testWidgets('change transition runs only when contents changed', (t) async {
    Widget build(List<(int, String)> items) =>
        host(DiffAnimatedList<(int, String)>(
          items: items,
          itemKey: (e) => e.$1,
          animation: const DiffAnimationConfig(
              changeTransition: DiffChangeTransitions.crossFade),
          itemBuilder: (c, e, i) => SizedBox(height: 50, child: Text(e.$2)),
        ));
    await t.pumpWidget(build([(1, 'a'), (2, 'b')]));
    await t.pumpWidget(build([(1, 'a'), (2, 'B')]));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('b'), findsOneWidget); // old content fading out
    expect(find.text('B'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    await t.pumpAndSettle();
    expect(find.text('b'), findsNothing);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('stagger delays later inserts', (t) async {
    const cfg = DiffAnimationConfig(stagger: Duration(milliseconds: 100));
    await t.pumpWidget(list([], anim: cfg));
    await t.pumpWidget(list([1, 2, 3], anim: cfg));
    await t.pump(const Duration(milliseconds: 150));
    // Item 3 is delayed by 200 ms: it has no height yet, item 1 has.
    expect(t.getSize(find.byKey(const ValueKey('tile1'))).height, 50);
    final h1 = t.getRect(find.byKey(const ValueKey('tile1'))).height;
    expect(h1, 50);
    await t.pumpAndSettle();
    expect(top(t, 3), 100);
  });

  testWidgets('animateInitial plays for the first items', (t) async {
    await t.pumpWidget(
        list([1, 2], anim: const DiffAnimationConfig(animateInitial: true)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(t.hasRunningAnimations, isTrue);
    await t.pumpAndSettle();
    expect(top(t, 2), 50);
  });

  testWidgets('CORE 2: rapid successive updates never crash and end correct',
      (t) async {
    final rnd = Random(11);
    var items = List.generate(8, (i) => i);
    await t.pumpWidget(list(items));
    var next = 100;
    for (var step = 0; step < 300; step++) {
      items = List.of(items);
      switch (rnd.nextInt(5)) {
        case 0:
          items.insert(rnd.nextInt(items.length + 1), next++);
        case 1:
          if (items.isNotEmpty) items.removeAt(rnd.nextInt(items.length));
        case 2:
          items.shuffle(rnd);
        case 3:
          items = [];
        default:
          items = List.generate(rnd.nextInt(15), (_) => next++);
      }
      await t.pumpWidget(list(items));
      // Pump a random, often tiny, slice so updates land mid-animation.
      await t.pump(Duration(milliseconds: rnd.nextInt(120)));
    }
    expect(t.takeException(), isNull);
    await t.pumpAndSettle();
    expect(shown(t).toSet(), items.toSet());
    for (var i = 0; i < items.length; i++) {
      expect(top(t, items[i]), i * 50.0);
    }
  });

  testWidgets('update during exit of the same item re-adding it', (t) async {
    await t.pumpWidget(list([1, 2, 3]));
    await t.pumpWidget(list([1, 3]));
    await t.pump(const Duration(milliseconds: 60));
    await t.pumpWidget(list([1, 2, 3]));
    await t.pumpAndSettle();
    expect(shown(t), [1, 2, 3]);
  });

  testWidgets('same list instance mutated in place is still diffed', (t) async {
    final items = [1, 2, 3];
    await t.pumpWidget(list(items));
    items.removeAt(0);
    await t.pumpWidget(list(items));
    await t.pumpAndSettle();
    expect(shown(t), [2, 3]);
  });

  testWidgets('disposing mid animation does not throw', (t) async {
    await t.pumpWidget(list([1, 2, 3]));
    await t.pumpWidget(list([3, 2, 9]));
    await t.pump(const Duration(milliseconds: 40));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
  });

  testWidgets('CORE 3: Dismissible works (competitor issues #21 / #23)',
      (t) async {
    final controller = DiffAnimatedListController();
    var items = [1, 2, 3];
    late StateSetter set;
    await t.pumpWidget(host(StatefulBuilder(builder: (c, s) {
      set = s;
      return DiffAnimatedList<int>(
        items: items,
        itemKey: (i) => i,
        controller: controller,
        itemBuilder: (c, i, index) => Dismissible(
          key: ValueKey('d$i'),
          onDismissed: (_) {
            controller.skipNextAnimations();
            set(() => items = items.where((e) => e != i).toList());
          },
          child: SizedBox(
              key: ValueKey('tile$i'), height: 50, child: Text('item $i')),
        ),
      );
    })));
    await t.drag(find.text('item 2'), const Offset(500, 0));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('item 2'), findsNothing);
    expect(find.text('item 3'), findsOneWidget);
    expect(top(t, 3), 50);
  });

  testWidgets('skipNextAnimations applies instantly', (t) async {
    final c = DiffAnimatedListController();
    await t.pumpWidget(list([1, 2, 3], controller: c));
    c.skipNextAnimations();
    await t.pumpWidget(list([3, 1], controller: c));
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
    expect(shown(t), [3, 1]);
  });

  testWidgets('removedItemBuilder is used for exiting items', (t) async {
    await t.pumpWidget(list([1, 2],
        removed: (c, i, n) => SizedBox(
            key: ValueKey('tile$i'), height: 50, child: Text('bye $i'))));
    await t.pumpWidget(list([1],
        removed: (c, i, n) => SizedBox(
            key: ValueKey('tile$i'), height: 50, child: Text('bye $i'))));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('bye 2'), findsOneWidget);
    await t.pumpAndSettle();
  });

  testWidgets('CORE 4: large lists are diffed off the UI thread', (t) async {
    final a = List.generate(3000, (i) => i);
    await t.pumpWidget(list(a, threshold: 100));
    final b = List.of(a)..removeAt(0);
    await t.pumpWidget(list(b, threshold: 100));
    // The result arrives from an isolate: wait for real time.
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    await t.pumpAndSettle();
    expect(find.text('item 0'), findsNothing);
    expect(find.text('item 1'), findsOneWidget);
    expect(top(t, 1), 0);
  });

  testWidgets('async diff: a newer update wins over a pending one', (t) async {
    final a = List.generate(500, (i) => i);
    await t.pumpWidget(list(a, threshold: 100));
    await t.pumpWidget(list(a.sublist(10), threshold: 100));
    await t.pumpWidget(list(a.sublist(20), threshold: 100));
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    await t.pumpAndSettle();
    expect(find.text('item 20'), findsOneWidget);
    expect(find.text('item 10'), findsNothing);
  });

  testWidgets('header and footer scroll with the list', (t) async {
    await t.pumpWidget(host(DiffAnimatedList<int>(
      items: const [1, 2],
      itemKey: (i) => i,
      header: const SizedBox(height: 40, child: Text('H')),
      footer: const SizedBox(height: 40, child: Text('F')),
      padding: const EdgeInsets.all(8),
      itemBuilder: tile,
    )));
    expect(find.text('H'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
    expect(top(t, 1), 48);
  });

  testWidgets('sliver list works inside a CustomScrollView', (t) async {
    Widget build(List<int> items) => host(CustomScrollView(slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverDiffAnimatedList<int>(
              items: items, itemKey: (i) => i, itemBuilder: tile),
        ]));
    await t.pumpWidget(build([1, 2]));
    await t.pumpWidget(build([2, 1, 3]));
    await t.pumpAndSettle();
    expect(top(t, 2), 20);
    expect(top(t, 3), 120);
  });

  testWidgets('grid animates inserts, removals and moves', (t) async {
    Widget build(List<int> items) => host(DiffAnimatedGrid<int>(
          items: items,
          itemKey: (i) => i,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2),
          itemBuilder: (c, i, n) =>
              Container(key: ValueKey('g$i'), child: Text('g$i')),
        ));
    await t.pumpWidget(build([1, 2, 3, 4]));
    final before = t.getTopLeft(find.byKey(const ValueKey('g4')));
    await t.pumpWidget(build([4, 1, 2, 3, 5]));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    final mid = t.getTopLeft(find.byKey(const ValueKey('g4')));
    expect(mid, isNot(before));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.byKey(const ValueKey('g4'))), Offset.zero);
    await t.pumpWidget(build([1]));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('g4')), findsNothing);
  });

  testWidgets('theme supplies the configuration', (t) async {
    await t.pumpWidget(DiffAnimatedListTheme(
      data: DiffAnimationConfig.disabled,
      child: list([1, 2, 3]),
    ));
    await t.pumpWidget(DiffAnimatedListTheme(
      data: DiffAnimationConfig.disabled,
      child: list([3, 1]),
    ));
    await t.pump();
    await t.pump();
    expect(shown(t), [3, 1]);
    expect(top(t, 3), 0);
  });

  testWidgets('custom transitions and combine compile and run', (t) async {
    final cfg = DiffAnimationConfig(
      insertTransition: DiffTransitions.combine(
          [DiffTransitions.sizeAxis(Axis.vertical), DiffTransitions.fade]),
      removeTransition: DiffTransitions.slideFrom(const Offset(-1, 0)),
      moveBuilder: (c, child, a) => Material(elevation: 4, child: child),
    );
    await t.pumpWidget(list([1, 2], anim: cfg));
    await t.pumpWidget(list([2, 3], anim: cfg));
    await t.pumpAndSettle();
    expect(shown(t), [2, 3]);
  });
}
