import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runprogram/src/app.dart';

void main() {
  testWidgets('launches the app foundation', (tester) async {
    await tester.pumpWidget(const RunProgramApp());
    expect(find.text('RUN//PROGRAM'), findsOneWidget);
    expect(find.text('Hello World'), findsOneWidget);
    expect(find.text('SYSTEM ONLINE'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('small screen supports large text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const RunProgramApp());
    await tester.ensureVisible(find.text('Hello World'));
    expect(tester.takeException(), isNull);
  });
}
