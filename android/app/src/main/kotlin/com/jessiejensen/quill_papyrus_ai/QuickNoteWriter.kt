package com.jessiejensen.quill_papyrus_ai

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object QuickNoteWriter {
    const val KEY_WORKSPACE_ROOT = "workspace_root"

    fun getWorkspaceDirectory(context: Context): File {
        val prefs = context.getSharedPreferences(QuickNoteAppWidget.PREFS_NAME, Context.MODE_PRIVATE)
        val customPath = prefs.getString(KEY_WORKSPACE_ROOT, null)
        if (!customPath.isNullOrEmpty()) {
            val dir = File(customPath)
            if (dir.exists() && dir.canWrite()) return dir
        }

        // Standard Documents/QuillPapyrus folder on Android
        val standardDir = File("/storage/emulated/0/Documents/QuillPapyrus")
        if (standardDir.exists() || standardDir.mkdirs()) {
            return standardDir
        }

        // Fallback to app external files dir or internal files dir
        return context.getExternalFilesDir(null) ?: context.filesDir
    }

    fun saveQuickNote(context: Context, text: String, titleSuffix: String = ""): File? {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return null

        try {
            val root = getWorkspaceDirectory(context)
            val quickNotesDir = File(root, "QuickNotes")
            if (!quickNotesDir.exists()) {
                quickNotesDir.mkdirs()
            }

            val now = Date()
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
            val fileTimeFormat = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault())

            val dateStr = dateFormat.format(now)
            val timeStr = timeFormat.format(now)
            val fileStamp = fileTimeFormat.format(now)

            val fileName = "Note_$fileStamp.md"
            val file = File(quickNotesDir, fileName)

            val displayTitle = if (titleSuffix.isNotBlank()) "Quick Note - $titleSuffix" else "Quick Note - $dateStr $timeStr"
            val markdown = """---
title: $displayTitle
tags: [quicknote, inbox]
date: $dateStr $timeStr
---

$trimmed
""".trimIndent()

            file.writeText(markdown)

            // Update widget snippet in SharedPreferences
            val firstLine = trimmed.lines().firstOrNull { it.isNotBlank() } ?: "Note created at $timeStr"
            val snippet = if (firstLine.length > 80) firstLine.take(77) + "..." else firstLine

            val prefs = context.getSharedPreferences(QuickNoteAppWidget.PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(QuickNoteAppWidget.KEY_RECENT_TITLE, "Quick Note ($timeStr)")
                .putString(QuickNoteAppWidget.KEY_RECENT_SNIPPET, snippet)
                .apply()

            QuickNoteAppWidget.updateAllWidgets(context)
            return file
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
}
