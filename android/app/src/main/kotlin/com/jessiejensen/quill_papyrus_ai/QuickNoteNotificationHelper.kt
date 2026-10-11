package com.jessiejensen.quill_papyrus_ai

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput

object QuickNoteNotificationHelper {
    const val CHANNEL_ID = "quill_quick_note_channel"
    const val NOTIFICATION_ID = 10099
    const val KEY_QUICK_NOTE_INPUT = "key_quick_note_text"
    const val ACTION_SUBMIT_NOTE = "com.jessiejensen.quill_papyrus_ai.SUBMIT_QUICK_NOTE"
    const val ACTION_DISMISS_NOTIFICATION = "com.jessiejensen.quill_papyrus_ai.DISMISS_QUICK_NOTE_NOTIFICATION"

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Quick Note Capture"
            val descriptionText = "Persistent notification to quickly type notes from notification shade"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(false)
            }
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun showQuickNoteNotification(context: Context, statusMessage: String? = null) {
        createNotificationChannel(context)

        // RemoteInput for inline typing directly inside notification
        val remoteInput = RemoteInput.Builder(KEY_QUICK_NOTE_INPUT)
            .setLabel("Type note and send...")
            .build()

        // PendingIntent for submitting the typed note
        val submitIntent = Intent(context, QuickNoteNotificationReceiver::class.java).apply {
            action = ACTION_SUBMIT_NOTE
        }
        val submitPendingIntent = PendingIntent.getBroadcast(
            context,
            2001,
            submitIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        val replyAction = NotificationCompat.Action.Builder(
            R.drawable.ic_note_add,
            "Type Note",
            submitPendingIntent
        )
            .addRemoteInput(remoteInput)
            .setAllowGeneratedReplies(true)
            .build()

        // Intent when clicking the notification body -> QuickCaptureActivity
        val openPopupIntent = Intent(context, QuickCaptureActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPopupPendingIntent = PendingIntent.getActivity(
            context,
            2002,
            openPopupIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Dismiss action
        val dismissIntent = Intent(context, QuickNoteNotificationReceiver::class.java).apply {
            action = ACTION_DISMISS_NOTIFICATION
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            context,
            2003,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_note_add)
            .setContentTitle("Quill Quick Note")
            .setContentText(statusMessage ?: "Tap 'Type Note' to capture without opening app")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(openPopupPendingIntent)
            .addAction(replyAction)
            .addAction(0, "Dismiss", dismissPendingIntent)
            .setAutoCancel(false)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }

    fun cancelNotification(context: Context) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }
}
