package dev.dartway.push.rustore

import android.os.Handler
import android.os.Looper
import android.util.Log
import ru.rustore.flutter_rustore_push.FlutterRustorePushService
import ru.rustore.flutter_rustore_push.pigeons.Message
import ru.rustore.flutter_rustore_push.pigeons.Notification
import ru.rustore.sdk.pushclient.messaging.exception.RuStorePushClientException
import ru.rustore.sdk.pushclient.messaging.model.RemoteMessage
import ru.rustore.sdk.pushclient.messaging.service.RuStoreMessagingService

private const val LOG_TAG = "DwRuStorePush"

/**
 * The service RuStore delivers to.
 *
 * It replaces the one `flutter_rustore_push` registers — RuStore delivers to a
 * single service, and two things have to happen here that the SDK's own does
 * not do: the payload has to be written down before the notification is shown
 * (the tap may come back hours later, to a process that no longer exists), and
 * a data-only message has to be drawn, because nothing else will draw it.
 *
 * Everything the Flutter side expects still happens: each callback is forwarded
 * to the plugin's Dart client exactly as before, on the main thread.
 */
class DwRuStorePushService : RuStoreMessagingService() {
    private val uiThreadHandler = Handler(Looper.getMainLooper())

    override fun onNewToken(token: String) {
        Log.d(LOG_TAG, "new token, length=${token.length}")
        uiThreadHandler.post {
            FlutterRustorePushService.client?.newToken(token) { }
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        DwRuStorePushPayloadStore(this).store(message)

        val sdkNotification = message.notification
        resolveDwRuStoreNotificationContent(
            hasVisibleSdkNotification = hasVisibleSdkNotification(
                notificationTitle = sdkNotification?.title,
                notificationBody = sdkNotification?.body,
            ),
            messageData = message.data,
        )?.let { content ->
            DwRuStoreNotificationRenderer.show(this, message, content)
        }

        message.messageId?.let { FlutterRustorePushService.messages[it] = message }

        val notification = sdkNotification?.let { remoteNotification ->
            Notification(
                title = remoteNotification.title.orEmpty(),
                body = remoteNotification.body.orEmpty(),
                channelId = remoteNotification.channelId.orEmpty(),
                imageUrl = remoteNotification.imageUrl?.toString().orEmpty(),
                color = remoteNotification.color.orEmpty(),
                icon = remoteNotification.icon.orEmpty(),
                clickAction = remoteNotification.clickAction.orEmpty(),
            )
        }

        val pushMessage = Message(
            messageId = message.messageId,
            data = message.data.entries.associate { entry -> entry.key to entry.value },
            priority = message.priority.toLong(),
            ttl = message.ttl.toLong(),
            collapseKey = message.collapseKey,
            notification = notification,
        )

        uiThreadHandler.post {
            FlutterRustorePushService.client?.messageReceived(pushMessage) { }
        }
    }

    override fun onDeletedMessages() {
        uiThreadHandler.post {
            FlutterRustorePushService.client?.deletedMessages { }
        }
    }

    override fun onError(errors: List<RuStorePushClientException>) {
        Log.e(LOG_TAG, "push client error: $errors")
        uiThreadHandler.post {
            FlutterRustorePushService.client?.error(errors.toString()) { }
        }
    }
}
