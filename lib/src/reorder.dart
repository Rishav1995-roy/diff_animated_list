/// Lets the app talk to a diff list, mainly after a user-driven reorder.
///
/// When the user drags an item to a new place, the item already sits where it
/// was dropped; animating the resulting move again would look like a glitch.
/// Call [skipNextAnimations] together with the data change to apply it
/// instantly.
///
/// The same call is the recipe for `Dismissible` and similar widgets that
/// remove themselves visually: call it from `onDismissed` before removing the
/// item from your data.
class DiffAnimatedListController {
  bool _skip = false;

  /// Makes the next update apply without any animation.
  ///
  /// Call it in the same `setState` that changes the data. The flag is
  /// consumed by the next update of the list.
  void skipNextAnimations() => _skip = true;

  /// Reads and clears the skip flag. Used by the widgets.
  bool consumeSkip() {
    final v = _skip;
    _skip = false;
    return v;
  }
}

/// Moves an item with the semantics of `ReorderableListView.onReorder`:
/// [newIndex] is the index *before* the item is taken out, so when moving
/// down it is one too high.
///
/// Handy as `onReorder: (a, b) => setState(() => reorderListItem(items, a, b))`
/// and works with every drag-to-reorder package. The diff list recognises the
/// move and animates it.
void reorderListItem<T>(List<T> list, int oldIndex, int newIndex) {
  if (newIndex > oldIndex) newIndex -= 1;
  list.insert(newIndex, list.removeAt(oldIndex));
}
