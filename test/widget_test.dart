import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runprogram/src/app.dart';
import 'package:runprogram/src/data/coach_store.dart';
import 'package:runprogram/src/training/plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('runprogram/coach');
  late Map<String, dynamic> state;
  Map<String, dynamic>? runtime;
  late CoachStore store;
  setUp(() {
    state = {
      'programs': <dynamic>[],
      'history': <dynamic>[],
      'settings': {'rain': false},
    };
    runtime = null;
    store = CoachStore(channel: channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'snapshot':
              return jsonEncode({'state': state, 'runtime': runtime});
            case 'newProgram':
              (state['programs'] as List).add(
                Map<String, dynamic>.from(call.arguments as Map),
              );
              return null;
            case 'skip':
              runtime?['intervalIndex'] = 1;
              runtime?['remainingMs'] = 60000;
              runtime?['skippedMs'] = 300000;
              return null;
            case 'settings':
              state['settings'] = call.arguments;
              return null;
            case 'start':
              runtime = {
                ...Map<String, dynamic>.from(call.arguments as Map),
                'status': 'running',
                'elapsedMs': 0,
                'intervalIndex': 0,
                'remainingMs': 300000,
              };
              return null;
            default:
              return null;
          }
        });
  });
  tearDown(() {
    store.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets('defaults initialize and start with two actions', (tester) async {
    await tester.pumpWidget(RunProgramApp(store: store));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('INITIALIZE PROGRAM'), 250);
    await tester.tap(find.text('INITIALIZE PROGRAM'));
    await tester.pumpAndSettle();
    expect(find.text('Start Workout'), findsOneWidget);
    await tester.tap(find.text('Start Workout'));
    await tester.pumpAndSettle();
    expect(find.text('WARM-UP'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('returning user starts directly from Home', (tester) async {
    (state['programs'] as List).add(
      PlanGenerator.generate(const PlanRequest()).toJson('test'),
    );
    await tester.pumpWidget(RunProgramApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Workout'));
    await tester.pumpAndSettle();
    expect(find.text('End Workout'), findsOneWidget);
    await tester.tap(find.text('End Workout'));
    await tester.pumpAndSettle();
    expect(find.text('End workout?'), findsOneWidget);
    expect(runtime?['status'], 'running');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(runtime?['status'], 'running');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('small viewport and 200 percent text do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(RunProgramApp(store: store));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('INITIALIZE PROGRAM'), 300);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('week view shows all three days and the written prescription', (
    tester,
  ) async {
    (state['programs'] as List).add(
      PlanGenerator.generate(const PlanRequest(weeks: 60)).toJson('long-plan'),
    );
    await tester.pumpWidget(RunProgramApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Week 1 · Day 1'), findsOneWidget);
    await tester.tap(find.text('Program'));
    await tester.pumpAndSettle();
    expect(find.text('Week 1 of 60'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Day 2'), findsOneWidget);
    expect(find.text('Day 3'), findsOneWidget);
    expect(
      find.text('Run 30 seconds, then walk 3 minutes; repeat 6 times.'),
      findsNWidgets(3),
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('player exposes skip and a complete written workout', (
    tester,
  ) async {
    (state['programs'] as List).add(
      PlanGenerator.generate(const PlanRequest()).toJson('test'),
    );
    await tester.pumpWidget(RunProgramApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Workout'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Skip Interval'));
    await tester.tap(find.text('Skip Interval'));
    await tester.pumpAndSettle();
    expect(runtime?['intervalIndex'], 1);
    await tester.scrollUntilVisible(find.text('RUN'), -250);
    expect(find.text('RUN'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Run 1 minute, then walk 1 minute 30 seconds; repeat 8 times.'),
      250,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('custom timeline entry initializes a 60-week program', (
    tester,
  ) async {
    await tester.pumpWidget(RunProgramApp(store: store));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Enter another number of weeks'),
      200,
    );
    await tester.tap(find.text('Enter another number of weeks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '60');
    await tester.tap(find.text('Use timeline'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('INITIALIZE PROGRAM'), 250);
    await tester.tap(find.text('INITIALIZE PROGRAM'));
    await tester.pumpAndSettle();
    expect((state['programs'] as List).last['weeks'], 60);
    expect(((state['programs'] as List).last['workouts'] as List).length, 180);
    await tester.pumpWidget(const SizedBox());
  });
}
