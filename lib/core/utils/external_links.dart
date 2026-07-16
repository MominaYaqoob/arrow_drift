import 'package:url_launcher/url_launcher.dart';

import 'package:arrow_drift/core/constants/app_constants.dart';

/// Opens an https / mailto link in an external app when possible.
Future<void> openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> openPrivacyPolicyUrl() =>
    openExternalUrl(AppConstants.privacyPolicyUrl);

Future<void> openSupportEmail() =>
    openExternalUrl('mailto:${AppConstants.supportEmail}');
