import 'package:flutter/widgets.dart';

import '../animation/config.dart';
import '../diff/list_diff.dart';
import '../reorder.dart';
import 'core.dart';

/// Options shared by every diff widget.
abstract class _DiffSliverBase<T> extends StatelessWidget {
  const _DiffSliverBase({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.removedItemBuilder,
    this.itemKey,
    this.areItemsTheSame,
    this.areContentsTheSame,
    this.animation,
    this.controller,
    this.detectMoves = true,
    this.isolateThreshold = 1000,
    this.maxEditDistance = defaultMaxEditDistance,
    this.addAutomaticKeepAlives = true,
  });

  /// The current items. Pass a new list (or a mutated one) whenever your data
  /// changes; the widget works out the inserts, removals, moves and changes.
  final List<T> items;

  /// Builds one item. [DiffItemBuilder]'s `index` is the item's index in
  /// [items] (for an item that is animating out, its last index).
  final DiffItemBuilder<T> itemBuilder;

  /// Builds an item that is animating out. Defaults to [itemBuilder]. Use it
  /// to drop widgets that must not stay mounted after the data is gone.
  final DiffItemBuilder<T>? removedItemBuilder;

  /// Returns the identity of an item (an id, for example). Identity decides
  /// whether an item is the same one, moved, inserted or removed. Preferred
  /// over [areItemsTheSame] because it keeps move detection linear and allows
  /// diffing on a background isolate. Keys need `==` and `hashCode`.
  final Object? Function(T item)? itemKey;

  /// Alternative to [itemKey]: compares two items for identity. With neither,
  /// items are compared with `==`. Diffs that use this callback always run on
  /// the UI thread.
  final bool Function(T a, T b)? areItemsTheSame;

  /// Decides whether an item that exists in both lists changed (default
  /// `==`). A change triggers `DiffAnimationConfig.changeTransition`.
  final bool Function(T a, T b)? areContentsTheSame;

  /// Timing and transitions. Falls back to the nearest
  /// [DiffAnimatedListTheme], then to defaults.
  final DiffAnimationConfig? animation;

  /// Optional handle for [DiffAnimatedListController.skipNextAnimations].
  final DiffAnimatedListController? controller;

  /// Whether an item that disappears in one place and appears in another is
  /// animated as a move (default) or as a removal plus an insertion.
  final bool detectMoves;

  /// When the longer of the two lists has at least this many items the diff
  /// runs on a background isolate via `compute`. `null` = always on the UI
  /// thread. Only used with [itemKey] or `==` identity.
  final int? isolateThreshold;

  /// Upper bound for the edit distance searched by the diff, see
  /// [defaultMaxEditDistance].
  final int maxEditDistance;

  /// Forwarded to the underlying sliver delegate.
  final bool addAutomaticKeepAlives;

  Widget _core(SliverGridDelegate? grid) => DiffSliverCore<T>(
        items: items,
        itemBuilder: itemBuilder,
        removedItemBuilder: removedItemBuilder,
        itemKey: itemKey,
        areItemsTheSame: areItemsTheSame,
        areContentsTheSame: areContentsTheSame,
        animation: animation,
        controller: controller,
        detectMoves: detectMoves,
        isolateThreshold: isolateThreshold,
        maxEditDistance: maxEditDistance,
        gridDelegate: grid,
        addAutomaticKeepAlives: addAutomaticKeepAlives,
      );
}

/// A sliver list that animates itself when [items] changes.
///
/// Use it inside a `CustomScrollView` next to other slivers. For a plain
/// scrolling list use [DiffAnimatedList].
class SliverDiffAnimatedList<T> extends _DiffSliverBase<T> {
  /// Creates the sliver.
  const SliverDiffAnimatedList({
    super.key,
    required super.items,
    required super.itemBuilder,
    super.removedItemBuilder,
    super.itemKey,
    super.areItemsTheSame,
    super.areContentsTheSame,
    super.animation,
    super.controller,
    super.detectMoves,
    super.isolateThreshold,
    super.maxEditDistance,
    super.addAutomaticKeepAlives,
  });

  @override
  Widget build(BuildContext context) => _core(null);
}

/// A sliver grid that animates itself when [items] changes.
class SliverDiffAnimatedGrid<T> extends _DiffSliverBase<T> {
  /// Creates the sliver. [gridDelegate] lays out the cells.
  const SliverDiffAnimatedGrid({
    super.key,
    required super.items,
    required super.itemBuilder,
    required this.gridDelegate,
    super.removedItemBuilder,
    super.itemKey,
    super.areItemsTheSame,
    super.areContentsTheSame,
    super.animation,
    super.controller,
    super.detectMoves,
    super.isolateThreshold,
    super.maxEditDistance,
    super.addAutomaticKeepAlives,
  });

  /// Cell layout, for example `SliverGridDelegateWithFixedCrossAxisCount`.
  final SliverGridDelegate gridDelegate;

  @override
  Widget build(BuildContext context) => _core(gridDelegate);
}

/// Scroll settings and decorations of the box widgets.
abstract class _DiffScrollBase<T> extends _DiffSliverBase<T> {
  const _DiffScrollBase({
    super.key,
    required super.items,
    required super.itemBuilder,
    super.removedItemBuilder,
    super.itemKey,
    super.areItemsTheSame,
    super.areContentsTheSame,
    super.animation,
    super.controller,
    super.detectMoves,
    super.isolateThreshold,
    super.maxEditDistance,
    super.addAutomaticKeepAlives,
    this.header,
    this.footer,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.scrollController,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
  });

  /// Shown above the items, scrolls with them.
  final Widget? header;

  /// Shown below the items, scrolls with them.
  final Widget? footer;

  /// Scroll axis.
  final Axis scrollDirection;

  /// Whether the list scrolls from the end.
  final bool reverse;

  /// Controls the scroll position.
  final ScrollController? scrollController;

  /// See `ScrollView.primary`.
  final bool? primary;

  /// See `ScrollView.physics`.
  final ScrollPhysics? physics;

  /// See `ScrollView.shrinkWrap`.
  final bool shrinkWrap;

  /// Padding around the items (not around header and footer).
  final EdgeInsetsGeometry? padding;

  Widget _scroll(Widget sliver) {
    final p = padding;
    return CustomScrollView(
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: scrollController,
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        if (p != null) SliverPadding(padding: p, sliver: sliver) else sliver,
        if (footer != null) SliverToBoxAdapter(child: footer),
      ],
    );
  }
}

/// A scrolling list that animates itself when [items] changes.
///
/// ```dart
/// DiffAnimatedList<Todo>(
///   items: todos,
///   itemKey: (t) => t.id,
///   itemBuilder: (context, todo, index) => TodoTile(todo),
/// )
/// ```
class DiffAnimatedList<T> extends _DiffScrollBase<T> {
  /// Creates the list.
  const DiffAnimatedList({
    super.key,
    required super.items,
    required super.itemBuilder,
    super.removedItemBuilder,
    super.itemKey,
    super.areItemsTheSame,
    super.areContentsTheSame,
    super.animation,
    super.controller,
    super.detectMoves,
    super.isolateThreshold,
    super.maxEditDistance,
    super.addAutomaticKeepAlives,
    super.header,
    super.footer,
    super.scrollDirection,
    super.reverse,
    super.scrollController,
    super.primary,
    super.physics,
    super.shrinkWrap,
    super.padding,
  });

  @override
  Widget build(BuildContext context) => _scroll(_core(null));
}

/// A scrolling grid that animates itself when [items] changes.
class DiffAnimatedGrid<T> extends _DiffScrollBase<T> {
  /// Creates the grid. [gridDelegate] lays out the cells.
  const DiffAnimatedGrid({
    super.key,
    required super.items,
    required super.itemBuilder,
    required this.gridDelegate,
    super.removedItemBuilder,
    super.itemKey,
    super.areItemsTheSame,
    super.areContentsTheSame,
    super.animation,
    super.controller,
    super.detectMoves,
    super.isolateThreshold,
    super.maxEditDistance,
    super.addAutomaticKeepAlives,
    super.header,
    super.footer,
    super.scrollDirection,
    super.reverse,
    super.scrollController,
    super.primary,
    super.physics,
    super.shrinkWrap,
    super.padding,
  });

  /// Cell layout, for example `SliverGridDelegateWithFixedCrossAxisCount`.
  final SliverGridDelegate gridDelegate;

  @override
  Widget build(BuildContext context) => _scroll(_core(gridDelegate));
}
