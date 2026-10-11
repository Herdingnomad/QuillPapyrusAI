package com.jessiejensen.quill_papyrus_ai

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val STORAGE_CHANNEL = "com.jessiejensen.quill_papyrus_ai/storage_permissions"
    private val WIDGET_CHANNEL = "com.jessiejensen.quill_papyrus_ai/widget"

    private var widgetChannel: MethodChannel? = null
    private var pendingActionUri: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val dataUri = intent?.dataString
        if (!dataUri.isNullOrEmpty()) {
            pendingActionUri = dataUri
            widgetChannel?.invokeMethod("onActionReceived", dataUri)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        result.success(Environment.isExternalStorageManager())
                    } else {
                        result.success(true)
                    }
                }
                "requestStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                            startActivity(intent)
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
        widgetChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialAction" -> {
                    val action = pendingActionUri
                    pendingActionUri = null
                    result.success(action)
                }
                "updateWidgetData" -> {
                    val title = call.argument<String>("title") ?: ""
                    val snippet = call.argument<String>("snippet") ?: ""
                    val prefs = getSharedPreferences(QuickNoteAppWidget.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString(QuickNoteAppWidget.KEY_RECENT_TITLE, title)
                        .putString(QuickNoteAppWidget.KEY_RECENT_SNIPPET, snippet)
                        .apply()
                    QuickNoteAppWidget.updateAllWidgets(applicationContext)
                    result.success(true)
                }
                "updateWorkspaceRoot" -> {
                    val root = call.argument<String>("root") ?: ""
                    if (root.isNotEmpty()) {
                        val prefs = getSharedPreferences(QuickNoteAppWidget.PREFS_NAME, Context.MODE_PRIVATE)
                        prefs.edit().putString(QuickNoteWriter.KEY_WORKSPACE_ROOT, root).apply()
                    }
                    result.success(true)
                }
                "showQuickNoteNotification" -> {
                    QuickNoteNotificationHelper.showQuickNoteNotification(applicationContext)
                    result.success(true)
                }
                "cancelQuickNoteNotification" -> {
                    QuickNoteNotificationHelper.cancelNotification(applicationContext)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
