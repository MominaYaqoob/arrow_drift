import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arrow_drift/core/constants/app_constants.dart';
import 'package:arrow_drift/core/router/app_router.dart';
import 'package:arrow_drift/core/widgets/app_logo.dart';
import 'package:arrow_drift/data/repositories/progress_repository.dart';
import 'package:arrow_drift/features/consent/consent_screen.dart';
import 'package:arrow_drift/features/home/home_screen.dart';
import 'package:arrow_drift/features/splash/splash_loading_screen.dart';
import 'package:arrow_drift/features/splash/splash_logo_screen.dart';
import 'package:arrow_drift/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Splash chain: logo -> loading -> consent -> home',
      (WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ArrowDriftApp(),
      ),
    );
    await tester.pump();

    final router = container.read(appRouterProvider);

    expect(router.state.uri.path, SplashLogoScreen.routePath);
    expect(find.byType(AppLogoMark), findsOneWidget);
    expect(find.text(AppConstants.appShortName), findsOneWidget);
    expect(find.textContaining('THINK'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();

    expect(router.state.uri.path, SplashLoadingScreen.routePath);
    expect(find.text('Shuffling puzzles…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.state.uri.path, ConsentScreen.routePath);
    expect(find.text('Agree'), findsOneWidget);

    await tester.tap(find.text('Agree'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(router.state.uri.path, HomeScreen.routePath);
  });

  testWidgets('Returning user skips consent after splash',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      ProgressRepository.hasAcceptedTermsKey: true,
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ArrowDriftApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final router = container.read(appRouterProvider);
    expect(router.state.uri.path, HomeScreen.routePath);
  });
}
