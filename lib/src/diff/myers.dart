import 'dart:math' as math;
import 'dart:typed_data';

/// Myers' O(ND) shortest-edit-script search.
///
/// Compares `a[0..n)` with `b[0..m)` through [same] and returns the matched
/// pairs as a flat list `[x0, y0, x1, y1, ...]` (in descending order), or
/// `null` when the edit distance exceeds [maxD]. Memory is O(D^2) because the
/// frontier of every round is kept for the backtrack.
///
/// Reference: E. W. Myers, "An O(ND) Difference Algorithm and Its
/// Variations", Algorithmica 1(2), 1986.
List<int>? myersMatches(
  int n,
  int m,
  bool Function(int x, int y) same,
  int maxD,
) {
  if (n == 0 || m == 0) return const <int>[];
  final max = math.min(n + m, maxD);
  final offset = max + 1;
  final v = Int32List(2 * max + 3);
  final trace = <Int32List>[];

  for (var d = 0; d <= max; d++) {
    // Frontier of the previous round for the diagonals -d-1 .. d+1.
    trace.add(Int32List.fromList(v.sublist(offset - d - 1, offset + d + 2)));
    for (var k = -d; k <= d; k += 2) {
      int x;
      if (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1])) {
        x = v[offset + k + 1];
      } else {
        x = v[offset + k - 1] + 1;
      }
      var y = x - k;
      while (x < n && y < m && same(x, y)) {
        x++;
        y++;
      }
      v[offset + k] = x;
      if (x == n && y == m) {
        return _backtrack(trace, n, m, d);
      }
    }
  }
  return null;
}

List<int> _backtrack(List<Int32List> trace, int n, int m, int lastD) {
  final matches = <int>[];
  var x = n;
  var y = m;
  for (var d = lastD; d >= 0; d--) {
    final snap = trace[d];
    final k = x - y;
    final int prevK;
    if (k == -d || (k != d && snap[k - 1 + d + 1] < snap[k + 1 + d + 1])) {
      prevK = k + 1;
    } else {
      prevK = k - 1;
    }
    final prevX = snap[prevK + d + 1];
    final prevY = prevX - prevK;
    while (x > prevX && y > prevY) {
      x--;
      y--;
      matches
        ..add(x)
        ..add(y);
    }
    if (d > 0) {
      x = prevX;
      y = prevY;
    }
  }
  return matches;
}
