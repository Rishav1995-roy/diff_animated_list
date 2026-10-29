import 'diff_operation.dart';

/// The outcome of comparing an old list with a new list.
///
/// A result only contains indices, never items, so it is cheap to build in a
/// background isolate and send back.
class DiffResult {
  /// Creates a result. Normally obtained from `diffKeys` or `diffLists`.
  DiffResult({
    required this.newToOld,
    required this.oldToNew,
    required this.moved,
    required this.changed,
  });

  /// For every index of the **new** list, the index of the same item in the
  /// old list, or `-1` if the item was inserted.
  final List<int> newToOld;

  /// For every index of the **old** list, the index of the same item in the
  /// new list, or `-1` if the item was removed.
  final List<int> oldToNew;

  /// For every index of the new list, `true` if the item was detected as moved
  /// (it is not part of the longest common subsequence).
  final List<bool> moved;

  /// For every index of the new list, `true` if the item exists in both lists
  /// but its content changed (`areContentsTheSame` returned `false`).
  final List<bool> changed;

  /// Number of inserted items.
  int get insertCount => newToOld.where((o) => o < 0).length;

  /// Number of removed items.
  int get removeCount => oldToNew.where((n) => n < 0).length;

  /// Number of items detected as moved.
  int get moveCount => moved.where((m) => m).length;

  /// Number of items whose content changed.
  int get changeCount => changed.where((c) => c).length;

  /// Whether the two lists are identical (same items, same order, same
  /// content).
  bool get isEmpty =>
      insertCount == 0 &&
      removeCount == 0 &&
      moveCount == 0 &&
      changeCount == 0;

  /// A copy with the given [changed] flags (one per new index).
  DiffResult withChanges(List<bool> changed) => DiffResult(
        newToOld: newToOld,
        oldToNew: oldToNew,
        moved: moved,
        changed: changed,
      );

  /// The result as sequential list operations.
  ///
  /// Applied in order to the old list they produce the new list:
  ///
  /// 1. all removals, highest old index first,
  /// 2. moves, each one taking the item out and re-inserting it right after
  ///    its predecessor in the final order,
  /// 3. insertions, lowest new index first (the index is the final index),
  /// 4. content changes, addressed by final index.
  ///
  /// Computed on demand; the animated widgets do not need it.
  List<DiffOperation> get operations {
    final ops = <DiffOperation>[];
    for (var o = oldToNew.length - 1; o >= 0; o--) {
      if (oldToNew[o] < 0) ops.add(DiffOperation(DiffOperationType.remove, o));
    }

    // Survivors in current order, expressed as new indices.
    final current = <int>[
      for (final n in oldToNew)
        if (n >= 0) n,
    ];
    final target = <int>[
      for (var j = 0; j < newToOld.length; j++)
        if (newToOld[j] >= 0) j,
    ];
    for (var t = 0; t < target.length; t++) {
      final item = target[t];
      if (!moved[item]) continue;
      final from = current.indexOf(item);
      current.removeAt(from);
      final int to;
      if (t == 0) {
        to = 0;
      } else {
        to = current.indexOf(target[t - 1]) + 1;
      }
      current.insert(to, item);
      if (to != from) {
        ops.add(DiffOperation(DiffOperationType.move, to, from));
      }
    }

    for (var j = 0; j < newToOld.length; j++) {
      if (newToOld[j] < 0) ops.add(DiffOperation(DiffOperationType.insert, j));
    }
    for (var j = 0; j < changed.length; j++) {
      if (changed[j]) ops.add(DiffOperation(DiffOperationType.change, j));
    }
    return ops;
  }
}

/// Applies [operations] (from `DiffResult.operations`) to [list] in place,
/// taking inserted and changed items from [newItems].
///
/// This is the reference semantics of the operation list and is mostly useful
/// for tests and for driving other list structures.
void applyDiffOperations<T>(
  List<T> list,
  List<DiffOperation> operations,
  List<T> newItems,
) {
  for (final op in operations) {
    switch (op.type) {
      case DiffOperationType.remove:
        list.removeAt(op.index);
      case DiffOperationType.move:
        list.insert(op.index, list.removeAt(op.fromIndex));
      case DiffOperationType.insert:
        list.insert(op.index, newItems[op.index]);
      case DiffOperationType.change:
        list[op.index] = newItems[op.index];
    }
  }
}
