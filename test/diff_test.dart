import 'dart:math';

import 'package:diff_animated_list/diff_animated_list.dart';
import 'package:flutter_test/flutter_test.dart';

int lcs(List<int> a, List<int> b) {
  final t = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      t[i][j] = a[i - 1] == b[j - 1]
          ? t[i - 1][j - 1] + 1
          : max(t[i - 1][j], t[i][j - 1]);
    }
  }
  return t[a.length][b.length];
}

void checkConsistency(DiffResult r, List<int> a, List<int> b) {
  for (var j = 0; j < b.length; j++) {
    final o = r.newToOld[j];
    if (o >= 0) {
      expect(a[o], b[j]);
      expect(r.oldToNew[o], j);
    }
  }
  final applied = List<int>.of(a);
  applyDiffOperations(applied, r.operations, b);
  expect(applied, b, reason: 'ops ${r.operations} from $a to $b');
}

void main() {
  group('diffKeys', () {
    test('identical lists give an empty diff', () {
      final r = diffKeys([1, 2, 3], [1, 2, 3]);
      expect(r.isEmpty, isTrue);
      expect(r.operations, isEmpty);
    });

    test('insert, remove, move counts', () {
      final r = diffKeys(['a', 'b', 'c', 'd'], ['b', 'c', 'd', 'a', 'x']);
      expect(r.insertCount, 1);
      expect(r.removeCount, 0);
      expect(r.moveCount, 1);
    });

    test('detectMoves false reports remove + insert', () {
      final r = diffKeys([1, 2, 3], [2, 3, 1], detectMoves: false);
      expect(r.moveCount, 0);
      expect(r.insertCount, 1);
      expect(r.removeCount, 1);
    });

    test('empty old and empty new', () {
      expect(diffKeys(<int>[], [1, 2]).insertCount, 2);
      expect(diffKeys([1, 2], <int>[]).removeCount, 2);
      expect(diffKeys(<int>[], <int>[]).isEmpty, isTrue);
    });

    test('duplicate keys match first come first served', () {
      final a = [1, 1, 2];
      final b = [2, 1, 1, 1];
      final r = diffKeys(a, b);
      checkConsistency(r, a, b);
    });

    test('exceeding maxEditDistance still yields a correct result', () {
      final a = List.generate(50, (i) => i);
      final b = a.reversed.toList();
      final r = diffKeys(a, b, maxEditDistance: 3);
      checkConsistency(r, a, b);
      expect(r.moveCount, greaterThan(0));
    });

    test('Myers finds the minimal edit script (vs DP LCS)', () {
      final rnd = Random(7);
      for (var i = 0; i < 300; i++) {
        final a = List.generate(rnd.nextInt(14), (_) => rnd.nextInt(6));
        final b = List.generate(rnd.nextInt(14), (_) => rnd.nextInt(6));
        final r = diffKeys(a, b, detectMoves: false);
        final kept = r.newToOld.where((o) => o >= 0).length;
        expect(kept, lcs(a, b), reason: '$a -> $b');
      }
    });

    test('fuzz: applying the operations always yields the target', () {
      final rnd = Random(42);
      for (var i = 0; i < 2000; i++) {
        final a = List.generate(rnd.nextInt(30), (_) => rnd.nextInt(40));
        final b = List.generate(rnd.nextInt(30), (_) => rnd.nextInt(40));
        for (final moves in [true, false]) {
          final r = diffKeys(a, b, detectMoves: moves);
          checkConsistency(r, a, b);
        }
      }
    });

    test('fuzz: unique keys, shuffles, inserts and removals', () {
      final rnd = Random(99);
      for (var i = 0; i < 1000; i++) {
        final pool = List.generate(60, (k) => k)..shuffle(rnd);
        final a = pool.take(rnd.nextInt(40)).toList();
        final b = List<int>.of(pool.skip(rnd.nextInt(20)).take(rnd.nextInt(40)))
          ..shuffle(rnd);
        final r = diffKeys(a, b);
        checkConsistency(r, a, b);
        // With unique keys every shared key is matched (kept or moved).
        final shared = a.toSet().intersection(b.toSet()).length;
        expect(r.newToOld.where((o) => o >= 0).length, shared);
      }
    });

    test('a single move is reported as one move', () {
      final a = List.generate(100, (i) => i);
      final b = List.of(a)..insert(90, b0(a));
      b.removeAt(0);
      final r = diffKeys(a, b);
      expect(r.moveCount, 1);
      expect(r.operations.length, 1);
    });
  });

  group('diffLists', () {
    test('itemKey and areContentsTheSame report changes', () {
      final a = [(1, 'a'), (2, 'b')];
      final b = [(1, 'a'), (2, 'B')];
      final r = diffLists<(int, String)>(a, b,
          itemKey: (e) => e.$1, areContentsTheSame: (x, y) => x == y);
      expect(r.changeCount, 1);
      expect(r.changed, [false, true]);
      expect(
          r.operations.last, const DiffOperation(DiffOperationType.change, 1));
    });

    test('areItemsTheSame callback mode with moves', () {
      final a = [1, 2, 3, 4];
      final b = [4, 1, 2, 3];
      final r = diffLists<int>(a, b, areItemsTheSame: (x, y) => x == y);
      expect(r.moveCount, 1);
      checkConsistency(r, a, b);
    });

    test('fuzz callback mode', () {
      final rnd = Random(5);
      for (var i = 0; i < 500; i++) {
        final a = List.generate(rnd.nextInt(20), (_) => rnd.nextInt(25));
        final b = List.generate(rnd.nextInt(20), (_) => rnd.nextInt(25));
        final r = diffLists<int>(a, b, areItemsTheSame: (x, y) => x == y);
        checkConsistency(r, a, b);
      }
    });
  });

  test('diffKeysAsync matches diffKeys', () async {
    final a = List.generate(500, (i) => i);
    final b = List.of(a)..shuffle(Random(1));
    final sync = diffKeys(a, b);
    final async = await diffKeysAsync(a, b);
    expect(async.newToOld, sync.newToOld);
    expect(async.moved, sync.moved);
  });

  test('performance: 20k items with a few edits diffs fast', () {
    final a = List.generate(20000, (i) => i);
    final b = List.of(a)
      ..removeRange(100, 130)
      ..insertAll(9000, [-1, -2, -3])
      ..add(-4);
    final sw = Stopwatch()..start();
    final r = diffKeys(a, b);
    sw.stop();
    expect(r.removeCount, 30);
    expect(r.insertCount, 4);
    expect(sw.elapsedMilliseconds, lessThan(500));
  });

  test('reorderListItem follows ReorderableListView semantics', () {
    final l = [1, 2, 3, 4];
    reorderListItem(l, 0, 3);
    expect(l, [2, 3, 1, 4]);
    reorderListItem(l, 3, 0);
    expect(l, [4, 2, 3, 1]);
  });
}

int b0(List<int> a) => a[0];
