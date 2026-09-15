package dev.dartway.push.rustore

// DwPushData.titleKey, bodyKey and imageKey of dartway_push_shared; the Dart
// test of this package checks these literals against those constants.
internal const val DW_TITLE_DATA_KEY = "dw_title"
internal const val DW_BODY_DATA_KEY = "dw_body"
internal const val DW_IMAGE_DATA_KEY = "dw_image"

/**
 * What to draw for a message the RuStore SDK will not draw itself.
 */
data class DwRuStoreNotificationContent(
    val title: String,
    val body: String,
    val imageUrl: String?,
)

/**
 * Decides whether this plugin has to render the notification, and with what.
 *
 * The server sends a picture message as **data only** — RuStore ignores an
 * image in a notification block, so the choice is between sending the image and
 * having the SDK show the text. When it does that, nothing is displayed at all
 * unless somebody draws it, and on a device where the app is not running that
 * somebody has to be native code: there is no Flutter engine to hand it to.
 *
 * Kept as a pure function so the decision can be tested without a device.
 * The three keys are `DwPushData`'s, written by the server's RuStore provider.
 */
fun resolveDwRuStoreNotificationContent(
    hasVisibleSdkNotification: Boolean,
    messageData: Map<String, String>,
): DwRuStoreNotificationContent? {
    if (hasVisibleSdkNotification) return null

    val title = messageData[DW_TITLE_DATA_KEY]?.trim().orEmpty()
    val body = messageData[DW_BODY_DATA_KEY]?.trim().orEmpty()
    if (title.isEmpty() && body.isEmpty()) return null

    return DwRuStoreNotificationContent(
        title = title,
        body = body,
        imageUrl = messageData[DW_IMAGE_DATA_KEY]?.trim()?.takeIf(String::isNotEmpty),
    )
}

fun hasVisibleSdkNotification(
    notificationTitle: String?,
    notificationBody: String?,
): Boolean = !notificationTitle.isNullOrBlank() || !notificationBody.isNullOrBlank()
