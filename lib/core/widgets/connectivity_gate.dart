import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arrow_drift/core/providers/connectivity_provider.dart';
import 'package:arrow_drift/core/widgets/no_internet_view.dart';

/// App-wide connectivity gate. Wrap the router's routed content with this
/// (via `MaterialApp.router`'s `builder`) so that regardless of which
/// screen is currently showing — including mid-gameplay — losing
/// connectivity immediately covers the **entire** screen with a blocking,
/// opaque "No Internet Connection" view with a Retry button.
///
/// This is a pure `Stack` overlay, not a route change: [child] (the
/// current screen) is never disposed, rebuilt away, or navigated from.
/// Its Timers/AnimationControllers keep existing underneath (just
/// visually and interactively covered), so once connectivity returns and
/// the overlay is dismissed, the player is back exactly where they left
/// off — same board, same puzzle state, nothing reset.
///
/// Touch-blocking is automatic here: the overlay is opaque and sits on
/// top in the `Stack`, so there is no gap in the hit-test area for taps
/// to reach the game board underneath while it's showing.
class ConnectivityGate extends ConsumerStatefulWidget {
  const ConnectivityGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends ConsumerState<ConnectivityGate> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await ref.read(connectivityProvider.notifier).retry();
    if (!mounted) return;
    setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider);
    return Stack(
      children: [
        widget.child,
        if (!online)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: NoInternetBlockingView(
                retrying: _retrying,
                onRetry: _retry,
                title: 'Connection Lost',
                subtitle:
                    'Please reconnect to continue. Your game is paused and will resume when you are back online.',
              ),
            ),
          ),
      ],
    );
  }
}
