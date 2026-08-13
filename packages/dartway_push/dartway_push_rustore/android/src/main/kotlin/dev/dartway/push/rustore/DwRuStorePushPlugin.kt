package dev.dartway.push.rustore

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

private const val CHANNEL_NAME = "dartway_push_rustore"
private const val PERMISSION_REQUEST_CODE = 4931

/**
 * The Android side of the RuStore transport: notification taps and the
 * Android 13 permission prompt.
 *
 * Both used to be the app's problem — an `onNewIntent` override in
 * `MainActivity` and a permission package pulled in for one call. A plugin can
 * own the activity's intents through `ActivityAware`, so an app that installs
 * this writes no Kotlin at all.
 */
class DwRuStorePushPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.NewIntentListener,
    PluginRegistry.RequestPermissionsResultListener {

    private var channel: MethodChannel? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var payloadStore: DwRuStorePushPayloadStore? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val activity: Activity?
        get() = activityBinding?.activity

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        payloadStore = DwRuStorePushPayloadStore(binding.applicationContext)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        payloadStore = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addOnNewIntentListener(this)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onDetachedFromActivity() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takeInitialPayload" ->
                result.success(payloadStore?.consumePayloadJson(activity?.intent))
            "notificationPermissionStatus" -> result.success(permissionStatus())
            "requestNotificationPermission" -> requestNotificationPermission(result)
            else -> result.notImplemented()
        }
    }

    /**
     * The app was already running when the user tapped. The intent replaces the
     * activity's own, so a later `takeInitialPayload` does not hand out a
     * notification that has already been acted on.
     */
    override fun onNewIntent(intent: Intent): Boolean {
        activity?.intent = intent
        val payload = payloadStore?.consumePayloadJson(intent) ?: return false
        channel?.invokeMethod("onPushOpened", payload)
        return false
    }

    private fun permissionStatus(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return "granted"
        val context = activity ?: return "notDetermined"
        val granted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) return "granted"
        // Android tells us whether to justify the request, not whether we have
        // asked before. "Explain yourself" means the user said no once and can
        // be asked again; silence means either never asked or never again, and
        // the two are indistinguishable until the request comes back.
        return if (ActivityCompat.shouldShowRequestPermissionRationale(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            )
        ) {
            "denied"
        } else {
            "notDetermined"
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success("granted")
            return
        }
        val currentActivity = activity
        if (currentActivity == null) {
            result.success("notDetermined")
            return
        }
        if (ContextCompat.checkSelfPermission(
                currentActivity,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success("granted")
            return
        }
        if (pendingPermissionResult != null) {
            // A second prompt while one is on screen: Android shows nothing and
            // the caller would wait forever.
            result.success("notDetermined")
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            currentActivity,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            PERMISSION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val result = pendingPermissionResult ?: return false
        pendingPermissionResult = null

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success("granted")
            return true
        }
        val currentActivity = activity
        val canAskAgain = currentActivity != null &&
            ActivityCompat.shouldShowRequestPermissionRationale(
                currentActivity,
                Manifest.permission.POST_NOTIFICATIONS,
            )
        result.success(if (canAskAgain) "denied" else "permanentlyDenied")
        return true
    }
}
