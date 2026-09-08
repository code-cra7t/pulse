package com.tori.pulse

import android.app.Activity
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.util.Log
import com.dexterous.flutterlocalnotifications.models.NotificationAction
import com.dexterous.flutterlocalnotifications.models.NotificationChannelAction
import com.dexterous.flutterlocalnotifications.models.NotificationDetails
import com.dexterous.flutterlocalnotifications.models.NotificationStyle
import com.dexterous.flutterlocalnotifications.models.styles.DefaultStyleInformation
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors

/** Native interval scheduling that stays anchored while the Flutter process is dead. */
class IntervalNotificationBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor = Executors.newSingleThreadExecutor()

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "openAlertSettings") handleCall(call, result)
        else executor.execute { handleCall(call, result) }
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "scheduleInterval" -> {
                    val record = IntervalNotificationRecord.from(call)
                    IntervalNotificationScheduler.schedule(activity, record)
                    result.success(null)
                }
                "cancelInterval" -> {
                    val id = call.argument<Number>("id")?.toInt()
                        ?: throw IllegalArgumentException("Notification ID is missing.")
                    IntervalNotificationScheduler.cancel(activity, id)
                    result.success(null)
                }
                "cancelAllIntervals" -> {
                    IntervalNotificationScheduler.cancelAll(activity)
                    result.success(null)
                }
                "pendingIntervalCount" -> result.success(
                    IntervalNotificationScheduler.pendingCount(activity),
                )
                "dismissAlert" -> {
                    val id = call.argument<Number>("id")?.toInt()
                        ?: throw IllegalArgumentException("Notification ID is missing.")
                    (activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
                    result.success(null)
                }
                "openAlertSettings" -> {
                    openAlertSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: SecurityException) {
            result.error(
                "EXACT_ALARM_PERMISSION",
                "Exact alarm access is disabled for JotCue.",
                null,
            )
        } catch (error: Exception) {
            result.error(
                "INTERVAL_SCHEDULE_FAILED",
                error.message ?: "Could not schedule the repeating reminder.",
                null,
            )
        }
    }

    private fun openAlertSettings() {
        val channelIntent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
            putExtra(Settings.EXTRA_CHANNEL_ID, REMINDER_CHANNEL_ID)
        }
        try {
            activity.startActivity(channelIntent)
        } catch (_: Exception) {
            activity.startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                },
            )
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    companion object {
        const val CHANNEL = "com.tori.pulse/notifications"
        const val REMINDER_CHANNEL_ID = "jotcue_reminder_alerts_v3"
    }
}

internal data class IntervalNotificationRecord(
    val id: Int,
    val title: String,
    val body: String,
    val payload: String,
    val anchorMillis: Long,
    val intervalMillis: Long,
) {
    fun toJson() = JSONObject()
        .put("id", id)
        .put("title", title)
        .put("body", body)
        .put("payload", payload)
        .put("anchorMillis", anchorMillis)
        .put("intervalMillis", intervalMillis)
        .toString()

    companion object {
        fun from(call: MethodCall): IntervalNotificationRecord {
            val id = call.argument<Number>("id")?.toInt()
                ?: throw IllegalArgumentException("Notification ID is missing.")
            val anchorMillis = call.argument<Number>("scheduledAtMillis")?.toLong()
                ?: throw IllegalArgumentException("Reminder time is missing.")
            val intervalMillis = call.argument<Number>("intervalMillis")?.toLong()
                ?: throw IllegalArgumentException("Repeat interval is missing.")
            require(intervalMillis >= 15 * 60 * 1000L) {
                "Repeat intervals must be at least 15 minutes."
            }
            return IntervalNotificationRecord(
                id = id,
                title = call.argument<String>("title") ?: "JotCue reminder",
                body = call.argument<String>("body") ?: "",
                payload = call.argument<String>("payload") ?: "",
                anchorMillis = anchorMillis,
                intervalMillis = intervalMillis,
            )
        }

        fun fromJson(value: String): IntervalNotificationRecord {
            val json = JSONObject(value)
            return IntervalNotificationRecord(
                id = json.getInt("id"),
                title = json.getString("title"),
                body = json.getString("body"),
                payload = json.getString("payload"),
                anchorMillis = json.getLong("anchorMillis"),
                intervalMillis = json.getLong("intervalMillis"),
            )
        }
    }
}

internal object IntervalNotificationScheduler {
    private const val PREFERENCES = "jotcue_interval_notifications"
    private const val ACTION_FIRE = "com.tori.pulse.INTERVAL_NOTIFICATION"

    @Synchronized fun schedule(context: Context, record: IntervalNotificationRecord) {
        scheduleAlarm(context, record, nextTrigger(record, System.currentTimeMillis()))
        val saved = preferences(context).edit().putString(record.id.toString(), record.toJson()).commit()
        if (!saved) {
            cancelAlarm(context, record.id)
            throw IllegalStateException("Could not save the repeating reminder.")
        }
    }

    fun scheduleNext(context: Context, record: IntervalNotificationRecord) {
        scheduleAlarm(context, record, nextTrigger(record, System.currentTimeMillis()))
    }

    @Synchronized fun cancel(context: Context, id: Int) {
        cancelAlarm(context, id)
        preferences(context).edit().remove(id.toString()).apply()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
    }

    @Synchronized fun cancelAll(context: Context) {
        records(context).forEach { cancelAlarm(context, it.id) }
        preferences(context).edit().clear().apply()
    }

    fun pendingCount(context: Context) = preferences(context).all.size

    @Synchronized fun deliver(context: Context, id: Int) {
        val current = record(context, id) ?: return
        scheduleNext(context, current)
        show(context, current)
    }

    fun record(context: Context, id: Int): IntervalNotificationRecord? {
        val value = preferences(context).getString(id.toString(), null) ?: return null
        return try {
            IntervalNotificationRecord.fromJson(value)
        } catch (error: Exception) {
            Log.e(TAG, "Discarding corrupt interval reminder $id", error)
            preferences(context).edit().remove(id.toString()).apply()
            null
        }
    }

    fun records(context: Context): List<IntervalNotificationRecord> = preferences(context).all
        .values
        .mapNotNull { value ->
            try {
                IntervalNotificationRecord.fromJson(value as String)
            } catch (error: Exception) {
                Log.e(TAG, "Ignoring corrupt interval reminder", error)
                null
            }
        }

    fun show(context: Context, record: IntervalNotificationRecord) {
        val details = NotificationDetails().apply {
            id = record.id
            title = record.title
            body = record.body
            payload = record.payload
            icon = "ic_notification"
            channelId = IntervalNotificationBridge.REMINDER_CHANNEL_ID
            channelName = "JotCue reminder alerts"
            channelDescription = "Sound, vibration, and pop-up alerts for JotCue reminders"
            channelShowBadge = true
            channelAction = NotificationChannelAction.CreateIfNotExists
            importance = 5
            priority = 1
            playSound = true
            enableVibration = true
            autoCancel = true
            ongoing = false
            silent = false
            onlyAlertOnce = false
            style = NotificationStyle.Default
            styleInformation = DefaultStyleInformation(false, false)
            ticker = "JotCue reminder"
            visibility = Notification.VISIBILITY_PUBLIC
            category = Notification.CATEGORY_REMINDER
            audioAttributesUsage = 4
            actions = listOf(
                notificationAction("snooze", "Snooze"),
                notificationAction("dismiss", "Dismiss"),
            )
        }
        IntervalNotificationRenderer.show(context, details)
    }

    private fun notificationAction(id: String, title: String): NotificationAction =
        NotificationAction(
            hashMapOf<String, Any>(
                "id" to id,
                "title" to title,
                "showsUserInterface" to true,
                "cancelNotification" to true,
            ),
        )

    private fun nextTrigger(record: IntervalNotificationRecord, now: Long): Long {
        if (record.anchorMillis > now) return record.anchorMillis
        val occurrences = (now - record.anchorMillis) / record.intervalMillis + 1
        return record.anchorMillis + occurrences * record.intervalMillis
    }

    private fun scheduleAlarm(context: Context, record: IntervalNotificationRecord, atMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            atMillis,
            pendingIntent(context, record.id),
        )
    }

    private fun cancelAlarm(context: Context, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent(context, id))
    }

    private fun pendingIntent(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, IntervalNotificationReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra("id", id)
        }
        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    private const val TAG = "JotCueIntervals"
}

class IntervalNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", Int.MIN_VALUE)
        if (id == Int.MIN_VALUE) return
        try {
            IntervalNotificationScheduler.deliver(context, id)
        } catch (error: Exception) {
            Log.e("JotCueIntervals", "Could not deliver interval reminder $id", error)
        }
    }
}

class IntervalNotificationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in RESTORE_ACTIONS) return
        IntervalNotificationScheduler.records(context).forEach { record ->
            try {
                IntervalNotificationScheduler.scheduleNext(context, record)
            } catch (error: Exception) {
                Log.e("JotCueIntervals", "Could not restore interval reminder ${record.id}", error)
            }
        }
    }

    companion object {
        private val RESTORE_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED",
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
        )
    }
}
