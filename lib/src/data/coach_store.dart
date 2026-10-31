import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CoachStore extends ChangeNotifier {
  CoachStore({MethodChannel? channel})
    : channel = channel ?? const MethodChannel('runprogram/coach');
  final MethodChannel channel;
  Map<String, dynamic> state = {'programs': [], 'history': [], 'settings': {}};
  Map<String, dynamic>? runtime;
  String? error;
  bool loaded = false;
  bool busy = false;
  Timer? _poll;
  bool _disposed = false;
  int _generation = 0;
  void stopPolling() {
    _generation++;
    _poll?.cancel();
    _poll = null;
  }

  Map<String, dynamic>? get program {
    final list = (state['programs'] as List? ?? []);
    return list.isEmpty ? null : Map<String, dynamic>.from(list.last as Map);
  }

  Map<String, dynamic> get settings =>
      Map<String, dynamic>.from(state['settings'] as Map? ?? {});
  List<Map<String, dynamic>> get history => (state['history'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  Future<void> initialize() async {
    stopPolling();
    final generation = _generation;
    await refresh();
    if (_disposed || generation != _generation) return;
    _poll = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!busy && runtime != null) refresh();
    });
  }

  Future<void> refresh({bool clearError = false}) async {
    if (clearError) error = null;
    try {
      final raw = await channel.invokeMethod<String>('snapshot');
      final data = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
      if (data != null) {
        state = Map<String, dynamic>.from(data['state'] as Map);
        runtime = data['runtime'] == null
            ? null
            : Map<String, dynamic>.from(data['runtime'] as Map);
        loaded = true;
      }
    } catch (e) {
      error = 'Local storage is unavailable. $e';
    }
    if (!_disposed) notifyListeners();
  }

  Future<bool> command(String method, [Map<String, dynamic>? args]) async {
    if (busy) return false;
    error = null;
    busy = true;
    notifyListeners();
    try {
      await channel.invokeMethod<dynamic>(method, args);
      await refresh();
      return true;
    } on PlatformException catch (e) {
      error = e.message ?? e.code;
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
