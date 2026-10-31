import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runprogram/src/screens/history_screen.dart';
import 'package:runprogram/src/theme/app_theme.dart';

Map<String, dynamic> savedAttempt({String status = 'modified_confirmed'}) => {
  'id': 'attempt-1',
  'programId': 'old-program',
  'status': status,
  'mode': 'week',
  'date': '2026-10-30T18:00:00Z',
  'elapsedMs': 315000,
  'skippedMs': 45000,
  'skips': [
    {'intervalIndex': 1, 'skippedMs': 45000},
  ],
  'reportedKm': 0.8,
  'workout': {
    'id': 'w2s3',
    'week': 2,
    'session': 3,
    'role': 'Saved walk/run workout',
    'seconds': 360,
    'intervals': [
      {'activity': 'warmup', 'seconds': 60},
      {'activity': 'run', 'seconds': 75},
      {'activity': 'walk', 'seconds': 165},
      {'activity': 'cooldown', 'seconds': 60},
    ],
  },
};

Widget historyApp(List<Map<String, dynamic>> attempts) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: WorkoutHistory(
      attempts: attempts,
      programs: const [
        {'id': 'old-program', 'goal': 'fiveK', 'weeks': 60},
        {'id': 'current-program', 'goal': 'tenK', 'weeks': 18},
      ],
    ),
  ),
);

void main() {
  testWidgets('opens the archived prescription and recorded skip details', (
    tester,
  ) async {
    await tester.pumpWidget(historyApp([savedAttempt()]));
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('Workout details'), findsOneWidget);
    expect(find.text('5K · 60-week program'), findsOneWidget);
    expect(find.text('Repeated week'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Run 1 minute 15 seconds, then walk 2 minutes 45 seconds.'),
      250,
    );
    await tester.scrollUntilVisible(
      find.text('Interval 2: Run for 1 minute 15 seconds. Skipped 45 seconds.'),
      250,
    );
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Workout history'), findsOneWidget);
  });

  testWidgets('shows actual time separately from skips and reported distance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: WorkoutAttemptDetails(
          attempt: savedAttempt(),
          programLabel: '5K · 60-week program',
        ),
      ),
    );
    expect(find.text('Active exercise: 5 minutes 15 seconds.'), findsOneWidget);
    expect(find.text('Prescribed workout: 6 minutes.'), findsOneWidget);
    expect(
      find.text(
        'Skipped: 45 seconds. Skipped time is not recorded as exercise.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Distance: 0.8 km · reported by you, not measured by the app.'),
      200,
    );
    expect(
      find.text(
        'You chose to count this modified workout toward your program. The skipped time remains recorded.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('history remains lazy with thousands of retained attempts', (
    tester,
  ) async {
    final attempts = List.generate(
      3000,
      (i) => {...savedAttempt(), 'id': 'attempt-$i'},
    );
    await tester.pumpWidget(historyApp(attempts));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile).evaluate().length, lessThan(20));
    expect(find.byKey(const ValueKey('attempt-2999')), findsOneWidget);
    expect(find.byKey(const ValueKey('attempt-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy stopped attempts fit a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final attempt = savedAttempt(status: 'stopped')
      ..remove('skips')
      ..remove('skippedMs')
      ..remove('reportedKm');
    await tester.pumpWidget(historyApp([attempt]));
    final title = find.textContaining('Week 2 · Day 3 ·');
    await tester.scrollUntilVisible(title, 200);
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('This attempt stopped early and did not advance your program.'),
      250,
    );
    expect(find.text('Skipped intervals'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Total workout: 6 minutes.'),
      250,
    );
    expect(tester.takeException(), isNull);
  });
}
