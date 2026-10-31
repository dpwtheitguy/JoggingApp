/// Text is derived from actual intervals, so archived and current programs
/// always show their own exact prescription rather than a regenerated guess.
String writtenDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  final parts = <String>[];
  if (minutes > 0) parts.add('$minutes ${minutes == 1 ? 'minute' : 'minutes'}');
  if (remainder > 0 || parts.isEmpty) {
    parts.add('$remainder ${remainder == 1 ? 'second' : 'seconds'}');
  }
  return parts.join(' ');
}

String stepInstruction(Map step) {
  final action = switch (step['activity']) {
    'warmup' => 'Warm up: walk',
    'cooldown' => 'Cool down: walk',
    'walk' => 'Walk',
    _ => 'Run',
  };
  return '$action for ${writtenDuration(step['seconds'] as int)}';
}

List<String> workoutInstructions(Map workout) {
  final steps = (workout['intervals'] as List).cast<Map>();
  final lines = <String>[];
  var i = 0;
  while (i < steps.length) {
    if (steps[i]['activity'] == 'run' &&
        i + 1 < steps.length &&
        steps[i + 1]['activity'] == 'walk') {
      final run = steps[i]['seconds'];
      final walk = steps[i + 1]['seconds'];
      var rounds = 1;
      while (i + rounds * 2 + 1 < steps.length &&
          steps[i + rounds * 2]['activity'] == 'run' &&
          steps[i + rounds * 2]['seconds'] == run &&
          steps[i + rounds * 2 + 1]['activity'] == 'walk' &&
          steps[i + rounds * 2 + 1]['seconds'] == walk) {
        rounds++;
      }
      lines.add(
        'Run ${writtenDuration(run as int)}, then walk ${writtenDuration(walk as int)}${rounds > 1 ? '; repeat $rounds times' : ''}.',
      );
      i += rounds * 2;
    } else {
      lines.add('${stepInstruction(steps[i])}.');
      i++;
    }
  }
  lines.add('Total workout: ${writtenDuration(workout['seconds'] as int)}.');
  return lines;
}

String workoutSummary(Map workout) {
  final lines = workoutInstructions(workout);
  final main = lines
      .where((line) => line.startsWith('Run ') || line.startsWith('Walk '))
      .toList();
  return main.isEmpty ? lines.first : main.join(' ');
}
