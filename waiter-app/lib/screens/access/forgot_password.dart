import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_scope.dart';
import '../../core/config/environment.dart';

/// The web app's password reset page on the API host (03a §2 "Forgot
/// password?"): the API base URL without `/api/v1`, plus `/forgot-password`.
Uri forgotPasswordUri(AppEnvironment environment) {
  const String apiPrefix = '/api/v1';
  final Uri api = Uri.parse(environment.apiBaseUrl);
  final String path = api.path.endsWith(apiPrefix)
      ? api.path.substring(0, api.path.length - apiPrefix.length)
      : api.path;
  return api.replace(path: '$path/forgot-password');
}

/// Opens the reset page in the in-app browser (SFSafariViewController /
/// Chrome Custom Tab); closing it returns to the screen unchanged.
Future<void> openForgotPassword(BuildContext context) async {
  final AppServices services = context.services;
  final Uri uri = forgotPasswordUri(services.environment);
  try {
    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
      services.log.record('forgotPassword.notOpened', '$uri');
    }
  } on PlatformException catch (e) {
    services.log.record('forgotPassword.failed', '$e');
  }
}
