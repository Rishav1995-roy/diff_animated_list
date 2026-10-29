# diff_animated_list

[![pub version](https://img.shields.io/pub/v/diff_animated_list.svg)](https://pub.dev/packages/diff_animated_list)
[![pub points](https://img.shields.io/pub/points/diff_animated_list)](https://pub.dev/packages/diff_animated_list/score)
[![likes](https://img.shields.io/pub/likes/diff_animated_list)](https://pub.dev/packages/diff_animated_list)
[![popularity](https://img.shields.io/pub/popularity/diff_animated_list)](https://pub.dev/packages/diff_animated_list/score)
[![CI](https://github.com/Rishav1995-roy/diff_animated_list/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Rishav1995-roy/diff_animated_list/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-android%20%7C%20ios%20%7C%20web%20%7C%20macos%20%7C%20windows%20%7C%20linux-informational)

Give a Flutter list or grid a new list of items. It works out the inserts, removals, **moves** and changes itself and animates them. No `insertItem` / `removeItem` bookkeeping, no index arithmetic.

![Demo](https://raw.githubusercontent.com/Rishav1995-roy/diff_animated_list/main/doc/demo.gif)

<p>
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/diff_animated_list/main/doc/screenshot_light.png" width="260" alt="Light mode">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/diff_animated_list/main/doc/screenshot_dark.png" width="260" alt="Dark mode">
</p>

The demo is rendered from the example app frame by frame in a widget test (see `tool/make_demo.sh`), not recorded on a device.

## Why this package

Flutter's `AnimatedList` makes you mirror every data change with an `insertItem` or `removeItem` call at the right index ([flutter/flutter#128241](https://github.com/flutter/flutter/issues/128241) asks for an automatic version). The packages that did that are `implicitly_animated_reorderable_list` (discontinued) and its fork `animated_list_plus` (last release 2023-08).

| | `AnimatedList` | `implicitly_animated_reorderable_list` | `animated_list_plus` | `diff_animated_list` |
|---|---|---|---|---|
| Works out changes from a new list | No, manual calls | Yes | Yes | Yes |
| Moves animate position | No | Yes | Yes | Yes |
| Maintained | Flutter SDK | Discontinued | Last release 2023-08 | Yes |
| Diff on a background isolate for large lists | - | No | No | Yes (`compute`, threshold configurable) |
| List, grid, sliver list, sliver grid | List and sliver list, grid separately | List | List | All four |
| Transitions | One builder | Fixed per widget | Fixed per widget | Presets plus custom builders for insert, remove, move and change |
| Staggering | Manual | No | No | `stagger` |
| Plays well with `Dismissible` | Manual | Open issues | Open issues (#21, #23 on its tracker) | Yes, via `skipNextAnimations` (tested) |
| Header and footer | Manual slivers | - | - | Built in |

All behaviour claims above about this package are covered by tests in `test/`. The competitor columns come from their pub.dev pages and trackers at the time of writing; check them yourself before deciding.

## Install

```sh
flutter pub add diff_animated_list
```

Pure Dart, no native code, no dependencies besides Flutter. Requires Flutter 3.27 or newer.

## Quick start

```dart
DiffAnimatedList<Todo>(
  items: todos,                       // your data, as it is now
  itemKey: (todo) => todo.id,         // identity: same id = same item
  itemBuilder: (context, todo, index) => TodoTile(todo),
)
```

Change `todos` in `setState` (add, remove, sort, shuffle, filter, replace the list) and the list animates. That is the whole API for the common case.

- `itemKey` decides whether an item is "the same one". An item that left one spot and showed up in another is a **move** and slides there.
- `areContentsTheSame` (default `==`) decides whether a kept item **changed**. Only then the change transition runs.

## Widgets

| Widget | Use |
|---|---|
| `DiffAnimatedList<T>` | Scrolling list with header, footer, padding |
| `DiffAnimatedGrid<T>` | Scrolling grid (`gridDelegate`) |
| `SliverDiffAnimatedList<T>` | Inside your own `CustomScrollView` |
| `SliverDiffAnimatedGrid<T>` | Same, grid |

### Options on every widget

| Parameter | Description |
|---|---|
| `items`, `itemBuilder` | Data and builder `(context, item, index)` |
| `itemKey` | Identity of an item. Preferred; enables linear move detection and background diffing |
| `areItemsTheSame` | Alternative identity callback (diffed on the UI thread) |
| `areContentsTheSame` | Content equality, default `==` |
| `removedItemBuilder` | Builder for items animating out (default: `itemBuilder`) |
| `animation` | `DiffAnimationConfig`, see below. Falls back to `DiffAnimatedListTheme` |
| `controller` | `DiffAnimatedListController` |
| `detectMoves` | `false` = report move as remove + insert |
| `isolateThreshold` | Diff in an isolate from this many items (default 1000, `null` = never) |
| `maxEditDistance` | Upper bound of the diff search (default 2000); beyond it the result is still correct, only less minimal |

The box widgets add `header`, `footer`, `padding`, `scrollDirection`, `reverse`, `scrollController`, `primary`, `physics`, `shrinkWrap`.

### `DiffAnimationConfig`

| Field | Default | Description |
|---|---|---|
| `insertTransition` / `removeTransition` | size+fade (list), scale+fade (grid) | `(context, child, animation)`; animation is 0 = hidden, 1 = shown for both directions |
| `changeTransition` | `DiffChangeTransitions.none` | `(context, old, new, animation)`; presets `crossFade`, `fadeIn`, `pop` |
| `moveBuilder` | none | Wrap moving items, e.g. to lift them |
| `insertDuration` / `removeDuration` / `moveDuration` / `changeDuration` | 300 / 250 / 350 / 300 ms | `Duration.zero` disables that animation |
| `insertCurve` / `removeCurve` / `moveCurve` / `changeCurve` | ease-out / ease-in-out | |
| `stagger`, `maxStaggerSteps` | zero, 12 | Delay between consecutive inserted (or removed) items of one update |
| `animateInitial` | `false` | Animate the first items in (read from the widget's `animation`) |

Presets in `DiffTransitions`: `none`, `fade`, `size`, `scale`, `slide`, `sizeAndFade`, `scaleAndFade`, `slideAndFade`, plus `slideFrom(offset)`, `sizeAxis(axis)`, `scaleFrom(begin)` and `combine([...])`. Anything with the builder signature works as a custom transition.

```dart
DiffAnimatedList<Todo>(
  items: todos,
  itemKey: (t) => t.id,
  animation: DiffAnimationConfig(
    insertTransition: DiffTransitions.combine([
      DiffTransitions.size,
      DiffTransitions.slideFrom(const Offset(-1, 0)),
    ]),
    removeTransition: DiffTransitions.fade,
    changeTransition: DiffChangeTransitions.crossFade,
    stagger: const Duration(milliseconds: 40),
    moveBuilder: (context, child, a) =>
        Material(elevation: 6 * a.value, child: child),
  ),
  itemBuilder: ...,
)
```

Set one configuration for a whole subtree with `DiffAnimatedListTheme(data: ..., child: ...)`.

## Rapid updates

Items that leave stay mounted (and non-interactive) until their exit animation finished; the list never relies on index bookkeeping that a second update could invalidate. Every update is diffed against what the list currently shows, so updating 200 times in a row, mid-animation, ends in the right state (see the test "rapid successive updates"). With `isolateThreshold`, a newer update supersedes a diff that is still computing.

## Dismissible, drag to reorder

A `Dismissible` (and similar swipe widgets) already animates the item away. Tell the list so it does not animate again, and the widget is gone in the same frame as Flutter requires:

```dart
final controller = DiffAnimatedListController();

itemBuilder: (context, task, i) => Dismissible(
  key: ValueKey(task.id),
  onDismissed: (_) {
    controller.skipNextAnimations();
    setState(() => tasks = tasks.where((t) => t.id != task.id).toList());
  },
  child: ...,
),
```

For drag-to-reorder UIs, call `skipNextAnimations()` in `onReorder` (the dropped item already sits in place) and use `reorderListItem(list, oldIndex, newIndex)` for the list change. Moves caused by buttons, sorting or server data animate normally. This package does not ship its own drag handle.

I have not tested the `flutter_slidable` package; it follows the same pattern as `Dismissible`.

## Using the diff on its own

```dart
final r = diffLists(oldList, newList, itemKey: (e) => e.id);
r.insertCount; r.removeCount; r.moveCount; r.changeCount;
r.operations; // sequential insert/remove/move/change steps
```

`diffKeys`, `diffKeysAsync` and `applyDiffOperations` are exported too. The diff is Myers' O(ND) algorithm (E. W. Myers, 1986) on the identity keys, with common prefix/suffix trimming; unmatched items with equal keys are paired as moves through a hash map.

## How moves animate

A move is not a remove plus an insert. After the structural change, every visible item whose layout position jumped is translated back to where it was and animated to its new position (the FLIP technique). Items that are not on screen are not animated.

Limits to know:

- Items that jump in from outside the viewport appear in place, they do not fly in.
- A moving item can be painted under items that come after it in the list.
- With `areItemsTheSame` instead of `itemKey`, the diff runs on the UI thread and move detection is quadratic in the number of unmatched items (skipped above 4 million comparisons).

## Platform support

| Android | iOS | Web | macOS | Windows | Linux |
|---|---|---|---|---|---|
| Yes | Yes | Yes | Yes | Yes | Yes |

On the web `compute` runs on the main thread, so large diffs are not off-thread there.

## Coming from `animated_list_plus` / `implicitly_animated_reorderable_list`

| Before | After |
|---|---|
| `ImplicitlyAnimatedList(items:, areItemsTheSame:, itemBuilder: (context, animation, item, i))` | `DiffAnimatedList(items:, itemKey:, itemBuilder: (context, item, index))`, or keep `areItemsTheSame:` |
| `removeItemBuilder` | `removedItemBuilder` (optional) |
| `insertDuration`, `removeDuration`, `updateDuration` | `DiffAnimationConfig(insertDuration:, removeDuration:, changeDuration:)` |
| `SliverImplicitlyAnimatedList` | `SliverDiffAnimatedList` |
| Reorderable variants | Use any reorder UI plus `reorderListItem` and `skipNextAnimations` |

## Coming from `AnimatedList`

Delete the `GlobalKey<AnimatedListState>` and every `insertItem` / `removeItem` call. Keep your data in a normal list, replace it in `setState`, pass it as `items`.

## FAQ

**Items with the same key twice?** Duplicates are matched first come first served; the result is still consistent.

**Every item cross-fades on every update.** You enabled a change transition and your items do not implement `==`. Pass `areContentsTheSame` or implement `==`.

**Large lists?** Typical updates (a few edits) diff in time linear in the list length. 20 000 items with 34 edits diff in well under half a second (asserted in the tests). Lists above `isolateThreshold` items use a background isolate when keys can be sent between isolates; otherwise it falls back to the UI thread.

## Contributing

Issues and pull requests are welcome. Run `flutter analyze` and `flutter test` before opening one.

## License

MIT, see [LICENSE](LICENSE).
