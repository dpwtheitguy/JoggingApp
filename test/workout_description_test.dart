import 'package:flutter_test/flutter_test.dart';
import 'package:runprogram/src/training/workout_description.dart';

void main() {
  test(
    'writes repeated run/walk intervals clearly without losing durations',
    () {
      final workout = {
        'seconds': 1080,
        'intervals': [
          {'activity': 'warmup', 'seconds': 300},
          for (var i = 0; i < 2; i++) ...[
            {'activity': 'run', 'seconds': 60},
            {'activity': 'walk', 'seconds': 180},
          ],
          {'activity': 'cooldown', 'seconds': 300},
        ],
      };
      expect(workoutInstructions(workout), [
        'Warm up: walk for 5 minutes.',
        'Run 1 minute, then walk 3 minutes; repeat 2 times.',
        'Cool down: walk for 5 minutes.',
        'Total workout: 18 minutes.',
      ]);
    },
  );
  test('mixed intervals are described in their actual order', () {
    final lines = workoutInstructions({
      'seconds': 195,
      'intervals': [
        {'activity': 'run', 'seconds': 45},
        {'activity': 'walk', 'seconds': 90},
        {'activity': 'run', 'seconds': 60},
      ],
    });
    expect(lines[0], 'Run 45 seconds, then walk 1 minute 30 seconds.');
    expect(lines[1], 'Run for 1 minute.');
  });
}
