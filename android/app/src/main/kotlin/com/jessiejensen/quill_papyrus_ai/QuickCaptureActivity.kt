package com.jessiejensen.quill_papyrus_ai

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast

class QuickCaptureActivity : Activity() {

    private lateinit var etQuickNote: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_quick_capture)

        // Set dialog window width to match parent with reasonable margins
        window.setLayout(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )

        etQuickNote = findViewById(R.id.et_quick_note)
        val btnClose = findViewById<TextView>(R.id.btn_quick_cancel)
        val btnSave = findViewById<TextView>(R.id.btn_save_note)
        val btnOpenApp = findViewById<TextView>(R.id.btn_open_app)

        btnClose.setOnClickListener {
            dismissAndClose()
        }

        btnSave.setOnClickListener {
            val text = etQuickNote.text.toString().trim()
            if (text.isEmpty()) {
                Toast.makeText(this, "Please enter a note", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            val saved = QuickNoteWriter.saveQuickNote(this, text)
            if (saved != null) {
                Toast.makeText(this, "Note saved to QuickNotes", Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(this, "Failed to save note", Toast.LENGTH_SHORT).show()
            }
            dismissAndClose()
        }

        btnOpenApp.setOnClickListener {
            val text = etQuickNote.text.toString().trim()
            if (text.isNotEmpty()) {
                QuickNoteWriter.saveQuickNote(this, text)
            }

            // Launch full app
            val intent = Intent(this, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("quillpapyrus://quick-note")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(intent)
            dismissAndClose()
        }

        // Auto-focus input and show soft keyboard
        etQuickNote.requestFocus()
        etQuickNote.postDelayed({
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.showSoftInput(etQuickNote, InputMethodManager.SHOW_IMPLICIT)
        }, 150)
    }

    private fun dismissAndClose() {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.hideSoftInputFromWindow(etQuickNote.windowToken, 0)
        finish()
        overridePendingTransition(0, 0)
    }
}
