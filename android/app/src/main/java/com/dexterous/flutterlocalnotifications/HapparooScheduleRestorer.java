package com.dexterous.flutterlocalnotifications;

import android.content.Context;

/**
 * flutter_local_notifications 17.2.4 restores schedules from
 * {@code FlutterLocalNotificationsPlugin.rescheduleNotifications}, which is
 * package-private. The boot receiver in that package is the supported path.
 * This app class lives in the same package so a timezone change can call it
 * after the stored local date is pointed at the new zone.
 */
public final class HapparooScheduleRestorer {
    private HapparooScheduleRestorer() {}

    public static void reschedule(Context context) {
        FlutterLocalNotificationsPlugin.rescheduleNotifications(context);
    }
}
