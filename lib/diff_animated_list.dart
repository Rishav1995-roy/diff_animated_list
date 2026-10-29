/// Animated lists and grids that work out inserts, removals, moves and
/// changes by themselves.
library;

export 'src/animation/config.dart';
export 'src/animation/transitions.dart';
export 'src/diff/diff_operation.dart';
export 'src/diff/diff_result.dart' show DiffResult, applyDiffOperations;
export 'src/diff/list_diff.dart'
    show defaultMaxEditDistance, diffKeys, diffKeysAsync, diffLists;
export 'src/reorder.dart';
export 'src/widgets/core.dart' show DiffItemBuilder;
export 'src/widgets/diff_widgets.dart';
