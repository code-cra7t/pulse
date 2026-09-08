package com.tori.pulse;

import android.content.Context;
import androidx.core.app.NotificationManagerCompat;
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;

/** Reuses the pinned notification plugin's protected renderer and tap protocol. */
public final class IntervalNotificationRenderer extends FlutterLocalNotificationsPlugin {
    public static void show(Context context, NotificationDetails details) {
        NotificationManagerCompat.from(context).notify(details.id, createNotification(context, details));
    }
}
