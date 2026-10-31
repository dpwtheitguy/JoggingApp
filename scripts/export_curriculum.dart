import 'dart:io';

import 'package:runprogram/src/training/plan.dart';
import 'package:runprogram/src/training/workout_description.dart';

void main() {
  final out = StringBuffer(
    '# Generated curriculum samples\n\nDevelopment definitions for review; not validated prescriptions. Times include five-minute warm-up and cooldown in each session. Regenerate with `dart run scripts/export_curriculum.dart`.\n',
  );
  final requests = [
    for (final goal in RunningGoal.values)
      (
        goal,
        goal == RunningGoal.marathon
            ? Ability.experienced
            : goal == RunningGoal.half
            ? Ability.intermediate
            : Ability.beginner,
        0,
      ),
    (RunningGoal.fiveK, Ability.beginner, 60),
  ];
  for (final (goal, ability, requestedWeeks) in requests) {
    final weeks = requestedWeeks == 0
        ? PlanGenerator.recommended(goal, ability)
        : requestedWeeks;
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
      '| Week | Day 1 | Day 2 | Day 3 | Weekly time | Day 3 prescription |\n|---|---|---|---|---|---|',
    );
    for (var i = 0; i < p.workouts.length; i += 3) {
      final w = p.workouts.sublist(i, i + 3);
      final durations = w
          .map((s) => durationLabel(s['seconds'] as int))
          .toList();
      out.writeln(
        '| ${i ~/ 3 + 1} | ${durations[0]} | ${durations[1]} | ${durations[2]} | ${durationLabel(w.fold<int>(0, (n, s) => n + (s['seconds'] as int)))} | ${workoutSummary(w.last)} |',
      );
    }
  }
  File('docs/CURRICULUM-SAMPLES.md').writeAsStringSync(out.toString());
}
