import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arrow_drift/core/providers/connectivity_provider.dart';
import 'package:arrow_drift/core/widgets/no_internet_view.dart';
import 'package:arrow_drift/services/network_status.dart';

/// Returns true when the device reports a network. On failure, treats as
/// offline so we never launch network-dependent gameplay by accident.
Future<bool> requireOnline(WidgetRef ref) async {
  try {
    final online = await NetworkStatus.instance.isOnline();
    if (!online) {
      // Keep the global gate in sync so the overlay appears immediately.
      await ref.read(connectivityProvider.notifier).retry();
    }
    return online;
  } catch (_) {
    await ref.read(connectivityProvider.notifier).retry();
    return false;
  }
}

/// Full-screen blocking dialog used when the player tries to start a level
/// / daily while already offline (before the gameplay route is pushed).
Future<void> showNoInternetDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      var retrying = false;
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog.fullscreen(
            backgroundColor: Colors.transparent,
            child: NoInternetBlockingView(
              retrying: retrying,
              title: 'No Internet Connection',
              subtitle:
                  'Arrow Drift needs an internet connection to start. '
                  'Please check your Wi-Fi or mobile data and try again.',
              onRetry: () async {
                if (retrying) return;
                setState(() => retrying = true);
                final online = await NetworkStatus.instance.isOnline();
                if (!context.mounted) return;
                setState(() => retrying = false);
                if (online) {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          );
        },
      );
    },
  );
}
