import 'package:flutter/material.dart';

/// A synthetic item used by the examples.
class Task {
  /// Creates a task.
  const Task(this.id, this.title, this.tag, this.color);

  /// Stable identity.
  final int id;

  /// Display title.
  final String title;

  /// Category.
  final String tag;

  /// Accent colour.
  final Color color;

  /// Copy with a new title (same identity).
  Task rename(String t) => Task(id, t, tag, color);

  @override
  bool operator ==(Object other) =>
      other is Task && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

/// Categories with their colours.
const tagColors = {
  'Work': Color(0xFF4F46E5),
  'Home': Color(0xFF0D9488),
  'Play': Color(0xFFE11D48),
  'Study': Color(0xFFD97706),
};

const _titles = [
  'Plan the sprint',
  'Water the plants',
  'Practice guitar',
  'Read a chapter',
  'Review pull requests',
  'Bake bread',
  'Go for a run',
  'Write release notes',
  'Fix the bike',
  'Learn a new chord',
  'Call the plumber',
  'Sketch a logo',
  'Tidy the desk',
  'Watch a lecture',
  'Cook dinner',
  'Update the roadmap',
  'Board game night',
  'Back up photos',
  'Stretch for ten minutes',
  'Draft the newsletter',
];

/// Builds the nth synthetic task.
Task makeTask(int n) {
  final tags = tagColors.keys.toList();
  final tag = tags[n % tags.length];
  return Task(n, _titles[n % _titles.length], tag, tagColors[tag]!);
}

/// A card for a task.
class TaskCard extends StatelessWidget {
  /// Creates the card.
  const TaskCard({super.key, required this.task, this.trailing});

  /// The task to show.
  final Task task;

  /// Optional trailing widget.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: task.color,
              child: Text('${task.id}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(task.tag,
                      style: TextStyle(color: task.color, fontSize: 12)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ]),
        ),
      ),
    );
  }
}
