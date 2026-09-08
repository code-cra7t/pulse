package com.tori.pulse

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract.Calendars
import android.provider.CalendarContract.Events
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.Executors

/** Device-local links: never search/delete unrelated events or legacy exports. */
class CalendarBridge(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "com.tori.pulse/calendar")
    private val preferences = activity.getSharedPreferences("jotcue_calendar_links", Context.MODE_PRIVATE)
    private val executor = Executors.newSingleThreadExecutor()
    private var permissionCall: Pair<MethodCall, MethodChannel.Result>? = null

    init { channel.setMethodCallHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "retryPendingRemovals") {
            if (!hasPermission()) result.success(null)
            else background(result) { retryPendingRemovals(); succeed(result) }
            return
        }
        if (call.method !in listOf("upsert", "updateLinked", "remove")) {
            result.notImplemented()
            return
        }
        val id = call.argument<String>("reminderId")
        if (id.isNullOrBlank()) {
            result.error("INVALID_REMINDER", "A saved reminder is required.", null)
            return
        }
        if (call.method != "upsert" && !preferences.contains(id)) {
            result.success(null)
            return
        }
        if (call.method == "remove") preferences.edit().putBoolean("pending:$id", true).commit()
        if (!hasPermission()) {
            if (call.method != "upsert") {
                // Keep the link for a later retry after access is restored.
                result.error("CALENDAR_PERMISSION", "Calendar access is disabled. The linked entry could not be updated.", null)
            } else if (permissionCall != null) {
                result.error("CALENDAR_BUSY", "Finish the current calendar request first.", null)
            } else {
                permissionCall = call to result
                activity.requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR), REQUEST_CODE)
            }
            return
        }
        execute(call, result)
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val pending = permissionCall ?: return true
        permissionCall = null
        if (grantResults.isNotEmpty() && hasPermission()) execute(pending.first, pending.second)
        else pending.second.error("CALENDAR_PERMISSION", "Allow calendar access to link and remove completed entries.", null)
        return true
    }

    private fun hasPermission() =
        activity.checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED &&
        activity.checkSelfPermission(Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED

    private fun execute(call: MethodCall, result: MethodChannel.Result) = background(result) {
        retryPendingRemovals()
        val id = call.argument<String>("reminderId")!!
        val link = preferences.getString(id, null)?.let(::JSONObject)
        if (link != null && ownsEvent(link)) {
            val uri = ContentUris.withAppendedId(Events.CONTENT_URI, link.getLong("eventId"))
            if (call.method == "remove") {
                activity.contentResolver.delete(uri, null, null)
                preferences.edit().remove(id).commit()
            } else {
                activity.contentResolver.update(uri, values(call, link.getLong("calendarId"), link.getString("marker")), null, null)
            }
            succeed(result)
        } else {
            if (link != null) preferences.edit().remove(id).commit()
            if (call.method == "upsert") chooseCalendar(call, result)
            else succeed(result)
        }
    }

    private fun retryPendingRemovals() {
        for ((key, value) in preferences.all) {
            if (!key.startsWith("pending:") || value != true) continue
            val id = key.removePrefix("pending:")
            val link = preferences.getString(id, null)?.let(::JSONObject)
            if (link != null && ownsEvent(link)) {
                activity.contentResolver.delete(
                    ContentUris.withAppendedId(Events.CONTENT_URI, link.getLong("eventId")), null, null,
                )
            }
            preferences.edit().remove(id).remove(key).commit()
        }
    }

    private fun ownsEvent(link: JSONObject): Boolean {
        val uri = ContentUris.withAppendedId(Events.CONTENT_URI, link.getLong("eventId"))
        activity.contentResolver.query(uri, arrayOf(Events.CALENDAR_ID, Events.CUSTOM_APP_URI, Events.DELETED), null, null, null)?.use {
            return it.moveToFirst() && it.getInt(2) == 0 &&
                it.getLong(0) == link.getLong("calendarId") &&
                it.getString(1) == link.getString("marker")
        }
        return false
    }

    private fun chooseCalendar(call: MethodCall, result: MethodChannel.Result) {
        val calendars = mutableListOf<Pair<Long, String>>()
        activity.contentResolver.query(
            Calendars.CONTENT_URI,
            arrayOf(Calendars._ID, Calendars.CALENDAR_DISPLAY_NAME, Calendars.ACCOUNT_NAME),
            "${Calendars.CALENDAR_ACCESS_LEVEL} >= ? AND ${Calendars.VISIBLE} = 1",
            arrayOf(Calendars.CAL_ACCESS_CONTRIBUTOR.toString()), Calendars.CALENDAR_DISPLAY_NAME,
        )?.use { cursor ->
            while (cursor.moveToNext()) calendars.add(cursor.getLong(0) to "${cursor.getString(1)} (${cursor.getString(2)})")
        }
        if (calendars.isEmpty()) throw IllegalStateException("No writable calendar is available. Add a calendar account first.")
        activity.runOnUiThread {
            if (activity.isFinishing || activity.isDestroyed) {
                result.error("CALENDAR_CANCELLED", "Calendar selection was closed.", null)
                return@runOnUiThread
            }
            AlertDialog.Builder(activity)
                .setTitle("Add to calendar")
                .setItems(calendars.map { it.second }.toTypedArray()) { _, position ->
                    background(result) {
                        val calendarId = calendars[position].first
                        val marker = "jotcue://reminders/${UUID.randomUUID()}"
                        val uri = activity.contentResolver.insert(Events.CONTENT_URI, values(call, calendarId, marker))
                            ?: throw IllegalStateException("Calendar did not save the entry.")
                        val link = JSONObject().put("eventId", ContentUris.parseId(uri))
                            .put("calendarId", calendarId).put("marker", marker)
                        val saved = preferences.edit().putString(call.argument<String>("reminderId")!!, link.toString()).commit()
                        if (!saved) {
                            activity.contentResolver.delete(uri, null, null)
                            throw IllegalStateException("Could not save the calendar link. Try again.")
                        }
                        succeed(result)
                    }
                }
                .setNegativeButton("Cancel") { _, _ -> result.error("CALENDAR_CANCELLED", "No calendar entry was added.", null) }
                .setOnCancelListener { result.error("CALENDAR_CANCELLED", "No calendar entry was added.", null) }
                .show()
        }
    }

    private fun values(call: MethodCall, calendarId: Long, marker: String): ContentValues {
        val at = call.argument<Number>("scheduledAt")?.toLong()
            ?: throw IllegalArgumentException("Choose a reminder time first.")
        val repeat = call.argument<String>("repeat") ?: "none"
        val rule = when (repeat) {
            "none" -> null
            "daily" -> "FREQ=DAILY"
            "weekly" -> "FREQ=WEEKLY"
            "interval" -> {
                val minutes = call.argument<Number>("repeatIntervalMinutes")?.toInt() ?: 0
                require(minutes >= 15) { "Repeat intervals must be at least 15 minutes." }
                "FREQ=MINUTELY;INTERVAL=$minutes"
            }
            else -> throw IllegalArgumentException("Unsupported repeat schedule.")
        }
        return ContentValues().apply {
            put(Events.CALENDAR_ID, calendarId)
            put(Events.TITLE, call.argument<String>("title") ?: "Review note")
            put(Events.DESCRIPTION, call.argument<String>("body") ?: "")
            put(Events.CUSTOM_APP_PACKAGE, activity.packageName)
            put(Events.CUSTOM_APP_URI, marker)
            put(Events.DTSTART, at)
            put(Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
            put(Events.RRULE, rule)
            if (rule == null) {
                put(Events.DTEND, at + 30 * 60 * 1000)
                putNull(Events.DURATION)
            } else {
                putNull(Events.DTEND)
                put(Events.DURATION, "PT30M")
            }
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Unit) {
        executor.execute {
            try { work() }
            catch (error: Exception) {
                activity.runOnUiThread { result.error("CALENDAR_FAILED", error.message ?: "Calendar update failed.", null) }
            }
        }
    }

    private fun succeed(result: MethodChannel.Result) = activity.runOnUiThread { result.success(null) }

    fun dispose() {
        channel.setMethodCallHandler(null)
        permissionCall?.second?.error("CALENDAR_CANCELLED", "Calendar request was closed.", null)
        permissionCall = null
        executor.shutdown()
    }

    companion object { private const val REQUEST_CODE = 7412 }
}
