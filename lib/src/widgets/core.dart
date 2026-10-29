import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../animation/config.dart';
import '../animation/transitions.dart';
import '../diff/diff_result.dart';
import '../diff/list_diff.dart';
import '../reorder.dart';

/// Builds an item.
typedef DiffItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
);

/// Parameters shared by all four widgets (internal).
class DiffSliverCore<T> extends StatefulWidget {
  const DiffSliverCore({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.removedItemBuilder,
    required this.itemKey,
    required this.areItemsTheSame,
    required this.areContentsTheSame,
    required this.animation,
    required this.controller,
    required this.detectMoves,
    required this.isolateThreshold,
    required this.maxEditDistance,
    required this.gridDelegate,
    required this.addAutomaticKeepAlives,
  });

  final List<T> items;
  final DiffItemBuilder<T> itemBuilder;
  final DiffItemBuilder<T>? removedItemBuilder;
  final Object? Function(T item)? itemKey;
  final bool Function(T a, T b)? areItemsTheSame;
  final bool Function(T a, T b)? areContentsTheSame;
  final DiffAnimationConfig? animation;
  final DiffAnimatedListController? controller;
  final bool detectMoves;
  final int? isolateThreshold;
  final int maxEditDistance;
  final SliverGridDelegate? gridDelegate;
  final bool addAutomaticKeepAlives;

  @override
  State<DiffSliverCore<T>> createState() => _CoreState<T>();
}

class _Entry<T> {
  _Entry(this.id, this.item, {required this.enterPending, this.enterOrder = 0});
  final int id;
  T item;
  T? previousItem;
  int index = 0;
  bool exiting = false;
  bool enterPending;
  int enterOrder;
  int exitOrder = 0;
  int changeStamp = 0;
}

class _CoreState<T> extends State<DiffSliverCore<T>> {
  List<_Entry<T>> _live = [];
  List<_Entry<T>> _display = [];
  Map<int, int> _indexById = {};
  final Map<int, _ShellState<T>> _shells = {};
  final Set<_Entry<T>> _donePending = {};
  bool _purgeScheduled = false;
  int _nextId = 0;
  int _generation = 0;

  bool get _isGrid => widget.gridDelegate != null;

  DiffAnimationConfig get _config =>
      widget.animation ??
      DiffAnimatedListTheme.maybeOf(context) ??
      const DiffAnimationConfig();

  @override
  void initState() {
    super.initState();
    final animate = widget.animation?.animateInitial ?? false;
    var i = 0;
    for (final item in widget.items) {
      final e = _Entry<T>(_nextId++, item, enterPending: animate, enterOrder: i)
        ..index = i;
      _live.add(e);
      i++;
    }
    _display = List.of(_live);
    _reindex();
  }

  @override
  void didUpdateWidget(DiffSliverCore<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  void _reindex() {
    _indexById = {for (var i = 0; i < _display.length; i++) _display[i].id: i};
  }

  // ---------------------------------------------------------------- diff

  void _schedule() {
    final gen = ++_generation;
    final skip = widget.controller?.consumeSkip() ?? false;
    final newItems = List<T>.of(widget.items);
    final oldItems = [for (final e in _live) e.item];
    final threshold = widget.isolateThreshold;
    final large = threshold != null &&
        widget.areItemsTheSame == null &&
        math.max(oldItems.length, newItems.length) >= threshold;

    if (!large) {
      _apply(_diffSync(oldItems, newItems), newItems, !skip);
      return;
    }
    _diffAsync(oldItems, newItems).then((result) {
      if (mounted && gen == _generation) _apply(result, newItems, !skip);
    });
  }

  DiffResult _diffSync(List<T> oldItems, List<T> newItems) => diffLists<T>(
        oldItems,
        newItems,
        itemKey: widget.itemKey,
        areItemsTheSame: widget.areItemsTheSame,
        areContentsTheSame: widget.areContentsTheSame,
        detectMoves: widget.detectMoves,
        maxEditDistance: widget.maxEditDistance,
      );

  Future<DiffResult> _diffAsync(List<T> oldItems, List<T> newItems) async {
    try {
      final key = widget.itemKey ?? (T item) => item;
      final base = await diffKeysAsync(
        [for (final e in oldItems) key(e)],
        [for (final e in newItems) key(e)],
        detectMoves: widget.detectMoves,
        maxEditDistance: widget.maxEditDistance,
      );
      return base.withChanges(
          computeChanged(base, oldItems, newItems, widget.areContentsTheSame));
    } catch (_) {
      // Keys not sendable to an isolate: diff on this thread instead.
      return _diffSync(oldItems, newItems);
    }
  }

  // --------------------------------------------------------------- apply

  void _apply(DiffResult res, List<T> newItems, bool animate) {
    final old = _live;
    if (animate) {
      for (final s in _shells.values) {
        s.capture();
      }
    }

    final newLive = <_Entry<T>>[];
    var enterCount = 0;
    for (var j = 0; j < newItems.length; j++) {
      final o = res.newToOld[j];
      _Entry<T> e;
      if (o >= 0) {
        e = old[o];
        if (res.changed[j]) {
          e.previousItem = e.item;
          e.changeStamp++;
        }
        e.item = newItems[j];
      } else {
        e = _Entry<T>(_nextId++, newItems[j],
            enterPending: animate, enterOrder: enterCount++);
      }
      e.index = j;
      newLive.add(e);
    }
    var exitCount = 0;
    for (var o = 0; o < old.length; o++) {
      if (res.oldToNew[o] < 0) {
        old[o]
          ..exiting = true
          ..exitOrder = exitCount++;
      }
    }

    final ghostsAfter = <int, List<_Entry<T>>>{};
    var anchor = -1;
    for (final e in _display) {
      if (!e.exiting) {
        anchor = e.id;
      } else if (animate && _shells.containsKey(e.id)) {
        (ghostsAfter[anchor] ??= []).add(e);
      }
    }
    final merged = <_Entry<T>>[...?ghostsAfter[-1]];
    for (final e in newLive) {
      merged.add(e);
      final g = ghostsAfter[e.id];
      if (g != null) merged.addAll(g);
    }

    setState(() {
      _live = newLive;
      _display = merged;
      _reindex();
    });
    if (animate) _settleAfterFrame();
  }

  void _settleAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final s in _shells.values.toList()) {
        s.settle();
      }
    });
  }

  void _ghostDone(_Entry<T> entry) {
    _donePending.add(entry);
    if (_purgeScheduled) return;
    _purgeScheduled = true;
    scheduleMicrotask(() {
      _purgeScheduled = false;
      if (!mounted || _donePending.isEmpty) return;
      for (final s in _shells.values) {
        s.capture();
      }
      final done = Set<_Entry<T>>.of(_donePending);
      _donePending.clear();
      setState(() {
        _display = [
          for (final e in _display)
            if (!done.contains(e)) e,
        ];
        _reindex();
      });
      _settleAfterFrame();
    });
  }

  // --------------------------------------------------------------- build

  Widget _buildItem(BuildContext context, _Entry<T> entry, T item) {
    final builder = entry.exiting
        ? (widget.removedItemBuilder ?? widget.itemBuilder)
        : widget.itemBuilder;
    return builder(context, item, entry.index);
  }

  @override
  Widget build(BuildContext context) {
    final delegate = SliverChildBuilderDelegate(
      (context, index) {
        final entry = _display[index];
        return _Shell<T>(
            key: ValueKey<int>(entry.id), entry: entry, core: this);
      },
      childCount: _display.length,
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      findChildIndexCallback: (key) =>
          key is ValueKey<int> ? _indexById[key.value] : null,
    );
    final grid = widget.gridDelegate;
    if (grid != null) {
      return SliverGrid(delegate: delegate, gridDelegate: grid);
    }
    return SliverList(delegate: delegate);
  }
}

class _Shell<T> extends StatefulWidget {
  const _Shell({super.key, required this.entry, required this.core});
  final _Entry<T> entry;
  final _CoreState<T> core;

  @override
  State<_Shell<T>> createState() => _ShellState<T>();
}

class _ShellState<T> extends State<_Shell<T>> with TickerProviderStateMixin {
  late final AnimationController _presence;
  late final AnimationController _move;
  late final AnimationController _change;
  late CurvedAnimation _presenceCurve;
  late CurvedAnimation _changeCurve;
  final GlobalKey _childKey = GlobalKey();
  Timer? _timer;
  Offset? _captured;
  Offset _flipFrom = Offset.zero;
  int _seenChange = 0;
  bool _exitStarted = false;
  T? _oldItem;
  bool _hasOld = false;

  DiffAnimationConfig get _cfg => widget.core._config;
  _Entry<T> get _entry => widget.entry;

  @override
  void initState() {
    super.initState();
    final cfg = _cfg;
    _presence = AnimationController(
      vsync: this,
      duration: cfg.insertDuration,
      reverseDuration: cfg.removeDuration,
      value: _entry.enterPending ? 0 : 1,
    )..addStatusListener((s) {
        if (s == AnimationStatus.dismissed && _entry.exiting) {
          widget.core._ghostDone(_entry);
        }
      });
    _presenceCurve = CurvedAnimation(
        parent: _presence,
        curve: cfg.insertCurve,
        reverseCurve: cfg.removeCurve);
    _move =
        AnimationController(vsync: this, duration: cfg.moveDuration, value: 1);
    _change = AnimationController(
        vsync: this, duration: cfg.changeDuration, value: 1);
    _changeCurve = CurvedAnimation(parent: _change, curve: cfg.changeCurve);
    _seenChange = _entry.changeStamp;
    widget.core._shells[_entry.id] = this;

    if (_entry.exiting) {
      _presence.value = 1;
      _startExit();
    } else if (_entry.enterPending) {
      _entry.enterPending = false;
      _delayed(_entry.enterOrder, _presence.forward);
    }
  }

  void _delayed(int order, VoidCallback action) {
    final cfg = _cfg;
    final delay = cfg.stagger * math.min(order, cfg.maxStaggerSteps);
    if (delay == Duration.zero) {
      action();
    } else {
      _timer = Timer(delay, () {
        _timer = null;
        if (mounted) action();
      });
    }
  }

  void _startExit() {
    _exitStarted = true;
    _timer?.cancel();
    _timer = null;
    if (_presence.value == 0) {
      // Never became visible: nothing to animate.
      scheduleMicrotask(() => widget.core._ghostDone(_entry));
      return;
    }
    _delayed(_entry.exitOrder, () {
      _presence.reverse();
      // A zero-length reverse finishes without notifying status listeners.
      if (_presence.status == AnimationStatus.dismissed) {
        widget.core._ghostDone(_entry);
      }
    });
  }

  @override
  void didUpdateWidget(_Shell<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cfg = _cfg;
    _presence
      ..duration = cfg.insertDuration
      ..reverseDuration = cfg.removeDuration;
    _move.duration = cfg.moveDuration;
    _change.duration = cfg.changeDuration;
    if (_entry.exiting && !_exitStarted) _startExit();
    if (_entry.changeStamp != _seenChange) {
      _seenChange = _entry.changeStamp;
      _oldItem = _entry.previousItem;
      _hasOld = true;
      if (cfg.changeDuration > Duration.zero) _change.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.core._shells[_entry.id] == this) {
      widget.core._shells.remove(_entry.id);
    }
    _presenceCurve.dispose();
    _changeCurve.dispose();
    _presence.dispose();
    _move.dispose();
    _change.dispose();
    super.dispose();
  }

  // ---- move (FLIP)

  Offset get _translation =>
      _flipFrom * (1 - _cfg.moveCurve.transform(_move.value));

  Offset? _layoutOffset() {
    final ro = context.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) {
      return ro.localToGlobal(Offset.zero);
    }
    return null;
  }

  void capture() => _captured = _layoutOffset();

  void settle() {
    final before = _captured;
    _captured = null;
    if (before == null || !mounted) return;
    final now = _layoutOffset();
    if (now == null) return;
    final delta = before - now;
    if (delta.distance < 0.5) return;
    if (_cfg.moveDuration == Duration.zero) return;
    _flipFrom = delta + _translation;
    _move.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    final isGrid = widget.core._isGrid;
    final entry = _entry;

    Widget current = KeyedSubtree(
      key: _childKey,
      child: widget.core._buildItem(context, entry, entry.item),
    );

    final changeBuilder = cfg.changeTransition;
    final withChange = AnimatedBuilder(
      animation: _change,
      child: current,
      builder: (context, child) {
        if (_change.isAnimating && _hasOld) {
          final oldChild =
              widget.core._buildItem(context, entry, _oldItem as T);
          return changeBuilder(context, oldChild, child!, _changeCurve);
        }
        return child!;
      },
    );

    final insert = cfg.insertTransition ??
        (isGrid ? DiffTransitions.scaleAndFade : DiffTransitions.sizeAndFade);
    final remove = cfg.removeTransition ?? insert;
    final presence = AnimatedBuilder(
      animation: _presenceCurve,
      child: withChange,
      builder: (context, child) =>
          (entry.exiting ? remove : insert)(context, child!, _presenceCurve),
    );

    return AnimatedBuilder(
      animation: _move,
      child: IgnorePointer(ignoring: entry.exiting, child: presence),
      builder: (context, child) {
        Widget w = child!;
        final mb = cfg.moveBuilder;
        if (mb != null && _move.isAnimating) w = mb(context, w, _move);
        return Transform.translate(offset: _translation, child: w);
      },
    );
  }
}
