package com.jessiejensen.quill_papyrus_ai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.core.app.RemoteInput

class QuickNoteNotificationReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            QuickNoteNotificationHelper.ACTION_SUBMIT_NOTE -> {
                val remoteInput = RemoteInput.getResultsFromIntent(intent)
                val text = remoteInput?.getCharSequence(QuickNoteNotificationHelper.KEY_QUICK_NOTE_INPUT)?.toString()?.trim()

                if (!text.isNullOrEmpty()) {
                    val saved = QuickNoteWriter.saveQuickNote(context, text)
                    if (saved != null) {
                        Toast.makeText(context, "Note saved to QuickNotes", Toast.LENGTH_SHORT).show()
                        val snippet = text.lines().firstOrNull { it.isNotBlank() } ?: text
                        val preview = if (snippet.length > 25) snippet.take(22) + "..." else snippet
                        QuickNoteNotificationHelper.showQuickNoteNotification(context, "Saved: $preview")
                    } else {
                        Toast.makeText(context, "Failed to save note", Toast.LENGTH_SHORT).show()
                    }
                }
            }
            QuickNoteNotificationHelper.ACTION_DISMISS_NOTIFICATION -> {
                QuickNoteNotificationHelper.cancelNotification(context)
            }
        }
    }
}
