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
  int _commandRevision = 0;
  bool _polling = false;
  static const _terminal = {
    'completed',
    'stopped',
    'modified',
    'modified_confirmed',
  };
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
      if (!busy && runtime != null && !_terminal.contains(runtime!['status'])) {
        unawaited(_refreshRuntime());
      }
    });
  }

  Future<bool> refresh({bool clearError = false}) async {
    final generation = _generation;
    final revision = _commandRevision;
    if (clearError) error = null;
    try {
      final raw = await channel.invokeMethod<String>('snapshot');
      if (_disposed ||
          generation != _generation ||
          revision != _commandRevision) {
        return false;
      }
      if (raw == null) throw const FormatException('Empty local snapshot');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final nextState = Map<String, dynamic>.from(data['state'] as Map);
      final nextRuntime = data['runtime'] == null
          ? null
          : Map<String, dynamic>.from(data['runtime'] as Map);
      state = nextState;
      runtime = nextRuntime;
      loaded = true;
      notifyListeners();
      return true;
    } catch (e) {
      if (_disposed ||
          generation != _generation ||
          revision != _commandRevision) {
        return false;
      }
      error = 'Local storage is unavailable. $e';
    }
    if (!_disposed) notifyListeners();
    return false;
  }

  // A workout tick needs only the current attempt. Plans and historical
  // definitions can be large; reload them only on commands or completion.
  Future<void> _refreshRuntime() async {
    if (_polling || busy || _disposed) return;
    _polling = true;
    final generation = _generation;
    final revision = _commandRevision;
    try {
      final raw = await channel.invokeMethod<String>('runtimeSnapshot');
      if (_disposed ||
          busy ||
          generation != _generation ||
          revision != _commandRevision) {
        return;
      }
      final next = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
      if (next == null ||
          _terminal.contains(next['status']) ||
          next['attemptId'] != runtime?['attemptId']) {
        await refresh();
      } else {
        runtime = next;
        notifyListeners();
      }
    } catch (e) {
      if (!_disposed &&
          generation == _generation &&
          revision == _commandRevision) {
        error = 'Workout status is unavailable. Retry to reconnect.';
        notifyListeners();
      }
    } finally {
      _polling = false;
    }
  }

  Future<bool> command(String method, [Map<String, dynamic>? args]) async {
    if (busy || _disposed) return false;
    _commandRevision++;
    error = null;
    busy = true;
    notifyListeners();
    try {
      await channel.invokeMethod<dynamic>(method, args);
      return await refresh();
    } on PlatformException catch (e) {
      error = e.message ?? e.code;
      return false;
    } catch (e) {
      error = 'Workout operation failed. $e';
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
