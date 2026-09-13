package com.tori.pulse

import android.content.Intent
import android.content.ActivityNotFoundException
import android.provider.AlarmClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var calendarBridge: CalendarBridge? = null
    private var calendarReadBridge: CalendarReadBridge? = null
    private var intervalBridge: IntervalNotificationBridge? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        calendarBridge = CalendarBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        calendarReadBridge = CalendarReadBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        intervalBridge = IntervalNotificationBridge(this, flutterEngine.dartExecutor.binaryMessenger)

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
            if (hour == null || minute == null || hour !in 0..23 || minute !in 0..59) {
                result.error("INVALID_TIME", "Alarm time is missing.", null)
                return@setMethodCallHandler
            }

            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                putExtra(AlarmClock.EXTRA_MESSAGE, label)
                putExtra(AlarmClock.EXTRA_SKIP_UI, false)
            }

            try {
                startActivity(intent)
                result.success(true)
            } catch (_: ActivityNotFoundException) {
                result.success(false)
            } catch (_: SecurityException) {
                result.error("CLOCK_UNAVAILABLE", "Clock could not be opened. Check your phone's Clock app.", null)
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        calendarBridge?.onRequestPermissionsResult(requestCode, grantResults)
        calendarReadBridge?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        calendarBridge?.dispose()
        calendarReadBridge?.dispose()
        intervalBridge?.dispose()
        super.onDestroy()
    }
}
