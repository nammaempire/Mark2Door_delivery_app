import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hand-offs to other apps. Each shows a message if the phone has nothing
/// that can handle the request.
abstract final class Launchers {
  /// Opens turn-by-turn directions in Google Maps: to the customer's own
  /// pin when the order has one, otherwise to the typed [address].
  static Future<void> navigateTo(
    BuildContext context,
    String address, {
    double? latitude,
    double? longitude,
  }) {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': latitude != null && longitude != null
          ? '$latitude,$longitude'
          : address,
      'travelmode': 'two-wheeler',
    });
    return _open(context, uri, "Couldn't open Maps on this phone.");
  }

  static Future<void> call(BuildContext context, String phone) =>
      _open(context, Uri(scheme: 'tel', path: '+91$phone'),
          "Couldn't open the dialer on this phone.");

  static Future<void> _open(
    BuildContext context,
    Uri uri,
    String failure,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure)));
    }
  }
}
