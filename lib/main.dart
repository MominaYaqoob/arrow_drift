import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arrow_drift/core/constants/app_constants.dart';
import 'package:arrow_drift/core/router/app_router.dart';
import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/settings_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Ignore legacy / Auto-Backup-restored prefs so reinstall starts at Level 1.
  SharedPreferences.setPrefix('arrow_drift_v2.');
  runApp(const ProviderScope(child: ArrowDriftApp()));
}

class ArrowDriftApp extends ConsumerWidget {
  const ArrowDriftApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Load persisted settings (including dark theme) on startup.
    ref.watch(settingsProvider);

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
