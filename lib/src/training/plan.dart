enum RunningGoal {
  fiveK('5K', 5),
  tenK('10K', 10),
  half('Half Marathon', 21.1),
  marathon('Marathon', 42.2);

  const RunningGoal(this.label, this.km);
  final String label;
  final double km;
}

enum Ability { beginner, intermediate, experienced }

class PlanRequest {
  const PlanRequest({
    this.goal = RunningGoal.fiveK,
    this.ability = Ability.beginner,
    this.weeks = 10,
    this.baseReady = false,
    this.supportReady = false,
  });
  final RunningGoal goal;
  final Ability ability;
  final int weeks;
  final bool baseReady, supportReady;
}

class TrainingPlan {
  const TrainingPlan(this.request, this.workouts);
  final PlanRequest request;
  final List<Map<String, dynamic>> workouts;
  Map<String, dynamic> toJson(String id) => {
    'id': id,
    'goal': request.goal.name,
    'ability': request.ability.name,
    'weeks': request.weeks,
    'version': 2,
    'cursor': 0,
    'replay': <int>[],
    'paused': false,
    'created': DateTime.now().toUtc().toIso8601String(),
    'workouts': workouts,
  };
}

abstract final class PlanGenerator {
  static int minimum(RunningGoal goal, Ability ability) => switch (goal) {
    RunningGoal.fiveK => ability == Ability.beginner ? 10 : 8,
    RunningGoal.tenK => ability == Ability.beginner ? 18 : 10,
    RunningGoal.half => ability == Ability.experienced ? 16 : 20,
    RunningGoal.marathon => 24,
  };
  static int recommended(RunningGoal goal, Ability ability) => switch (goal) {
    RunningGoal.fiveK => 10,
    RunningGoal.tenK => ability == Ability.beginner ? 18 : 12,
    RunningGoal.half => ability == Ability.experienced ? 16 : 20,
    RunningGoal.marathon => 30,
  };
  static String? concern(PlanRequest r) {
    if (r.weeks < minimum(r.goal, r.ability)) {
      return 'Choose at least ${minimum(r.goal, r.ability)} weeks. Longer timelines are welcome; recovery is never compressed.';
    }
    if (r.weeks > 999) return 'Enter up to 999 weeks for a single program.';
    if (r.goal == RunningGoal.half || r.goal == RunningGoal.marathon) {
      if (r.ability == Ability.beginner ||
          (r.goal == RunningGoal.marathon &&
              r.ability != Ability.experienced)) {
        return 'Build a consistent running base first. Initialize a 5K or 10K foundation, then reassess your longer-distance goal.';
      }
      if (!r.baseReady || !r.supportReady) {
        return 'Confirm the running-base and supporting-activity prerequisites, or choose a shorter foundation goal.';
      }
    }
    return null;
  }

  // Original time-based curriculum, not a measured-distance prediction.
  // Repeated foundation weeks extend a template; build and taper are never compressed.
  static TrainingPlan generate(PlanRequest r) {
    final issue = concern(r);
    if (issue != null) throw ArgumentError(issue);
    final baseline = minimum(r.goal, r.ability);
    final workouts = <Map<String, dynamic>>[];
    for (var w = 0; w < r.weeks; w++) {
      // Distribute consolidation across the build rather than front-loading
      // dozens of identical opening weeks. Keep taper at the end.
      final taperWeeks =
          r.ability == Ability.beginner && r.goal == RunningGoal.fiveK
          ? 0
          : r.goal == RunningGoal.marathon
          ? 3
          : 2;
      final buildWeeks = baseline - taperWeeks;
      final requestedBuildWeeks = r.weeks - taperWeeks;
      final t = w < requestedBuildWeeks
          ? (w * buildWeeks ~/ requestedBuildWeeks).clamp(0, buildWeeks - 1)
          : baseline - (r.weeks - w);
      final beginner = r.ability == Ability.beginner;
      final foundation = beginner && t < 10;
      final taper =
          !foundation &&
          w >= r.weeks - (r.goal == RunningGoal.marathon ? 3 : 2);
      final recovery = !foundation && !taper && (t + 1) % 4 == 0;
      for (var s = 0; s < 3; s++) {
        final intervals = <Map<String, dynamic>>[];
        void add(String activity, int seconds) =>
            intervals.add({'activity': activity, 'seconds': seconds});
        add('warmup', 300);
        if (foundation) {
          // Expanded run/walk ladder for longer, gentler programs. The
          // ten-week default keeps its established stages; extended programs
          // include short running bouts and longer walking recoveries.
          const standard = [
            (60, 90, 8),
            (90, 90, 7),
            (120, 90, 6),
            (180, 90, 5),
            (240, 90, 4),
            (300, 60, 4),
            (480, 60, 3),
            (600, 60, 2),
            (900, 60, 2),
            (1800, 0, 1),
          ];
          const gentle = [
            (30, 180, 6),
            (45, 180, 6),
            (60, 180, 6),
            (60, 150, 7),
            (60, 120, 8),
            (60, 90, 8),
            (90, 120, 6),
            (90, 90, 7),
            (120, 120, 6),
            (120, 90, 6),
            (180, 120, 5),
            (180, 90, 5),
            (240, 120, 4),
            (240, 90, 4),
            (300, 90, 4),
            (300, 60, 4),
            (480, 90, 3),
            (480, 60, 3),
            (600, 60, 2),
            (900, 60, 2),
            (1800, 0, 1),
          ];
          final stages = r.weeks >= 20 ? gentle : standard;
          final foundationWeeks = r.goal == RunningGoal.fiveK
              ? r.weeks
              : (10 * requestedBuildWeeks / buildWeeks).ceil();
          final stageIndex = (w * (stages.length - 1) ~/ (foundationWeeks - 1))
              .clamp(0, stages.length - 1);
          final (run, walk, repeats) = stages[stageIndex];
          for (var n = 0; n < repeats; n++) {
            add('run', run);
            if (walk > 0) add('walk', walk);
          }
        } else {
          final buildIndex = beginner ? t - 10 : t;
          final long = s == 2;
          final start = switch (r.goal) {
            RunningGoal.fiveK => 25,
            RunningGoal.tenK => 30,
            RunningGoal.half => 45,
            RunningGoal.marathon => 75,
          };
          final cap = switch (r.goal) {
            RunningGoal.fiveK => 35,
            RunningGoal.tenK => 65,
            RunningGoal.half => 120,
            RunningGoal.marathon => 180,
          };
          final peak = (start + buildIndex * 5).clamp(start, cap);
          // Supporting running volume grows with the long run; do not let
          // three-day schedules collapse into one disproportionately long day.
          var minutes = long
              ? peak
              : (peak * (s == 0 ? .6 : .5)).round().clamp(20, 120);
          if (recovery) minutes = (minutes * .75).round();
          if (taper) {
            final remaining = r.weeks - w;
            minutes =
                (minutes *
                        (remaining == 1
                            ? .45
                            : remaining == 2
                            ? .6
                            : .75))
                    .round();
          }
          add('run', minutes * 60);
        }
        add('cooldown', 300);
        workouts.add({
          'id': 'w${w + 1}s${s + 1}',
          'week': w + 1,
          'session': s + 1,
          'role': foundation
              ? 'Run / walk foundation'
              : taper
              ? 'Taper'
              : recovery
              ? 'Recovery'
              : s == 2
              ? 'Long easy run'
              : s == 0
              ? 'Easy run'
              : 'Recovery run',
          'intervals': intervals,
          'seconds': intervals.fold<int>(
            0,
            (sum, i) => sum + (i['seconds'] as int),
          ),
        });
      }
    }
    return TrainingPlan(r, workouts);
  }
}

String durationLabel(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
String activityLabel(String value) => switch (value) {
  'warmup' => 'WARM-UP',
  'cooldown' => 'COOLDOWN',
  'walk' => 'WALK',
  _ => 'RUN',
};
