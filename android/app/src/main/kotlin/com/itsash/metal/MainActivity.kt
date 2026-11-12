package com.itsash.metal

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Channels (names match `lib/platform/device_channel.dart`):
 * - `com.itsash.metal/device` (method): `keepScreenOn`, `vibrate(ms)`,
 *   `setTone([freqHz, periodMs])`, `stopTone`.
 * - `com.itsash.metal/field` (events): `[x, y, z, accuracy, uncalibrated]`.
 */
class MainActivity : FlutterActivity() {
    private val tone = ToneGenerator()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "$CHANNEL/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "keepScreenOn" -> {
                    val on = call.arguments as? Boolean ?: false
                    if (on) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                "vibrate" -> {
                    vibrate((call.arguments as? Number)?.toLong() ?: 30L)
                    result.success(null)
                }
                "setTone" -> {
                    val args = call.arguments as? List<*>
                    val freq = (args?.getOrNull(0) as? Number)?.toDouble() ?: 0.0
                    val period = (args?.getOrNull(1) as? Number)?.toInt() ?: 0
                    tone.set(freq, period)
                    result.success(null)
                }
                "stopTone" -> {
                    tone.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "$CHANNEL/field")
            .setStreamHandler(MagnetStreamHandler(applicationContext))
    }

    override fun onPause() {
        tone.stop()
        super.onPause()
    }

    override fun onDestroy() {
        tone.stop()
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    private fun vibrate(ms: Long) {
        val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= 31) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        if (vibrator == null || !vibrator.hasVibrator()) return
        vibrator.vibrate(VibrationEffect.createOneShot(ms.coerceIn(5, 500), VibrationEffect.DEFAULT_AMPLITUDE))
    }

    private companion object {
        const val CHANNEL = "com.itsash.metal"
    }
}
