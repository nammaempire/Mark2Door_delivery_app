import 'package:flutter/services.dart';

/// Rings the phone and shows a banner for an order event while the app is
/// open on screen.
///
/// Android only shows a server notification by itself when the app is
/// closed or in the background. When the rider is looking at the app, the
/// message arrives here instead, and this asks the Android side
/// (`MainActivity.kt`) to post it on the "New orders" channel, which plays
/// the app's own alert sound.
abstract final class OrderAlerts {
  static const _channel = MethodChannel('mart2door/alerts');

  static Future<void> show({required String title, required String body}) async {
    try {
      await _channel.invokeMethod<void>('show', {
        'title': title,
        'body': body,
        // A different number each time, so alerts do not replace each other.
        'id': DateTime.now().millisecondsSinceEpoch ~/ 1000 % 1000000,
      });
    } on PlatformException {
      // Notifications are switched off for the app: the order still shows
      // in the list.
    } on MissingPluginException {
      // Not running on Android.
    }
  }
}
