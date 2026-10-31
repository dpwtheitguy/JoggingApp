import 'package:flutter/material.dart';

import '../training/plan.dart';
import '../training/workout_description.dart';

String attemptResultLabel(String status) => switch (status) {
  'completed' => 'Completed',
  'stopped' => 'Stopped early',
  'modified' => 'Finished with skips',
  'modified_confirmed' => 'Finished with skips · progression confirmed',
  'interrupted' => 'Interrupted',
  _ => 'Saved attempt',
};

String _attemptMode(Map attempt) => switch (attempt['mode']) {
  'week' => 'Repeated week',
  'repeat' => 'Repeated workout',
  _ => 'Scheduled workout',
};

String _attemptDate(BuildContext context, Map attempt) {
  final date = DateTime.tryParse(attempt['date'] as String? ?? '')?.toLocal();
  if (date == null) return 'Date unavailable';
  final labels = MaterialLocalizations.of(context);
  return '${labels.formatMediumDate(date)} · ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

String _programLabel(List<Map<String, dynamic>> programs, String id) {
  for (final program in programs) {
    if (program['id'] == id) {
      final goal = RunningGoal.values.byName(program['goal'] as String);
      return '${goal.label} · ${program['weeks']}-week program';
    }
  }
  return 'Previous training program';
}

/// Builds rows on demand, including for multi-year programs and retained repeats.
class WorkoutHistory extends StatelessWidget {
  const WorkoutHistory({
    super.key,
    required this.attempts,
    required this.programs,
  });
  final List<Map<String, dynamic>> attempts;
  final List<Map<String, dynamic>> programs;

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(24),
    itemCount: attempts.length + 1,
    itemBuilder: (context, index) {
      if (index == 0) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workout history',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const Text(
                'Every attempt stays here, including repeats and workouts stopped early. Tap an attempt to review the full workout.',
              ),
              if (attempts.isEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'No attempts yet. Start your first sequence from Home.',
                ),
              ],
            ],
          ),
        );
      }
      final attempt = attempts[attempts.length - index];
      final workout = attempt['workout'] as Map;
      final program = _programLabel(programs, attempt['programId'] as String);
      return Card(
        key: ValueKey(attempt['id'] as String),
        child: ListTile(
          title: Text(
            'Week ${workout['week']} · Day ${workout['session']} · ${attemptResultLabel(attempt['status'] as String)}',
          ),
          subtitle: Text(
            '${_attemptDate(context, attempt)}\n${writtenDuration((attempt['elapsedMs'] as num).toInt() ~/ 1000)} active · ${_attemptMode(attempt)}\n$program',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => WorkoutAttemptDetails(
                attempt: attempt,
                programLabel: program,
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Reads the saved definition, never today's generator or the active program.
class WorkoutAttemptDetails extends StatelessWidget {
  const WorkoutAttemptDetails({
    super.key,
    required this.attempt,
    required this.programLabel,
  });
  final Map<String, dynamic> attempt;
  final String programLabel;

  @override
  Widget build(BuildContext context) {
    final workout = attempt['workout'] as Map;
    final steps = (workout['intervals'] as List).cast<Map>();
    final status = attempt['status'] as String;
    final skipped = (attempt['skippedMs'] as num? ?? 0).toInt();
    final skipEvents = (attempt['skips'] as List? ?? []).cast<Map>();
    final heading = Theme.of(context).textTheme.headlineSmall;
    final content = <Widget>[
      Text(
        'Week ${workout['week']} · Day ${workout['session']}',
        style: heading,
      ),
      Text(attemptResultLabel(status)),
      Text(programLabel),
      Text(_attemptDate(context, attempt)),
      Text(_attemptMode(attempt)),
      Text('${workout['role']}'),
      Text(
        'Active exercise: ${writtenDuration((attempt['elapsedMs'] as num).toInt() ~/ 1000)}.',
      ),
      Text(
        'Prescribed workout: ${writtenDuration(workout['seconds'] as int)}.',
      ),
      if (skipped > 0)
        Text(
          'Skipped: ${writtenDuration((skipped + 999) ~/ 1000)}. Skipped time is not recorded as exercise.',
        ),
      Text(switch (status) {
        'completed' => 'The full prescribed workout was completed. No distance was measured.',
        'modified_confirmed' => 'You chose to count this modified workout toward your program. The skipped time remains recorded.',
        'modified' =>
          'This workout ended with skips and did not advance your program.',
        'stopped' =>
          'This attempt stopped early and did not advance your program.',
        _ => 'This saved attempt does not establish completion of the prescribed workout.',
      }),
      if (attempt['reportedKm'] != null)
        Text(
          'Distance: ${attempt['reportedKm']} km · reported by you, not measured by the app.',
        ),
      Text('Full workout', style: heading),
      for (final instruction in workoutInstructions(workout)) Text(instruction),
      if (skipEvents.isNotEmpty) ...[
        Text('Skipped intervals', style: heading),
        for (final event in skipEvents)
          Builder(
            builder: (_) {
              final index = (event['intervalIndex'] as num).toInt();
              final omitted =
                  ((event['skippedMs'] as num).toInt() + 999) ~/ 1000;
              final instruction = index >= 0 && index < steps.length
                  ? stepInstruction(steps[index])
                  : 'Saved interval';
              return Text(
                'Interval ${index + 1}: $instruction. Skipped ${writtenDuration(omitted)}.',
              );
            },
          ),
      ],
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Workout details')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: content.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (_, index) => content[index],
        ),
      ),
    );
  }
}
