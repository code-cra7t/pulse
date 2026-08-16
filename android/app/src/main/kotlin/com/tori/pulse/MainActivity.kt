package com.tori.pulse

import android.content.Intent
import android.provider.AlarmClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.tori.pulse/alarm",
        ).setMethodCallHandler { call, result ->
            if (call.method != "setAlarm") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val hour = call.argument<Int>("hour")
            val minute = call.argument<Int>("minute")
            val label = call.argument<String>("label") ?: "JotCue"
            if (hour == null || minute == null) {
                result.error("INVALID_TIME", "Alarm time is missing.", null)
                return@setMethodCallHandler
            }

            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                putExtra(AlarmClock.EXTRA_MESSAGE, label)
                putExtra(AlarmClock.EXTRA_SKIP_UI, false)
            }

            if (intent.resolveActivity(packageManager) == null) {
                result.success(false)
                return@setMethodCallHandler
            }

            startActivity(intent)
            result.success(true)
        }
    }
}
