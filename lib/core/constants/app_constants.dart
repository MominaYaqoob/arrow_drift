class AppConstants {
  AppConstants._();

  static const String appName = 'Arrow Drift: Puzzle Game';

  /// Short brand for tight UI spots (tabs, short labels).
  static const String appShortName = 'Arrow Drift';

  /// Full product name (same as [appName]).
  static const String appDisplayName = 'Arrow Drift: Puzzle Game';

  /// Android / Play application id (must match build.gradle.kts).
  static const String applicationId = 'com.sid.arrowdrift.puzzlegame';

  /// Support contact shown in Help / Privacy.
  static const String supportEmail = 'harmainfatima1000@gmail.com';

  /// Hosted privacy page opened from Privacy Policy taps.
  static const String privacyPolicyUrl =
      'https://learnwithfunpuzzlegame.blogspot.com/2026/07/arrow-drift-puzzle-game.html?m=1';

  /// Hosted terms page (optional).
  static const String termsOfServiceUrl = '';

  static String get playStoreListingUrl =>
      'https://play.google.com/store/apps/details?id=$applicationId';
}
