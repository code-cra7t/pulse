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

/**
 * Owns only calendar entries explicitly created for JotCue schedule blocks.
 * Reminder exports use CalendarBridge and a separate ownership store.
 */
class ScheduleCalendarBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "com.tori.pulse/calendar_schedule")
    private val preferences = activity.getSharedPreferences(
        "jotcue_schedule_calendar_links",
        Context.MODE_PRIVATE,
    )
    private val executor = Executors.newSingleThreadExecutor()
    private var permissionResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasAccess" -> result.success(hasPermission())
            "requestAccess" -> requestAccess(result)
            "isLinked" -> isLinked(call, result)
            "upsert" -> upsert(call, result)
            "remove" -> remove(call, result)
            "detach" -> detach(call, result)
            "detachAll" -> {
                preferences.edit().clear().apply()
                result.success(null)
            }
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
            result.error("CALENDAR_BUSY", "Finish the current calendar permission request first.", null)
            return
        }
        permissionResult = result
        activity.requestPermissions(
            arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
            REQUEST_CODE,
        )
    }

    private fun hasPermission(): Boolean =
        activity.checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED &&
            activity.checkSelfPermission(Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED

    private fun isLinked(call: MethodCall, result: MethodChannel.Result) {
        val blockId = requireBlockId(call, result) ?: return
        val raw = preferences.getString(blockId, null)
        if (raw == null) {
            result.success(false)
            return
        }
        if (!hasPermission()) {
            // The local ownership marker is still useful when access was revoked.
            result.success(true)
            return
        }
        background(result) {
            val link = JSONObject(raw)
            val linked = ownsEvent(link)
            if (!linked) preferences.edit().remove(blockId).commit()
            activity.runOnUiThread { result.success(linked) }
        }
    }

    private fun upsert(call: MethodCall, result: MethodChannel.Result) {
        val blockId = requireBlockId(call, result) ?: return
        if (!hasPermission()) {
            result.error(
                "CALENDAR_PERMISSION",
                "Calendar write access is required before adding a planned block.",
                null,
            )
            return
        }
        background(result) {
            val existing = preferences.getString(blockId, null)?.let(::JSONObject)
            if (existing != null && ownsEvent(existing)) {
                val uri = ContentUris.withAppendedId(Events.CONTENT_URI, existing.getLong("eventId"))
                val updated = activity.contentResolver.update(
                    uri,
                    values(call, existing.getLong("calendarId"), existing.getString("marker")),
                    ownershipSelection,
                    ownershipArguments(existing),
                )
                check(updated == 1) { "The linked calendar entry is no longer available." }
                succeed(result)
            } else {
                if (existing != null) preferences.edit().remove(blockId).commit()
                chooseCalendar(call, result, blockId)
            }
        }
    }

    private fun remove(call: MethodCall, result: MethodChannel.Result) {
        val blockId = requireBlockId(call, result) ?: return
        val raw = preferences.getString(blockId, null)
        if (raw == null) {
            result.success(null)
            return
        }
        if (!hasPermission()) {
            result.error(
                "CALENDAR_PERMISSION",
                "Calendar write access is required to remove the linked entry.",
                null,
            )
            return
        }
        background(result) {
            val link = JSONObject(raw)
            if (ownsEvent(link)) {
                activity.contentResolver.delete(
                    ContentUris.withAppendedId(Events.CONTENT_URI, link.getLong("eventId")),
                    ownershipSelection,
                    ownershipArguments(link),
                )
            }
            preferences.edit().remove(blockId).commit()
            succeed(result)
        }
    }

    private fun detach(call: MethodCall, result: MethodChannel.Result) {
        val blockId = requireBlockId(call, result) ?: return
        preferences.edit().remove(blockId).apply()
        result.success(null)
    }

    private fun requireBlockId(call: MethodCall, result: MethodChannel.Result): String? {
        val blockId = call.argument<String>("blockId")
        if (blockId.isNullOrBlank()) {
            result.error("INVALID_BLOCK", "A saved JotCue planning block is required.", null)
            return null
        }
        return blockId
    }

    private fun chooseCalendar(
        call: MethodCall,
        result: MethodChannel.Result,
        blockId: String,
    ) {
        val calendars = mutableListOf<Pair<Long, String>>()
        activity.contentResolver.query(
            Calendars.CONTENT_URI,
            arrayOf(Calendars._ID, Calendars.CALENDAR_DISPLAY_NAME, Calendars.ACCOUNT_NAME),
            "${Calendars.CALENDAR_ACCESS_LEVEL} >= ? AND ${Calendars.VISIBLE} = 1",
            arrayOf(Calendars.CAL_ACCESS_CONTRIBUTOR.toString()),
            Calendars.CALENDAR_DISPLAY_NAME,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                calendars.add(
                    cursor.getLong(0) to "${cursor.getString(1)} (${cursor.getString(2)})",
                )
            }
        }
        if (calendars.isEmpty()) {
            throw IllegalStateException("No writable calendar is available. Add a calendar account first.")
        }

        activity.runOnUiThread {
            if (activity.isFinishing || activity.isDestroyed) {
                result.error("CALENDAR_CANCELLED", "Calendar selection was closed.", null)
                return@runOnUiThread
            }
            AlertDialog.Builder(activity)
                .setTitle("Add JotCue block to calendar")
                .setItems(calendars.map { it.second }.toTypedArray()) { _, position ->
                    background(result) {
                        val calendarId = calendars[position].first
                        val marker = "jotcue://schedule-blocks/${UUID.randomUUID()}"
                        val uri = activity.contentResolver.insert(
                            Events.CONTENT_URI,
                            values(call, calendarId, marker),
                        ) ?: throw IllegalStateException("Calendar did not save the planned block.")
                        val link = JSONObject()
                            .put("eventId", ContentUris.parseId(uri))
                            .put("calendarId", calendarId)
                            .put("marker", marker)
                        val saved = preferences.edit().putString(blockId, link.toString()).commit()
                        if (!saved) {
                            activity.contentResolver.delete(uri, null, null)
                            throw IllegalStateException("Could not save the calendar link. Try again.")
                        }
                        succeed(result)
                    }
                }
                .setNegativeButton("Cancel") { _, _ ->
                    result.error("CALENDAR_CANCELLED", "No calendar entry was added.", null)
                }
                .setOnCancelListener {
                    result.error("CALENDAR_CANCELLED", "No calendar entry was added.", null)
                }
                .show()
        }
    }

    private fun ownsEvent(link: JSONObject): Boolean {
        val uri = ContentUris.withAppendedId(Events.CONTENT_URI, link.getLong("eventId"))
        activity.contentResolver.query(
            uri,
            arrayOf(Events.CALENDAR_ID, Events.CUSTOM_APP_URI, Events.DELETED),
            null,
            null,
            null,
        )?.use { cursor ->
            return cursor.moveToFirst() && cursor.getInt(2) == 0 &&
                cursor.getLong(0) == link.getLong("calendarId") &&
                cursor.getString(1) == link.getString("marker")
        }
        return false
    }

    private fun ownershipArguments(link: JSONObject): Array<String> = arrayOf(
        link.getLong("calendarId").toString(),
        link.getString("marker"),
    )

    private fun values(call: MethodCall, calendarId: Long, marker: String): ContentValues {
        val startsAt = call.argument<Number>("startsAt")?.toLong()
            ?: throw IllegalArgumentException("The planned block needs a start time.")
        val endsAt = call.argument<Number>("endsAt")?.toLong()
            ?: throw IllegalArgumentException("The planned block needs an end time.")
        require(endsAt > startsAt) { "The planned block must end after it starts." }

        return ContentValues().apply {
            put(Events.CALENDAR_ID, calendarId)
            put(Events.TITLE, call.argument<String>("title") ?: "JotCue focus block")
            put(
                Events.DESCRIPTION,
                call.argument<String>("description")
                    ?: "Planned with JotCue. Calendar edits are not automatically synced back to JotCue.",
            )
            put(Events.CUSTOM_APP_PACKAGE, activity.packageName)
            put(Events.CUSTOM_APP_URI, marker)
            put(Events.DTSTART, startsAt)
            put(Events.DTEND, endsAt)
            put(Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
            put(Events.AVAILABILITY, Events.AVAILABILITY_BUSY)
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Unit) {
        executor.execute {
            try {
                work()
            } catch (error: Exception) {
                activity.runOnUiThread {
                    result.error(
                        "CALENDAR_FAILED",
                        error.message ?: "Calendar update failed.",
                        null,
                    )
                }
            }
        }
    }

    private fun succeed(result: MethodChannel.Result) {
        activity.runOnUiThread { result.success(null) }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        permissionResult?.error("CALENDAR_CANCELLED", "Calendar permission request was closed.", null)
        permissionResult = null
        executor.shutdown()
    }

    companion object {
        private const val REQUEST_CODE = 7414
        private const val ownershipSelection =
            "${Events.CALENDAR_ID} = ? AND ${Events.CUSTOM_APP_URI} = ?"
    }
}
