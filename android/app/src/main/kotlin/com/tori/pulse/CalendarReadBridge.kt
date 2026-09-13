package com.tori.pulse

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.provider.CalendarContract.Events
import android.provider.CalendarContract.Instances
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Read-only calendar access used to calculate availability on-device. */
class CalendarReadBridge(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "com.tori.pulse/calendar_read")
    private val executor = Executors.newSingleThreadExecutor()
    private var permissionResult: MethodChannel.Result? = null

    init { channel.setMethodCallHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasAccess" -> result.success(hasPermission())
            "requestAccess" -> requestAccess(result)
            "listEvents" -> listEvents(call, result)
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val pending = permissionResult ?: return true
        permissionResult = null
        pending.success(grantResults.isNotEmpty() && hasPermission())
        return true
    }

    private fun requestAccess(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error("CALENDAR_BUSY", "Finish the current calendar request first.", null)
            return
        }
        permissionResult = result
        activity.requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), REQUEST_CODE)
    }

    private fun listEvents(call: MethodCall, result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.error("CALENDAR_PERMISSION", "Calendar read access is disabled.", null)
            return
        }
        val startAt = call.argument<Number>("startAt")?.toLong()
        val endAt = call.argument<Number>("endAt")?.toLong()
        if (startAt == null || endAt == null || endAt <= startAt) {
            result.error("INVALID_RANGE", "Choose a valid calendar range.", null)
            return
        }
        if (endAt - startAt > MAX_QUERY_RANGE_MILLIS) {
            result.error("RANGE_TOO_LARGE", "Calendar reads are limited to 31 days.", null)
            return
        }

        executor.execute {
            try {
                val events = queryEvents(startAt, endAt)
                activity.runOnUiThread { result.success(events) }
            } catch (error: Exception) {
                activity.runOnUiThread {
                    result.error("CALENDAR_READ_FAILED", error.message ?: "Calendar could not be read.", null)
                }
            }
        }
    }

    private fun queryEvents(startAt: Long, endAt: Long): List<Map<String, Any>> {
        val projection = arrayOf(
            Instances.EVENT_ID,
            Events.TITLE,
            Instances.BEGIN,
            Instances.END,
            Events.ALL_DAY,
            Events.STATUS,
            Events.AVAILABILITY,
        )
        val events = mutableListOf<Map<String, Any>>()
        Instances.query(activity.contentResolver, projection, startAt, endAt).use { cursor ->
            val eventIdIndex = cursor.getColumnIndexOrThrow(Instances.EVENT_ID)
            val titleIndex = cursor.getColumnIndexOrThrow(Events.TITLE)
            val beginIndex = cursor.getColumnIndexOrThrow(Instances.BEGIN)
            val endIndex = cursor.getColumnIndexOrThrow(Instances.END)
            val allDayIndex = cursor.getColumnIndexOrThrow(Events.ALL_DAY)
            val statusIndex = cursor.getColumnIndexOrThrow(Events.STATUS)
            val availabilityIndex = cursor.getColumnIndexOrThrow(Events.AVAILABILITY)

            while (cursor.moveToNext()) {
                val status = cursor.getInt(statusIndex)
                val availability = cursor.getInt(availabilityIndex)
                if (status == Events.STATUS_CANCELED || availability == Events.AVAILABILITY_FREE) {
                    continue
                }
                val eventId = cursor.getLong(eventIdIndex)
                val begin = cursor.getLong(beginIndex)
                val end = cursor.getLong(endIndex)
                if (end <= begin) continue
                events.add(
                    mapOf(
                        "id" to "$eventId:$begin",
                        "title" to (cursor.getString(titleIndex) ?: ""),
                        "startsAt" to begin,
                        "endsAt" to end,
                        "isAllDay" to (cursor.getInt(allDayIndex) != 0),
                    ),
                )
            }
        }
        return events
    }

    private fun hasPermission() =
        activity.checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED

    fun dispose() {
        channel.setMethodCallHandler(null)
        permissionResult?.error("CALENDAR_CANCELLED", "Calendar request was closed.", null)
        permissionResult = null
        executor.shutdown()
    }

    companion object {
        private const val REQUEST_CODE = 7413
        private const val MAX_QUERY_RANGE_MILLIS = 31L * 24L * 60L * 60L * 1000L
    }
}
