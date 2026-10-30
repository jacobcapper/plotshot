package com.plotshot.app

import android.content.Intent
import android.os.Bundle
import com.plotshot.app.widgets.Widgets
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required for the Health Connect permission flow.
class MainActivity : FlutterFragmentActivity() {
    private var widgetChannel: MethodChannel? = null

    // The widget link that launched the app, held until Dart asks for it.
    private var pendingLaunch: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        if (savedInstanceState == null) pendingLaunch = Widgets.launchLink(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Widgets.CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    Widgets.save(this, call.arguments as String)
                    result.success(null)
                }
                "takeLaunch" -> {
                    result.success(pendingLaunch)
                    pendingLaunch = null
                }
                else -> result.notImplemented()
            }
        }
        widgetChannel = channel
    }

    // A widget tapped while the app is open (launchMode is singleTop).
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val link = Widgets.launchLink(intent) ?: return
        val channel = widgetChannel
        if (channel == null) pendingLaunch = link else channel.invokeMethod("launch", link)
    }
}
