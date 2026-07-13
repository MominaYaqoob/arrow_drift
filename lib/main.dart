import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arrow_drift/core/constants/app_constants.dart';
import 'package:arrow_drift/core/router/app_router.dart';
import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/data/repositories/settings_repository.dart';
import 'package:arrow_drift/features/lock/lock_screen.dart';
import 'package:arrow_drift/features/splash/splash_loading_screen.dart';
import 'package:arrow_drift/features/splash/splash_logo_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Ignore legacy / Auto-Backup-restored prefs so reinstall starts at Level 1.
  SharedPreferences.setPrefix('arrow_drift_v2.');
  runApp(const ProviderScope(child: ArrowDriftApp()));
}

class ArrowDriftApp extends ConsumerStatefulWidget {
  const ArrowDriftApp({super.key});

  @override
  ConsumerState<ArrowDriftApp> createState() => _ArrowDriftAppState();
}

class _ArrowDriftAppState extends ConsumerState<ArrowDriftApp>
    with WidgetsBindingObserver {
  bool _pendingLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final autoLock = ref.read(autoLockEnabledProvider);
    if (!autoLock) return;

    // Arm on background. Prefer `paused` (not every `inactive`) so dialogs /
    // the lock route itself do not re-trigger the gate.
    if (state == AppLifecycleState.paused) {
      _pendingLock = true;
      return;
    }

    if (state == AppLifecycleState.resumed && _pendingLock) {
      _pendingLock = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final router = ref.read(appRouterProvider);
        final path = router.routerDelegate.currentConfiguration.uri.path;
        if (path == LockScreen.routePath ||
            path == SplashLogoScreen.routePath ||
            path == SplashLoadingScreen.routePath) {
          return;
        }
        router.push(LockScreen.routePath);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
