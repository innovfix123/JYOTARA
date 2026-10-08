package `in`.innovfix.jyotara

import android.content.Context
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Explicit events only. No login, personal identifiers or birth/chat payloads. */
class MetaMeasurement(context: Context, messenger: BinaryMessenger) {
    private val app = context.applicationContext
    private val appId = context.getString(R.string.jyotara_meta_app_id)
    private val clientToken = context.getString(R.string.jyotara_meta_client_token)
    private var consent = false
    private var logger: AppEventsLogger? = null
    private val allowed = setOf("fb_mobile_activate_app", "login_success", "chat_completed")

    init {
        MethodChannel(messenger, "jyotara/meta-measurement").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "configured" -> result.success(appId.matches(Regex("[0-9]+")) && clientToken.isNotBlank())
                    "consent" -> {
                        consent = call.arguments == true && appId.matches(Regex("[0-9]+")) && clientToken.isNotBlank()
                        if (consent && logger == null) {
                            FacebookSdk.setApplicationId(appId)
                            FacebookSdk.setClientToken(clientToken)
                            @Suppress("DEPRECATION")
                            FacebookSdk.sdkInitialize(app)
                            FacebookSdk.setAutoLogAppEventsEnabled(false)
                            FacebookSdk.setAdvertiserIDCollectionEnabled(false)
                            FacebookSdk.setLimitEventAndDataUsage(app, true)
                            FacebookSdk.fullyInitialize()
                            AppEventsLogger.setFlushBehavior(AppEventsLogger.FlushBehavior.EXPLICIT_ONLY)
                            logger = AppEventsLogger.newLogger(app)
                        }
                        result.success(consent)
                    }
                    "event" -> {
                        val name = call.arguments as? String
                        if (consent && name in allowed) {
                            logger?.logEvent(name)
                            logger?.flush()
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                consent = false
                result.error("meta_unavailable", "Meta measurement unavailable", null)
            }
        }
    }
}
