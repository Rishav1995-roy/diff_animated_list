## 0.0.1

* Initial release.
* `DiffAnimatedList`, `DiffAnimatedGrid`, `SliverDiffAnimatedList` and `SliverDiffAnimatedGrid`: pass a new list and the inserts, removals, moves and content changes are worked out and animated.
* Myers O(ND) diff with linear-time move detection; diffs of large lists run on a background isolate (`compute`).
* Insert, remove, move and change transitions with presets (fade, size, scale, slide, combinations) and custom builders; staggering; `DiffAnimatedListTheme`.
* Updates that arrive while animations are running are safe (items that leave stay mounted until their exit finished).
* `DiffAnimatedListController.skipNextAnimations` and `reorderListItem` for drag-to-reorder and `Dismissible`.
* Header, footer, padding and the usual scroll options on the box widgets.
* Public diff API: `diffKeys`, `diffLists`, `diffKeysAsync`, `DiffResult.operations`.
