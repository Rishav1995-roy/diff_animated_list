/// The kind of a [DiffOperation].
enum DiffOperationType {
  /// An item was added at [DiffOperation.index].
  insert,

  /// The item at [DiffOperation.index] was removed.
  remove,

  /// The item at [DiffOperation.fromIndex] moved to [DiffOperation.index].
  move,

  /// The item at [DiffOperation.index] has the same identity but new content.
  change,
}

/// One step of a diff, expressed as a plain list operation.
///
/// The operations of a [DiffResult] are meant to be applied **in order** to
/// a copy of the old list. See `DiffResult.operations` for the exact order and
/// semantics, and `applyDiffOperations` for a reference implementation.
class DiffOperation {
  /// Creates an operation. Prefer reading them from `DiffResult.operations`.
  const DiffOperation(this.type, this.index, [this.fromIndex = -1]);

  /// What happens.
  final DiffOperationType type;

  /// Target index. For [DiffOperationType.move] this is the index the item
  /// has **after** it was taken out of the list (`list.insert(index,
  /// list.removeAt(fromIndex))`).
  final int index;

  /// Source index, only meaningful for [DiffOperationType.move]; `-1`
  /// otherwise.
  final int fromIndex;

  @override
  bool operator ==(Object other) =>
      other is DiffOperation &&
      other.type == type &&
      other.index == index &&
      other.fromIndex == fromIndex;

  @override
  int get hashCode => Object.hash(type, index, fromIndex);

  @override
  String toString() => type == DiffOperationType.move
      ? 'move($fromIndex -> $index)'
      : '${type.name}($index)';
}
