package com.iris.iris_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private var sink: EventChannel.EventSink? = null
    private var initialUrl: String? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initialUrl = intent?.dataString
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "com.iris.app/device").setMethodCallHandler { call, result ->
            if (call.method == "timeZone") result.success(TimeZone.getDefault().id)
            else result.notImplemented()
        }
        MethodChannel(messenger, "com.iris.app/deep_link").setMethodCallHandler { call, result ->
            if (call.method == "getInitialUrl") { result.success(initialUrl); initialUrl = null }
            else result.notImplemented()
        }
        EventChannel(messenger, "com.iris.app/deep_link_events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
            override fun onCancel(arguments: Any?) { sink = null }
        })
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.dataString?.let { if (sink != null) sink?.success(it) else initialUrl = it }
    }
}
