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
    expect(find.text('INITIALIZE PROGRAM'), findsOneWidget);
    await tester.ensureVisible(find.text('INITIALIZE PROGRAM'));
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
}
