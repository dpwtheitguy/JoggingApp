import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runprogram/src/data/coach_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('runprogram/store-test');
  late CoachStore store;
  late Map<String, dynamic> runtime;
  late Map<String, dynamic> state;
  late List<String> calls;
  Future<Object?> Function(MethodCall)? custom;
  setUp(() {
    store = CoachStore(channel: channel);
    runtime = {'attemptId': 'a', 'status': 'running', 'elapsedMs': 0};
    state = {'programs': [], 'history': [], 'settings': {}};
    calls = [];
    custom = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (custom != null) return custom!(call);
          return switch (call.method) {
            'snapshot' => jsonEncode({'state': state, 'runtime': runtime}),
            'runtimeSnapshot' => jsonEncode(runtime),
            _ => null,
          };
        });
  });
  tearDown(() {
    store.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('timer updates avoid reloading full plans and history', (
    tester,
  ) async {
    await store.initialize();
    for (var second = 1; second <= 3; second++) {
      runtime['elapsedMs'] = second * 1000;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }
    expect(calls.where((call) => call == 'snapshot').length, 1);
    expect(calls.where((call) => call == 'runtimeSnapshot').length, 3);
    expect(store.runtime?['elapsedMs'], 3000);
    store.stopPolling();
  });

  testWidgets('completion refreshes progress once and stops polling', (
    tester,
  ) async {
    await store.initialize();
    runtime['status'] = 'completed';
    state['history'] = [
      {'id': 'a'},
    ];
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(store.history.length, 1);
    expect(calls.where((call) => call == 'snapshot').length, 2);
    await tester.pump(const Duration(seconds: 3));
    expect(calls.where((call) => call == 'runtimeSnapshot').length, 1);
    store.stopPolling();
  });

  testWidgets('a stale in-flight poll cannot undo a pause command', (
    tester,
  ) async {
    await store.initialize();
    final delayed = Completer<Object?>();
    custom = (call) async {
      if (call.method == 'runtimeSnapshot') return delayed.future;
      if (call.method == 'pause') runtime['status'] = 'paused';
      if (call.method == 'snapshot') {
        return jsonEncode({'state': state, 'runtime': runtime});
      }
      return null;
    };
    await tester.pump(const Duration(seconds: 1));
    expect(await store.command('pause'), isTrue);
    delayed.complete(
      jsonEncode({'attemptId': 'a', 'status': 'running', 'elapsedMs': 1000}),
    );
    await tester.pump();
    expect(store.runtime?['status'], 'paused');
    store.stopPolling();
  });

  testWidgets('backgrounding discards late polling responses', (tester) async {
    await store.initialize();
    final delayed = Completer<Object?>();
    custom = (_) => delayed.future;
    await tester.pump(const Duration(seconds: 1));
    store.stopPolling();
    delayed.complete(
      jsonEncode({'attemptId': 'a', 'status': 'running', 'elapsedMs': 9999}),
    );
    await tester.pump();
    expect(store.runtime?['elapsedMs'], 0);
    final count = calls.length;
    await tester.pump(const Duration(seconds: 5));
    expect(calls.length, count);
  });

  testWidgets('failed post-command snapshot is not reported as success', (
    tester,
  ) async {
    await store.initialize();
    custom = (call) async {
      if (call.method == 'snapshot') {
        throw PlatformException(code: 'STORAGE', message: 'Unavailable');
      }
      return null;
    };
    expect(await store.command('pause'), isFalse);
    expect(store.error, contains('Local storage is unavailable'));
    expect(store.busy, isFalse);
    store.stopPolling();
  });

  testWidgets('slow bridge polling does not accumulate overlapping requests', (
    tester,
  ) async {
    await store.initialize();
    final delayed = Completer<Object?>();
    custom = (_) => delayed.future;
    await tester.pump(const Duration(seconds: 5));
    expect(calls.where((call) => call == 'runtimeSnapshot').length, 1);
    delayed.complete(jsonEncode(runtime));
    await tester.pump();
    store.stopPolling();
  });
}
