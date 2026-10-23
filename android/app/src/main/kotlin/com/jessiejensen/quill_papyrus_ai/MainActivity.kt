package com.jessiejensen.quill_papyrus_ai

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.view.WindowInsets
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val STORAGE_CHANNEL = "com.jessiejensen.quill_papyrus_ai/storage_permissions"
    private val WIDGET_CHANNEL = "com.jessiejensen.quill_papyrus_ai/widget"
    private val DEVICE_CHANNEL = "com.jessiejensen.quill_papyrus_ai/device_mode"

    private var widgetChannel: MethodChannel? = null
    private var deviceChannel: MethodChannel? = null
    private var pendingActionUri: String? = null

    private fun isDeXMode(): Boolean {
        val config = resources.configuration
        try {
            val configClass = config.javaClass
            val semDesktopModeEnabled = configClass.getField("SEM_DESKTOP_MODE_ENABLED").getInt(configClass)
            val semDesktopMode = configClass.getField("semDesktopModeEnabled").getInt(config)
            if (semDesktopMode == semDesktopModeEnabled) return true
        } catch (_: Exception) {}

        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? android.app.UiModeManager
        if (uiModeManager?.currentModeType == 8 /* Configuration.UI_MODE_TYPE_DESKTOP */) {
            return true
        }
        val configStr = config.toString()
        return configStr.contains("desk-mode=enabled") || configStr.contains("semDesktopModeEnabled=1")
    }

    private fun isMultiWindow(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            isInMultiWindowMode
        } else {
            false
        }
    }

    private fun notifyDeviceModeChanged() {
        val map = mapOf(
            "isDeX" to isDeXMode(),
            "isMultiWindow" to isMultiWindow()
        )
        deviceChannel?.invokeMethod("onDeviceModeChanged", map)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.decorView.setOnApplyWindowInsetsListener { view, insets ->
                if (isMultiWindow() || isDeXMode()) {
                    val statusBarInsets = insets.getInsets(WindowInsets.Type.statusBars())
                    if (statusBarInsets.top > 0) {
                        val newInsets = WindowInsets.Builder(insets)
                            .setInsets(
                                WindowInsets.Type.statusBars(),
                                android.graphics.Insets.of(statusBarInsets.left, 0, statusBarInsets.right, statusBarInsets.bottom)
                            )
                            .build()
                        view.onApplyWindowInsets(newInsets)
                    } else {
                        view.onApplyWindowInsets(insets)
                    }
                } else {
                    view.onApplyWindowInsets(insets)
                }
            }
        }
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration?) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        notifyDeviceModeChanged()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        notifyDeviceModeChanged()
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

        val devChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
        deviceChannel = devChannel
        devChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceMode" -> {
                    val map = mapOf(
                        "isDeX" to isDeXMode(),
                        "isMultiWindow" to isMultiWindow()
                    )
                    result.success(map)
                }
                else -> result.notImplemented()
            }
        }
    }
}
