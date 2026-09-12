import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Play Store flexible update check. No-ops / logs on debug, web, or sideload.
Future<void> checkForUpdate() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;

  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      return;
    }

    final result = await InAppUpdate.startFlexibleUpdate();
    if (result == AppUpdateResult.success) {
      await InAppUpdate.completeFlexibleUpdate();
    }
  } catch (error, stack) {
    debugPrint('In-app update check failed: $error');
    debugPrint('$stack');
  }
}
