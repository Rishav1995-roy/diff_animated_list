import 'package:flutter/widgets.dart';

import 'transitions.dart';

/// All timing and look settings of the animated lists.
///
/// Every field is optional. Set one on a widget through `animation:`, or for a
/// whole subtree with [DiffAnimatedListTheme]. Precedence: widget, theme,
/// defaults.
@immutable
class DiffAnimationConfig {
  /// Creates a configuration.
  const DiffAnimationConfig({
    this.insertTransition,
    this.removeTransition,
    this.changeTransition = DiffChangeTransitions.none,
    this.moveBuilder,
    this.insertDuration = const Duration(milliseconds: 300),
    this.removeDuration = const Duration(milliseconds: 250),
    this.moveDuration = const Duration(milliseconds: 350),
    this.changeDuration = const Duration(milliseconds: 300),
    this.insertCurve = Curves.easeOutCubic,
    this.removeCurve = Curves.easeInOutCubic,
    this.moveCurve = Curves.easeInOutCubic,
    this.changeCurve = Curves.easeInOut,
    this.stagger = Duration.zero,
    this.maxStaggerSteps = 12,
    this.animateInitial = false,
  });

  /// Look of inserted items. `null` = size + fade in lists, scale + fade in
  /// grids.
  final DiffTransitionBuilder? insertTransition;

  /// Look of removed items (the animation runs 1 to 0). `null` = same as
  /// insert defaults.
  final DiffTransitionBuilder? removeTransition;

  /// Look of items whose content changed. Opt in, for example with
  /// [DiffChangeTransitions.crossFade]; the default only swaps the content.
  final DiffChangeTransitionBuilder changeTransition;

  /// Optional wrapper shown while an item slides to its new position (use it
  /// to lift or highlight moving items).
  final DiffMoveBuilder? moveBuilder;

  /// Duration of the insert animation.
  final Duration insertDuration;

  /// Duration of the remove animation.
  final Duration removeDuration;

  /// Duration of the slide to a new position. `Duration.zero` disables move
  /// animation.
  final Duration moveDuration;

  /// Duration of the content change animation.
  final Duration changeDuration;

  /// Curve of the insert animation.
  final Curve insertCurve;

  /// Curve of the remove animation, applied to the controller value while it
  /// runs from 1 to 0 (like `CurvedAnimation.reverseCurve`).
  final Curve removeCurve;

  /// Curve of the slide to a new position.
  final Curve moveCurve;

  /// Curve of the content change animation.
  final Curve changeCurve;

  /// Extra delay between consecutive inserted (or removed) items of one update.
  /// `Duration.zero` starts them all together.
  final Duration stagger;

  /// Upper bound of the stagger steps, so a 500 item insert does not take
  /// minutes to finish.
  final int maxStaggerSteps;

  /// Whether the items present at first build animate in.
  final bool animateInitial;

  /// A configuration without any animation.
  static const DiffAnimationConfig disabled = DiffAnimationConfig(
    insertDuration: Duration.zero,
    removeDuration: Duration.zero,
    moveDuration: Duration.zero,
    changeDuration: Duration.zero,
  );

  /// Copy with some fields replaced.
  DiffAnimationConfig copyWith({
    DiffTransitionBuilder? insertTransition,
    DiffTransitionBuilder? removeTransition,
    DiffChangeTransitionBuilder? changeTransition,
    DiffMoveBuilder? moveBuilder,
    Duration? insertDuration,
    Duration? removeDuration,
    Duration? moveDuration,
    Duration? changeDuration,
    Curve? insertCurve,
    Curve? removeCurve,
    Curve? moveCurve,
    Curve? changeCurve,
    Duration? stagger,
    int? maxStaggerSteps,
    bool? animateInitial,
  }) =>
      DiffAnimationConfig(
        insertTransition: insertTransition ?? this.insertTransition,
        removeTransition: removeTransition ?? this.removeTransition,
        changeTransition: changeTransition ?? this.changeTransition,
        moveBuilder: moveBuilder ?? this.moveBuilder,
        insertDuration: insertDuration ?? this.insertDuration,
        removeDuration: removeDuration ?? this.removeDuration,
        moveDuration: moveDuration ?? this.moveDuration,
        changeDuration: changeDuration ?? this.changeDuration,
        insertCurve: insertCurve ?? this.insertCurve,
        removeCurve: removeCurve ?? this.removeCurve,
        moveCurve: moveCurve ?? this.moveCurve,
        changeCurve: changeCurve ?? this.changeCurve,
        stagger: stagger ?? this.stagger,
        maxStaggerSteps: maxStaggerSteps ?? this.maxStaggerSteps,
        animateInitial: animateInitial ?? this.animateInitial,
      );
}

/// Provides a default [DiffAnimationConfig] to every diff list below it.
class DiffAnimatedListTheme extends InheritedWidget {
  /// Creates the theme.
  const DiffAnimatedListTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// The configuration handed to descendants.
  final DiffAnimationConfig data;

  /// The nearest theme data, or `null`.
  static DiffAnimationConfig? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DiffAnimatedListTheme>()?.data;

  @override
  bool updateShouldNotify(DiffAnimatedListTheme oldWidget) =>
      data != oldWidget.data;
}
