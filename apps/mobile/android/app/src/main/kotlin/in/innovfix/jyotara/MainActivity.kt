package `in`.innovfix.jyotara

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var otpChannel: MethodChannel
    private var receiver: BroadcastReceiver? = null
    private var generation = 0
    private var active = false
    private var resumed = false
    private var consentIntent: Intent? = null
    private var consentRequest = -1
    private val handler = Handler(Looper.getMainLooper())
    private var timeout: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MetaMeasurement(this, flutterEngine.dartExecutor.binaryMessenger)
        CoupleShare(this, flutterEngine.dartExecutor.binaryMessenger)
        otpChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jyotara/otp-autofill")
        otpChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> startOtp(result)
                "stop" -> { stopOtp(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun stopOtp() {
        active = false
        generation++
        consentIntent = null
        consentRequest = -1
        timeout?.let { handler.removeCallbacks(it) }
        timeout = null
        receiver?.let { try { unregisterReceiver(it) } catch (_: IllegalArgumentException) {} }
        receiver = null
    }

    private fun startOtp(result: MethodChannel.Result) {
        stopOtp()
        val attempt = generation
        active = true
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (!active || generation != attempt || intent.action != SmsRetriever.SMS_RETRIEVED_ACTION) return
                @Suppress("DEPRECATION")
                val status = intent.getParcelableExtra<Status>(SmsRetriever.EXTRA_STATUS) ?: return
                when (status.statusCode) {
                    CommonStatusCodes.SUCCESS -> {
                        @Suppress("DEPRECATION")
                        val consent = intent.getParcelableExtra<Intent>(SmsRetriever.EXTRA_CONSENT_INTENT) ?: return
                        consentIntent = consent
                        showConsent()
                    }
                    CommonStatusCodes.TIMEOUT -> stopOtp()
                }
            }
        }
        try {
            // Only Google Play services may deliver this broadcast. No SMS inbox permission.
            ContextCompat.registerReceiver(this, receiver, IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION),
                SmsRetriever.SEND_PERMISSION, null, ContextCompat.RECEIVER_EXPORTED)
            timeout = Runnable { if (generation == attempt) stopOtp() }
            handler.postDelayed(timeout!!, 300_000)
            SmsRetriever.getClient(this).startSmsUserConsent(null)
                .addOnSuccessListener { result.success(if (active && generation == attempt) attempt else null) }
                .addOnFailureListener { if (generation == attempt) stopOtp(); result.success(null) }
        } catch (_: Exception) {
            stopOtp()
            result.success(null)
        }
    }

    private fun showConsent() {
        if (!resumed || !active || consentRequest != -1) return
        val intent = consentIntent ?: return
        consentIntent = null
        consentRequest = 4000 + generation % 1000
        try { startActivityForResult(intent, consentRequest) } catch (_: Exception) { stopOtp() }
    }

    override fun onResume() { super.onResume(); resumed = true; showConsent() }
    override fun onPause() { resumed = false; super.onPause() }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (!active || requestCode != consentRequest) return
        val attempt = generation
        val message = if (resultCode == Activity.RESULT_OK) data?.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE) else null
        val codes = message?.let { Regex("(?<![0-9])[0-9]{6}(?![0-9])").findAll(it).map { match -> match.value }.toList() }
        stopOtp()
        // Do not log or transmit SMS content; only one unambiguous code crosses to the form.
        if (codes?.size == 1) otpChannel.invokeMethod("code", mapOf("attempt" to attempt, "code" to codes.single()))
    }

    override fun onDestroy() { stopOtp(); super.onDestroy() }
}
