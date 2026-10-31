import 'dart:io';

import 'package:runprogram/src/training/plan.dart';

void main() {
  final out = StringBuffer(
    '# Generated curriculum samples\n\nDevelopment definitions for review; not validated prescriptions. Times include five-minute warm-up and cooldown in each session. Regenerate with `dart run scripts/export_curriculum.dart`.\n',
  );
  for (final goal in RunningGoal.values) {
    final ability = goal == RunningGoal.marathon
        ? Ability.experienced
        : goal == RunningGoal.half
        ? Ability.intermediate
        : Ability.beginner;
    final weeks = PlanGenerator.recommended(goal, ability);
    final p = PlanGenerator.generate(
      PlanRequest(
        goal: goal,
        ability: ability,
        weeks: weeks,
        baseReady: true,
        supportReady: true,
      ),
    );
    out.writeln('\n## ${goal.label} · ${ability.name} · $weeks weeks\n');
    out.writeln(
      '| Week | Session 1 | Session 2 | Session 3 | Weekly time | Role |\n|---|---|---|---|---|---|',
    );
    for (var i = 0; i < p.workouts.length; i += 3) {
      final w = p.workouts.sublist(i, i + 3);
      final durations = w
          .map((s) => durationLabel(s['seconds'] as int))
          .toList();
      out.writeln(
        '| ${i ~/ 3 + 1} | ${durations[0]} | ${durations[1]} | ${durations[2]} | ${durationLabel(w.fold<int>(0, (n, s) => n + (s['seconds'] as int)))} | ${w.last['role']} |',
      );
    }
  }
  File('docs/CURRICULUM-SAMPLES.md').writeAsStringSync(out.toString());
}
