import 'package:flutter/widgets.dart';

/// Builds the insert/remove look of an item.
///
/// [animation] runs from 0 (hidden) to 1 (fully shown) when an item is
/// inserted and from 1 back to 0 when it is removed, so one builder serves
/// both directions.
typedef DiffTransitionBuilder = Widget Function(
  BuildContext context,
  Widget child,
  Animation<double> animation,
);

/// Builds the look of an item whose content changed.
///
/// [oldChild] is the item built from the previous data, [newChild] from the
/// new data. [animation] runs from 0 to 1.
typedef DiffChangeTransitionBuilder = Widget Function(
  BuildContext context,
  Widget oldChild,
  Widget newChild,
  Animation<double> animation,
);

/// Wraps an item while it slides to its new position after a move or after
/// its neighbours moved. [animation] runs from 0 to 1.
typedef DiffMoveBuilder = Widget Function(
  BuildContext context,
  Widget child,
  Animation<double> animation,
);

/// Ready-made insert/remove transitions.
///
/// The parameterless ones are `const`-friendly static methods and can be used
/// as default values; the `*From`, `sizeAxis` and `combine` helpers return a
/// configured builder.
abstract final class DiffTransitions {
  /// No animation: the item pops in and out.
  static Widget none(BuildContext c, Widget child, Animation<double> a) =>
      child;

  /// Fades the item.
  static Widget fade(BuildContext c, Widget child, Animation<double> a) =>
      FadeTransition(opacity: a, child: child);

  /// Grows and shrinks the item along the main axis (vertical).
  static Widget size(BuildContext c, Widget child, Animation<double> a) =>
      SizeTransition(sizeFactor: a, child: child);

  /// Scales the item around its centre.
  static Widget scale(BuildContext c, Widget child, Animation<double> a) =>
      ScaleTransition(scale: a, child: child);

  /// Slides the item in from the right.
  static Widget slide(BuildContext c, Widget child, Animation<double> a) =>
      slideFrom(const Offset(1, 0))(c, child, a);

  /// [size] and [fade] together. Default for lists.
  static Widget sizeAndFade(
          BuildContext c, Widget child, Animation<double> a) =>
      SizeTransition(
        sizeFactor: a,
        child: FadeTransition(opacity: a, child: child),
      );

  /// [scale] and [fade] together. Default for grids.
  static Widget scaleAndFade(
    BuildContext c,
    Widget child,
    Animation<double> a,
  ) =>
      ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1).animate(a),
        child: FadeTransition(opacity: a, child: child),
      );

  /// [slide], [size] and [fade] together.
  static Widget slideAndFade(
          BuildContext c, Widget child, Animation<double> a) =>
      sizeAndFade(c, slide(c, child, a), a);

  /// Slides in from [begin] (a fraction of the item size).
  static DiffTransitionBuilder slideFrom(Offset begin) =>
      (c, child, a) => SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero).animate(a),
            child: child,
          );

  /// Size transition along [axis].
  static DiffTransitionBuilder sizeAxis(Axis axis) =>
      (c, child, a) => SizeTransition(sizeFactor: a, axis: axis, child: child);

  /// Scale from [begin] to 1 around [alignment].
  static DiffTransitionBuilder scaleFrom(
    double begin, {
    Alignment alignment = Alignment.center,
  }) =>
      (c, child, a) => ScaleTransition(
            scale: Tween<double>(begin: begin, end: 1).animate(a),
            alignment: alignment,
            child: child,
          );

  /// Applies [builders] from last to first (the first one ends up outermost).
  static DiffTransitionBuilder combine(List<DiffTransitionBuilder> builders) =>
      (c, child, a) {
        var result = child;
        for (final b in builders.reversed) {
          result = b(c, result, a);
        }
        return result;
      };
}

/// Ready-made transitions for content changes.
abstract final class DiffChangeTransitions {
  /// Swap instantly (the item is still rebuilt with the new data).
  static Widget none(BuildContext c, Widget o, Widget n, Animation<double> a) =>
      n;

  /// Cross-fades the old content into the new content.
  static Widget crossFade(
    BuildContext c,
    Widget oldChild,
    Widget newChild,
    Animation<double> a,
  ) =>
      Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: ReverseAnimation(a),
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: double.infinity,
                child: oldChild,
              ),
            ),
          ),
          FadeTransition(opacity: a, child: newChild),
        ],
      );

  /// Fades the new content in (the old one is not shown).
  static Widget fadeIn(
          BuildContext c, Widget o, Widget n, Animation<double> a) =>
      FadeTransition(
        opacity: Tween<double>(begin: 0.3, end: 1).animate(a),
        child: n,
      );

  /// A small "pop": the new content scales from 0.92 back to 1.
  static Widget pop(BuildContext c, Widget o, Widget n, Animation<double> a) =>
      ScaleTransition(
        scale: TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 60),
        ]).animate(a),
        child: n,
      );
}
