package dev.dartway.push.rustore

import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject
import ru.rustore.sdk.pushclient.messaging.model.RemoteMessage

internal const val DW_PUSH_PAYLOAD_EXTRA = "dw_push_payload"
internal const val RUSTORE_MESSAGE_ID_EXTRA = "vkpns.analytics_payload.message_id"

private const val PREFS_NAME = "dw_rustore_push_payloads"
private const val MESSAGE_PREFIX = "message:"
private const val MAX_STORED_PAYLOADS = 20
private const val LOG_TAG = "DwRuStorePush"

/**
 * Keeps a message's data around from the moment it arrives until the moment the
 * user taps it.
 *
 * Two paths lead to that tap and only one of them carries the data. When this
 * plugin draws the notification it builds the intent and puts the whole payload
 * in one extra. When the RuStore SDK draws it, the intent is the SDK's and
 * carries only its own analytics extras — the message id among them. So the
 * payload is written down on arrival and looked up by that id.
 *
 * Deliberately not a list of known keys copied from Dart: whatever arrived is
 * stored whole. A key list would have to be kept in step by hand across two
 * languages, and a forgotten one loses the notification's context silently.
 */
internal class DwRuStorePushPayloadStore(context: Context) {
    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun store(message: RemoteMessage) {
        val messageId = message.messageId ?: run {
            Log.w(LOG_TAG, "message without an id; its payload cannot be restored on tap")
            return
        }
        val payload = JSONObject()
        message.data.forEach { (key, value) ->
            if (key != null && value != null) payload.put(key, value)
        }
        // The arrival time leads the key so plain string order is age order,
        // which is what the bound below evicts by.
        val key = "$MESSAGE_PREFIX${System.currentTimeMillis()}:$messageId"
        prefs.edit().putString(key, payload.toString()).apply()
        evictOldest()
    }

    /** The payload of the notification this intent came from, consumed once. */
    fun consumePayloadJson(intent: Intent?): String? {
        if (intent == null) return null

        val direct = intent.getStringExtra(DW_PUSH_PAYLOAD_EXTRA)
        if (direct != null) {
            intent.removeExtra(DW_PUSH_PAYLOAD_EXTRA)
            return direct
        }

        val messageId = intent.getStringExtra(RUSTORE_MESSAGE_ID_EXTRA) ?: return null
        intent.removeExtra(RUSTORE_MESSAGE_ID_EXTRA)
        val key = prefs.all.keys.firstOrNull { it.endsWith(":$messageId") }
        if (key == null) {
            Log.w(LOG_TAG, "no stored payload for messageId=$messageId")
            return null
        }
        val stored = prefs.getString(key, null)
        prefs.edit().remove(key).apply()
        return stored
    }

    /**
     * Bounds the store. Notifications the user never opens would otherwise
     * accumulate for the lifetime of the install.
     */
    private fun evictOldest() {
        val keys = prefs.all.keys.filter { it.startsWith(MESSAGE_PREFIX) }
        if (keys.size <= MAX_STORED_PAYLOADS) return
        val editor = prefs.edit()
        keys.sorted().take(keys.size - MAX_STORED_PAYLOADS).forEach(editor::remove)
        editor.apply()
    }
}
