package com.applausestudios.ekadashi_calendar.widget.ui

import android.content.Context
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import com.applausestudios.ekadashi_calendar.widget.model.WidgetPayload
import java.time.Instant

class WidgetPreviewFactory(private val messenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView = NativePreview(context, messenger, viewId, args as? Map<*, *>)
}

private class NativePreview(context: Context, messenger: BinaryMessenger, viewId: Int, args: Map<*, *>?) : PlatformView {
    private val channel = MethodChannel(messenger, "com.ekadashi.widget/preview/$viewId")
    private val host = WidgetPreviewHost(context) { channel.invokeMethod("openOccurrence", it) }
    init {
        args?.let(::update)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "update") {
                try { update(call.arguments as Map<*, *>); result.success(true) }
                catch (e: Exception) { result.error("INVALID_PREVIEW", e.message, null) }
            } else result.notImplemented()
        }
    }
    private fun update(args: Map<*, *>) {
        val payload = WidgetPayload.fromJsonString(args["payloadJson"] as String)
        host.update(payload, args["upcoming"] == true, (args["width"] as Number).toInt(), (args["height"] as Number).toInt(), Instant.parse(args["now"] as String))
    }
    override fun getView(): View = host
    override fun dispose() { channel.setMethodCallHandler(null); host.removeAllViews() }
}
