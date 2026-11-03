import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:runprogram/src/training/plan.dart';

void main() {
  test('default beginner workout is a 30 minute walk-run session', () {
    final p = PlanGenerator.generate(const PlanRequest());
    expect(p.workouts.length, 30);
    expect(p.workouts.first['seconds'], 1800);
    final steps = p.workouts.first['intervals'] as List;
    expect(steps.first, {'activity': 'warmup', 'seconds': 300});
    expect(steps[1], {'activity': 'run', 'seconds': 60});
    expect(steps[2], {'activity': 'walk', 'seconds': 90});
    expect(steps.last, {'activity': 'cooldown', 'seconds': 300});
  });
  test('all supported goals and timelines have positive consistent totals', () {
    for (final goal in RunningGoal.values) {
      for (final ability in Ability.values) {
        for (var weeks = 8; weeks <= 36; weeks++) {
          final r = PlanRequest(
            goal: goal,
            ability: ability,
            weeks: weeks,
            baseReady: true,
            supportReady: true,
          );
          if (PlanGenerator.concern(r) != null) {
            expect(() => PlanGenerator.generate(r), throwsArgumentError);
            continue;
          }
          final plan = PlanGenerator.generate(r);
          expect(plan.workouts.length, weeks * 3);
          for (final w in plan.workouts) {
            final steps = w['intervals'] as List;
            expect(steps.every((s) => (s['seconds'] as int) > 0), isTrue);
            expect(
              w['seconds'],
              steps.fold<int>(0, (n, s) => n + (s['seconds'] as int)),
            );
            expect(steps.first['activity'], 'warmup');
            expect(steps.last['activity'], 'cooldown');
          }
        }
      }
    }
  });
  test('long-distance ability labels alone do not establish readiness', () {
    expect(
      PlanGenerator.concern(
        const PlanRequest(
          goal: RunningGoal.marathon,
          ability: Ability.experienced,
          weeks: 30,
        ),
      ),
      isNotNull,
    );
    expect(
      PlanGenerator.concern(
        const PlanRequest(
          goal: RunningGoal.half,
          ability: Ability.beginner,
          weeks: 30,
          baseReady: true,
          supportReady: true,
        ),
      ),
      isNotNull,
    );
    expect(
      PlanGenerator.concern(
        const PlanRequest(
          goal: RunningGoal.marathon,
          ability: Ability.intermediate,
          weeks: 30,
          baseReady: true,
          supportReady: true,
        ),
      ),
      isNotNull,
    );
  });
  test('extensions consolidate rather than compress the beginner block', () {
    final p = PlanGenerator.generate(const PlanRequest(weeks: 12));
    expect(p.workouts.length, 36);
    expect(
      p.workouts[27]['intervals'],
      isNot(equals(p.workouts.first['intervals'])),
    );
    expect(
      p.workouts.last['intervals'],
      PlanGenerator.generate(const PlanRequest()).workouts.last['intervals'],
    );
  });
  test('long-distance plans include cutbacks and reserved taper', () {
    for (final goal in [RunningGoal.half, RunningGoal.marathon]) {
      final p = PlanGenerator.generate(
        PlanRequest(
          goal: goal,
          ability: Ability.experienced,
          weeks: PlanGenerator.recommended(goal, Ability.experienced),
          baseReady: true,
          supportReady: true,
        ),
      );
      expect(p.workouts.any((w) => w['role'] == 'Recovery'), isTrue);
      expect(p.workouts.last['role'], 'Taper');
      expect(
        (p.workouts.last['seconds'] as int),
        lessThan(p.workouts[p.workouts.length - 10]['seconds'] as int),
      );
    }
  });
  test('long run stays below half of the weekly running time', () {
    for (final goal in [RunningGoal.half, RunningGoal.marathon]) {
      final p = PlanGenerator.generate(
        PlanRequest(
          goal: goal,
          ability: Ability.experienced,
          weeks: PlanGenerator.recommended(goal, Ability.experienced),
          baseReady: true,
          supportReady: true,
        ),
      );
      for (var i = 0; i < p.workouts.length; i += 3) {
        final minutes = p.workouts
            .sublist(i, i + 3)
            .map((w) => (w['seconds'] as int) - 600)
            .toList();
        expect(minutes[2], lessThanOrEqualTo(minutes[0] + minutes[1]));
      }
    }
  });
  test(
    '60-week 5K distributes gentler interval options across the timeline',
    () {
      final p = PlanGenerator.generate(const PlanRequest(weeks: 60));
      expect(p.workouts.length, 180);
      expect(
        p.workouts.first['intervals'],
        isNot(equals(p.workouts[90]['intervals'])),
      );
      expect(
        p.workouts.last['intervals'],
        PlanGenerator.generate(const PlanRequest()).workouts.last['intervals'],
      );
      expect(
        p.workouts.any((w) {
          final i = w['intervals'] as List;
          return i[1]['seconds'] == 60 && i[2]['seconds'] == 180;
        }),
        isTrue,
      );
      expect(PlanGenerator.concern(const PlanRequest(weeks: 104)), isNull);
    },
  );
  test(
    'maximum custom timelines remain serializable and within native limits',
    () {
      for (final goal in RunningGoal.values) {
        final plan = PlanGenerator.generate(
          PlanRequest(
            goal: goal,
            ability: goal == RunningGoal.fiveK || goal == RunningGoal.tenK
                ? Ability.beginner
                : Ability.experienced,
            weeks: 999,
            baseReady: true,
            supportReady: true,
          ),
        );
        expect(plan.workouts.length, 2997);
        expect(
          (jsonDecode(jsonEncode(plan.toJson('max'))) as Map)['version'],
          2,
        );
        for (final workout in plan.workouts) {
          final steps = workout['intervals'] as List;
          expect(steps.length, inInclusiveRange(1, 200));
          expect(workout['seconds'], lessThanOrEqualTo(21600));
          expect(
            workout['seconds'],
            steps.fold<int>(0, (sum, step) => sum + step['seconds'] as int),
          );
        }
      }
      expect(PlanGenerator.concern(const PlanRequest(weeks: 1000)), isNotNull);
    },
  );
}
