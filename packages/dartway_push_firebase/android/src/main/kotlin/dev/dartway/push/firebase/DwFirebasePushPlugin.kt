package dev.dartway.push.firebase

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin

private const val SILENT_CHANNEL_ID_META = "dev.dartway.push.firebase.silent_channel_id"
private const val SILENT_CHANNEL_NAME_META = "dev.dartway.push.firebase.silent_channel_name"
private const val DEFAULT_SILENT_CHANNEL_ID = "dw_push_silent"
private const val DEFAULT_SILENT_CHANNEL_NAME = "Quiet notifications"

/** Creates the quiet notification channel before FCM can deliver to it. */
class DwFirebasePushPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val context = binding.applicationContext
        val metadata = try {
            context.packageManager
                .getApplicationInfo(context.packageName, PackageManager.GET_META_DATA).metaData
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
        val id = metadata?.getString(SILENT_CHANNEL_ID_META) ?: DEFAULT_SILENT_CHANNEL_ID
        val name = metadata?.getString(SILENT_CHANNEL_NAME_META) ?: DEFAULT_SILENT_CHANNEL_NAME
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(id) == null) {
            manager.createNotificationChannel(
                NotificationChannel(id, name, NotificationManager.IMPORTANCE_LOW).apply {
                    setSound(null, null)
                    enableVibration(false)
                },
            )
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit
}
