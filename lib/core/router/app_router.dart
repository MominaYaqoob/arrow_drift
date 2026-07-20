import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arrow_drift/core/theme/app_theme.dart';
import 'package:arrow_drift/features/about/about_screen.dart';
import 'package:arrow_drift/features/about/help_center_screen.dart';
import 'package:arrow_drift/features/about/privacy_policy_screen.dart';
import 'package:arrow_drift/features/about/terms_of_service_screen.dart';
import 'package:arrow_drift/features/awards/awards_screen.dart';
import 'package:arrow_drift/features/consent/consent_screen.dart';
import 'package:arrow_drift/features/daily_challenge/daily_challenge_screen.dart';
import 'package:arrow_drift/features/gameplay/gameplay_screen.dart';
import 'package:arrow_drift/features/home/home_screen.dart';
import 'package:arrow_drift/features/home/main_shell.dart';
import 'package:arrow_drift/features/profile/me_screen.dart';
import 'package:arrow_drift/features/settings/settings_screen.dart';
import 'package:arrow_drift/features/splash/splash_loading_screen.dart';
import 'package:arrow_drift/features/splash/splash_logo_screen.dart';
import 'package:arrow_drift/features/tutorial/tutorial_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: SplashLogoScreen.routePath,
    routes: [
      GoRoute(
        path: SplashLogoScreen.routePath,
        builder: (context, state) => const SplashLogoScreen(),
      ),
      GoRoute(
        path: SplashLoadingScreen.routePath,
        builder: (context, state) => const SplashLoadingScreen(),
      ),
      GoRoute(
        path: ConsentScreen.routePath,
        builder: (context, state) => const ConsentScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: HomeScreen.routePath,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: DailyChallengeScreen.routePath,
                builder: (context, state) => const DailyChallengeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MeScreen.routePath,
                builder: (context, state) => const MeScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: TutorialScreen.routePath,
        builder: (context, state) => const TutorialScreen(),
      ),
      GoRoute(
        path: GameplayScreen.routePath,
        builder: (context, state) {
          final isDaily = state.uri.queryParameters['daily'] == '1';
          if (isDaily) {
            final dateParam = state.uri.queryParameters['date'];
            DateTime? dailyDate;
            if (dateParam != null && dateParam.isNotEmpty) {
              final parts = dateParam.split('-');
              if (parts.length == 3) {
                dailyDate = DateTime(
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                  int.parse(parts[2]),
                );
              }
            }
            return GameplayScreen(
              isDaily: true,
              dailyDate: dailyDate,
            );
          }
          final level = int.tryParse(
                state.uri.queryParameters['level'] ?? '',
              ) ??
              1;
          return GameplayScreen(levelNumber: level);
        },
      ),
      GoRoute(
        path: SettingsScreen.routePath,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AwardsScreen.routePath,
        builder: (context, state) => const AwardsScreen(),
      ),
      GoRoute(
        path: AboutScreen.routePath,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: HelpCenterScreen.routePath,
        builder: (context, state) => const HelpCenterScreen(),
      ),
      GoRoute(
        path: TermsOfServiceScreen.routePath,
        builder: (context, state) => const TermsOfServiceScreen(),
      ),
      GoRoute(
        path: PrivacyPolicyScreen.routePath,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SizedBox.shrink(),
    ),
  );
});
