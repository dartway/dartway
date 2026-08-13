package dev.dartway.push.rustore

private const val PUSH_TITLE_DATA_KEY = "push_title"
private const val PUSH_BODY_DATA_KEY = "push_body"
private const val IMAGE_URL_DATA_KEY = "image_url"

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
 * The three keys are the wire contract with `dartway_push_server`, which pins
 * the same literals in a test of its own.
 */
fun resolveDwRuStoreNotificationContent(
    hasVisibleSdkNotification: Boolean,
    messageData: Map<String, String>,
): DwRuStoreNotificationContent? {
    if (hasVisibleSdkNotification) return null

    val title = messageData[PUSH_TITLE_DATA_KEY]?.trim().orEmpty()
    val body = messageData[PUSH_BODY_DATA_KEY]?.trim().orEmpty()
    if (title.isEmpty() && body.isEmpty()) return null

    return DwRuStoreNotificationContent(
        title = title,
        body = body,
        imageUrl = messageData[IMAGE_URL_DATA_KEY]?.trim()?.takeIf(String::isNotEmpty),
    )
}

fun hasVisibleSdkNotification(
    notificationTitle: String?,
    notificationBody: String?,
): Boolean = !notificationTitle.isNullOrBlank() || !notificationBody.isNullOrBlank()
