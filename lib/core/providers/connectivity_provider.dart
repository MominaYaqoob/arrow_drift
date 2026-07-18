import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arrow_drift/services/network_status.dart';

/// App-lifetime connectivity state, backing the global [ConnectivityGate]
/// (see connectivity_gate.dart). Single source of truth: one live
/// subscription to [NetworkStatus.onChanged] for the whole app, rather
/// than every screen that cares about connectivity opening its own.
class ConnectivityNotifier extends StateNotifier<bool> {
  ConnectivityNotifier() : super(true) {
    _init();
  }

  StreamSubscription<bool>? _sub;

  Future<void> _init() async {
    state = await _safeCheck();
    _sub = NetworkStatus.instance.onChanged.listen((isOnline) {
      state = isOnline;
    });
  }

  Future<bool> _safeCheck() async {
    try {
      return await NetworkStatus.instance.isOnline();
    } catch (_) {
      // Same policy as NetworkStatus itself: a broken *check* shouldn't
      // permanently lock the player out — assume online, and let the
      // live stream correct it on the next real change.
      return true;
    }
  }

  /// Manual re-check for the global gate's Retry button.
  Future<void> retry() async {
    state = await _safeCheck();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Not `.autoDispose` — this must stay alive for the whole app session so
/// connectivity is monitored continuously, not just while some particular
/// screen happens to be on screen.
final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>(
  (ref) => ConnectivityNotifier(),
);
