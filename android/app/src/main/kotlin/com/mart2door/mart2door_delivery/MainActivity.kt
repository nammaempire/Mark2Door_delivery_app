package com.mart2door.mart2door_delivery

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNewOrderChannel()
    }

    /**
     * Lets the Flutter side ask for an alert while the app is open on
     * screen (see lib/core/alerts/order_alerts.dart). Android shows server
     * notifications by itself only when the app is closed or in the
     * background.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALERTS)
            .setMethodCallHandler { call, result ->
                if (call.method == "show") {
                    showAlert(
                        call.argument<String>("title") ?: "New order",
                        call.argument<String>("body") ?: "",
                        call.argument<Int>("id") ?: 1,
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    /** The app's own alert sound, res/raw/order_alert.ogg. */
    private fun alertSound(): Uri =
        Uri.parse("android.resource://" + packageName + "/" + R.raw.order_alert)

    /**
     * The "New orders" notification channel, with the app's own alert sound.
     *
     * On Android 8 and later the sound belongs to the channel, and Android
     * ignores sound changes to a channel that already exists. To change the
     * sound later, replace res/raw/order_alert.ogg AND give the channel a new
     * id here, in AndroidManifest.xml and in the server function.
     */
    private fun createNewOrderChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        // The first version of this channel; replaced by the one below.
        manager.deleteNotificationChannel("new_orders_v1")
        val channel = NotificationChannel(
            NEW_ORDER_CHANNEL,
            "New orders",
            NotificationManager.IMPORTANCE_HIGH,
        )
        channel.description = "Rings when the store assigns you an order"
        channel.enableVibration(true)
        channel.setSound(
            alertSound(),
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        manager.createNotificationChannel(channel)
    }

    /** Posts one alert on the "New orders" channel: banner, sound, vibration. */
    @Suppress("DEPRECATION")
    private fun showAlert(title: String, body: String, id: Int) {
        val manager = getSystemService(NotificationManager::class.java)
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder: Notification.Builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, NEW_ORDER_CHANNEL)
            } else {
                // Before Android 8 there are no channels: the sound and
                // priority are set on the notification itself.
                Notification.Builder(this)
                    .setSound(alertSound())
                    .setPriority(Notification.PRIORITY_HIGH)
                    .setDefaults(Notification.DEFAULT_VIBRATE)
            }
        builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(open)
        manager.notify(id, builder.build())
    }

    companion object {
        const val NEW_ORDER_CHANNEL = "new_orders_v2"
        const val ALERTS = "mart2door/alerts"
    }
}
