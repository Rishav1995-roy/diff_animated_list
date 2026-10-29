import 'package:flutter/foundation.dart';

import 'diff_result.dart';
import 'myers.dart';

/// Default cap on the edit distance searched by Myers' algorithm.
///
/// Above it the search stops and unmatched items are paired by key
/// (`diffKeys`) or reported as insert + remove. The result is still correct,
/// only less minimal. Memory use is roughly `4 * D^2` bytes.
const int defaultMaxEditDistance = 2000;

const int _maxMoveComparisons = 4000000;

/// Compares two key lists and returns what changed.
///
/// Items are identified by `==` on their key. Duplicate keys are matched
/// first-come first-served. When [detectMoves] is `true`, an item that was
/// removed in one place and inserted in another is reported as a move.
///
/// Runs in `O((N + M) + D^2)` time on the typical case where the lists are
/// mostly equal (`N`/`M` are the lengths, `D` the edit distance).
DiffResult diffKeys(
  List<Object?> oldKeys,
  List<Object?> newKeys, {
  bool detectMoves = true,
  int maxEditDistance = defaultMaxEditDistance,
}) {
  return _diff(
    oldKeys.length,
    newKeys.length,
    (i, j) => oldKeys[i] == newKeys[j],
    detectMoves: detectMoves,
    maxEditDistance: maxEditDistance,
    oldKeys: oldKeys,
    newKeys: newKeys,
  );
}

/// Compares two lists of items.
///
/// Identity is decided by [itemKey] (preferred: it makes move detection
/// linear), or by [areItemsTheSame], or, when both are omitted, by `==` on the
/// items. [areContentsTheSame] (default `==`) decides which kept items are
/// reported in `DiffResult.changed`.
DiffResult diffLists<T>(
  List<T> oldList,
  List<T> newList, {
  Object? Function(T item)? itemKey,
  bool Function(T a, T b)? areItemsTheSame,
  bool Function(T a, T b)? areContentsTheSame,
  bool detectMoves = true,
  int maxEditDistance = defaultMaxEditDistance,
}) {
  final DiffResult base;
  if (itemKey != null || areItemsTheSame == null) {
    final key = itemKey ?? (T item) => item;
    base = diffKeys(
      [for (final e in oldList) key(e)],
      [for (final e in newList) key(e)],
      detectMoves: detectMoves,
      maxEditDistance: maxEditDistance,
    );
  } else {
    base = _diff(
      oldList.length,
      newList.length,
      (i, j) => areItemsTheSame(oldList[i], newList[j]),
      detectMoves: detectMoves,
      maxEditDistance: maxEditDistance,
    );
  }
  return base.withChanges(
    computeChanged(base, oldList, newList, areContentsTheSame),
  );
}

/// Per new index: whether the kept item changed content.
List<bool> computeChanged<T>(
  DiffResult result,
  List<T> oldList,
  List<T> newList,
  bool Function(T a, T b)? areContentsTheSame,
) {
  final same = areContentsTheSame ?? (T a, T b) => a == b;
  return [
    for (var j = 0; j < result.newToOld.length; j++)
      result.newToOld[j] >= 0 && !same(oldList[result.newToOld[j]], newList[j]),
  ];
}

/// Like [diffKeys], but runs on a background isolate with [compute].
///
/// Keys must be sendable between isolates (numbers, strings, enums, lists...).
/// On the web `compute` runs on the main thread. Throws if the keys cannot be
/// sent; callers fall back to [diffKeys].
Future<DiffResult> diffKeysAsync(
  List<Object?> oldKeys,
  List<Object?> newKeys, {
  bool detectMoves = true,
  int maxEditDistance = defaultMaxEditDistance,
}) {
  return compute(
    _diffKeysEntry,
    _KeysRequest(oldKeys, newKeys, detectMoves, maxEditDistance),
  );
}

class _KeysRequest {
  _KeysRequest(this.oldKeys, this.newKeys, this.detectMoves, this.maxD);
  final List<Object?> oldKeys;
  final List<Object?> newKeys;
  final bool detectMoves;
  final int maxD;
}

DiffResult _diffKeysEntry(_KeysRequest r) => diffKeys(
      r.oldKeys,
      r.newKeys,
      detectMoves: r.detectMoves,
      maxEditDistance: r.maxD,
    );

DiffResult _diff(
  int oldLen,
  int newLen,
  bool Function(int i, int j) same, {
  required bool detectMoves,
  required int maxEditDistance,
  List<Object?>? oldKeys,
  List<Object?>? newKeys,
}) {
  final newToOld = List<int>.filled(newLen, -1);
  final common = oldLen < newLen ? oldLen : newLen;

  var prefix = 0;
  while (prefix < common && same(prefix, prefix)) {
    newToOld[prefix] = prefix;
    prefix++;
  }
  var suffix = 0;
  while (suffix < common - prefix &&
      same(oldLen - 1 - suffix, newLen - 1 - suffix)) {
    newToOld[newLen - 1 - suffix] = oldLen - 1 - suffix;
    suffix++;
  }

  final n = oldLen - prefix - suffix;
  final m = newLen - prefix - suffix;
  if (n > 0 && m > 0) {
    final matches = myersMatches(
      n,
      m,
      (x, y) => same(prefix + x, prefix + y),
      maxEditDistance,
    );
    if (matches != null) {
      for (var i = 0; i < matches.length; i += 2) {
        newToOld[prefix + matches[i + 1]] = prefix + matches[i];
      }
    }
  }

  final moved = List<bool>.filled(newLen, false);
  if (detectMoves) {
    final usedOld = List<bool>.filled(oldLen, false);
    for (final o in newToOld) {
      if (o >= 0) usedOld[o] = true;
    }
    final freeOld = <int>[
      for (var i = 0; i < oldLen; i++)
        if (!usedOld[i]) i,
    ];
    final freeNew = <int>[
      for (var j = 0; j < newLen; j++)
        if (newToOld[j] < 0) j,
    ];
    if (freeOld.isNotEmpty && freeNew.isNotEmpty) {
      if (oldKeys != null && newKeys != null) {
        final byKey = <Object?, List<int>>{};
        for (final i in freeOld.reversed) {
          (byKey[oldKeys[i]] ??= <int>[]).add(i);
        }
        for (final j in freeNew) {
          final bucket = byKey[newKeys[j]];
          if (bucket != null && bucket.isNotEmpty) {
            newToOld[j] = bucket.removeLast();
            moved[j] = true;
          }
        }
      } else if (freeOld.length * freeNew.length <= _maxMoveComparisons) {
        final pool = List<int>.of(freeOld);
        for (final j in freeNew) {
          for (var p = 0; p < pool.length; p++) {
            if (same(pool[p], j)) {
              newToOld[j] = pool.removeAt(p);
              moved[j] = true;
              break;
            }
          }
        }
      }
    }
  }

  final oldToNew = List<int>.filled(oldLen, -1);
  for (var j = 0; j < newLen; j++) {
    if (newToOld[j] >= 0) oldToNew[newToOld[j]] = j;
  }
  return DiffResult(
    newToOld: newToOld,
    oldToNew: oldToNew,
    moved: moved,
    changed: List<bool>.filled(newLen, false),
  );
}
