package com.example.birthday_app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("NotificationReceiver", "🔔 NOTIFICATION RECEIVER TRIGGERED!")
        
        // Acquire wake lock to ensure device stays awake long enough to show notification
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "EventTracker::NotificationWakeLock"
        )
        
        try {
            wakeLock.acquire(10 * 1000L) // Hold for 10 seconds
            
            val notificationId = intent.getIntExtra("notification_id", 9997)
            val title = intent.getStringExtra("title") ?: "Event Reminder"
            val body = intent.getStringExtra("body") ?: "Notification triggered"
            val channelId = intent.getStringExtra("channel_id") ?: "event_reminder"
            
            Log.d("NotificationReceiver", "Creating notification: ID=$notificationId, Title=$title, Channel=$channelId")
            
            // Create intent to open app when notification is tapped
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                notificationId,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            try {
                // Use the app icon instead of system icon
                val iconRes = context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName)
                val icon = if (iconRes != 0) iconRes else android.R.drawable.ic_dialog_info
                
                val notification = NotificationCompat.Builder(context, channelId)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setSmallIcon(icon)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setDefaults(NotificationCompat.DEFAULT_ALL) // Sound, vibration, lights
                    .setAutoCancel(true)
                    .setContentIntent(pendingIntent)
                    .setCategory(NotificationCompat.CATEGORY_REMINDER)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setShowWhen(true)
                    .build()
                
                val notificationManager = NotificationManagerCompat.from(context)
                
                // Ensure notification channel exists and is enabled
                if (notificationManager.areNotificationsEnabled()) {
                    notificationManager.notify(notificationId, notification)
                    Log.d("NotificationReceiver", "✓ Notification displayed successfully")
                } else {
                    Log.e("NotificationReceiver", "❌ Notifications are disabled for this app")
                }
            } catch (e: Exception) {
                Log.e("NotificationReceiver", "❌ Error showing notification: ${e.message}", e)
            }
        } finally {
            // Release wake lock
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
    }
}

