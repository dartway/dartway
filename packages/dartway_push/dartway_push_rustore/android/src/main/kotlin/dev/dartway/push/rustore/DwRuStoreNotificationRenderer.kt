package dev.dartway.push.rustore

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import ru.rustore.sdk.pushclient.messaging.model.RemoteMessage
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URI
import java.util.concurrent.Executors

private const val CHANNEL_ID_META = "dev.dartway.push.rustore.channel_id"
private const val CHANNEL_NAME_META = "dev.dartway.push.rustore.channel_name"
private const val ICON_META = "ru.rustore.sdk.pushclient.default_notification_icon"
private const val COLOR_META = "ru.rustore.sdk.pushclient.default_notification_color"

private const val DEFAULT_CHANNEL_ID = "dw_push"
private const val DEFAULT_CHANNEL_NAME = "Notifications"

private const val MAX_IMAGE_BYTES = 1024 * 1024
private const val MAX_BITMAP_SIDE = 1600
private const val NETWORK_TIMEOUT_MS = 5000
private const val LOG_TAG = "DwRuStorePush"

/**
 * Draws the notification for a message the RuStore SDK leaves invisible.
 *
 * Appearance comes from the app's manifest rather than from this package: the
 * icon and colour reuse the meta-data RuStore already requires, and the channel
 * can be named in the app's own language through two optional entries. A plugin
 * cannot reach the app's resources any other way, and hard-coding either would
 * put this package's taste in every app that installs it.
 */
internal object DwRuStoreNotificationRenderer {
    private val imageExecutor = Executors.newFixedThreadPool(2) { runnable ->
        Thread(runnable, "dw-rustore-push-image").apply { isDaemon = true }
    }

    fun show(
        context: Context,
        message: RemoteMessage,
        content: DwRuStoreNotificationContent,
    ) {
        val appContext = context.applicationContext
        val settings = readSettings(appContext)
        ensureNotificationChannel(appContext, settings)

        val notificationId = message.messageId?.hashCode()
            ?: System.currentTimeMillis().toInt()
        val contentIntent = buildContentIntent(appContext, message, notificationId)
        val notificationManager = NotificationManagerCompat.from(appContext)

        // Shown as text first and upgraded once the picture is in hand: a
        // notification that waits for a download is a notification that arrives
        // late, or never, on a bad connection.
        notificationManager.notify(
            notificationId,
            buildTextNotification(appContext, settings, content, contentIntent),
        )

        val imageUrl = content.imageUrl ?: return
        imageExecutor.execute {
            val bitmap = downloadNotificationBitmap(imageUrl) ?: return@execute
            notificationManager.notify(
                notificationId,
                buildImageNotification(appContext, settings, content, contentIntent, bitmap),
            )
        }
    }

    /**
     * The tap intent, carrying the whole payload in one extra.
     *
     * `FLAG_IMMUTABLE` is required from Android 12; `CLEAR_TOP or SINGLE_TOP`
     * brings the running app forward instead of stacking a second copy of it,
     * which is what makes the tap arrive through `onNewIntent`.
     */
    private fun buildContentIntent(
        context: Context,
        message: RemoteMessage,
        notificationId: Int,
    ): PendingIntent {
        val payload = JSONObject()
        message.data.forEach { (key, value) ->
            if (!key.isNullOrBlank() && value != null) payload.put(key, value)
        }

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: Intent(Intent.ACTION_MAIN)
        launchIntent.apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(DW_PUSH_PAYLOAD_EXTRA, payload.toString())
            message.messageId?.let { putExtra(RUSTORE_MESSAGE_ID_EXTRA, it) }
        }

        return PendingIntent.getActivity(
            context,
            notificationId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildBaseNotification(
        context: Context,
        settings: NotificationSettings,
        content: DwRuStoreNotificationContent,
        contentIntent: PendingIntent,
    ) = NotificationCompat.Builder(context, settings.channelId)
        .setSmallIcon(settings.iconResourceId)
        .setContentTitle(content.title)
        .setContentText(content.body)
        .setAutoCancel(true)
        .setPriority(NotificationCompat.PRIORITY_HIGH)
        .setContentIntent(contentIntent)
        .also { builder -> settings.color?.let(builder::setColor) }

    private fun buildTextNotification(
        context: Context,
        settings: NotificationSettings,
        content: DwRuStoreNotificationContent,
        contentIntent: PendingIntent,
    ) = buildBaseNotification(context, settings, content, contentIntent)
        .setStyle(NotificationCompat.BigTextStyle().bigText(content.body))
        .build()

    private fun buildImageNotification(
        context: Context,
        settings: NotificationSettings,
        content: DwRuStoreNotificationContent,
        contentIntent: PendingIntent,
        bitmap: Bitmap,
    ) = buildBaseNotification(context, settings, content, contentIntent)
        // The text version already alerted; the picture must not buzz again.
        .setOnlyAlertOnce(true)
        .setStyle(
            NotificationCompat.BigPictureStyle()
                .bigPicture(bitmap)
                .setBigContentTitle(content.title)
                .setSummaryText(content.body),
        )
        .build()

    private fun ensureNotificationChannel(context: Context, settings: NotificationSettings) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        if (notificationManager.getNotificationChannel(settings.channelId) != null) return

        notificationManager.createNotificationChannel(
            NotificationChannel(
                settings.channelId,
                settings.channelName,
                NotificationManager.IMPORTANCE_HIGH,
            ),
        )
    }

    private data class NotificationSettings(
        val channelId: String,
        val channelName: String,
        val iconResourceId: Int,
        val color: Int?,
    )

    private fun readSettings(context: Context): NotificationSettings {
        val metaData = try {
            context.packageManager
                .getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
                .metaData
        } catch (error: PackageManager.NameNotFoundException) {
            null
        }

        val iconResourceId = metaData?.getInt(ICON_META, 0)?.takeIf { it != 0 }
            ?: context.applicationInfo.icon
        val colorResourceId = metaData?.getInt(COLOR_META, 0)?.takeIf { it != 0 }

        return NotificationSettings(
            channelId = metaData?.getString(CHANNEL_ID_META) ?: DEFAULT_CHANNEL_ID,
            channelName = metaData?.getString(CHANNEL_NAME_META) ?: DEFAULT_CHANNEL_NAME,
            iconResourceId = iconResourceId,
            color = colorResourceId?.let { resourceId ->
                runCatching { context.getColor(resourceId) }.getOrNull()
            },
        )
    }

    /**
     * Fetches the picture with every bound enforced before it is trusted:
     * HTTPS only, a size cap checked while reading rather than from a header
     * the server chooses, and a decode bounded by sample size. A notification
     * image is a URL from the network, and this runs in the app's process.
     */
    private fun downloadNotificationBitmap(imageUrl: String): Bitmap? {
        val uri = Uri.parse(imageUrl)
        if (uri.scheme != "https" || uri.host.isNullOrBlank()) return null

        var connection: HttpURLConnection? = null
        return try {
            connection = URI(imageUrl).toURL().openConnection() as HttpURLConnection
            connection.connectTimeout = NETWORK_TIMEOUT_MS
            connection.readTimeout = NETWORK_TIMEOUT_MS
            connection.instanceFollowRedirects = true
            connection.useCaches = true

            if (connection.responseCode !in 200..299) return null
            if (connection.contentLengthLong > MAX_IMAGE_BYTES) return null

            val imageBytes = connection.inputStream.use(::readBoundedBytes) ?: return null
            decodeBoundedBitmap(imageBytes)
        } catch (error: Exception) {
            Log.w(LOG_TAG, "notification image could not be fetched", error)
            null
        } finally {
            connection?.disconnect()
        }
    }

    private fun readBoundedBytes(input: InputStream): ByteArray? {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        var totalBytes = 0

        while (true) {
            val readBytes = input.read(buffer)
            if (readBytes < 0) break
            totalBytes += readBytes
            if (totalBytes > MAX_IMAGE_BYTES) return null
            output.write(buffer, 0, readBytes)
        }

        return output.toByteArray()
    }

    private fun decodeBoundedBitmap(imageBytes: ByteArray): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sampleSize = 1
        while (
            bounds.outWidth / sampleSize > MAX_BITMAP_SIDE ||
            bounds.outHeight / sampleSize > MAX_BITMAP_SIDE
        ) {
            sampleSize *= 2
        }

        val options = BitmapFactory.Options().apply { inSampleSize = sampleSize }
        return BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, options)
    }
}
