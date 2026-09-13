package com.tori.pulse

import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

/** Receives explicit Android text shares and hands them to Flutter for review. */
class ShareIntentBridge(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "com.tori.pulse/share")
    private val pending = ArrayDeque<Map<String, String>>()

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "consumePendingShare" -> result.success(if (pending.isEmpty()) null else pending.removeFirst())
            else -> result.notImplemented()
        }
    }

    fun handleIntent(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_SEND) return false
        val sharedText = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim().orEmpty()
        if (sharedText.isEmpty()) return false

        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim().orEmpty()
        val payload = mutableMapOf(
            "text" to sharedText.take(MAX_SHARED_TEXT_LENGTH),
            "mimeType" to (intent.type ?: "text/plain"),
        )
        if (subject.isNotEmpty()) payload["subject"] = subject.take(MAX_SUBJECT_LENGTH)

        if (pending.size >= MAX_PENDING_SHARES) pending.removeFirst()
        pending.addLast(payload)
        channel.invokeMethod("sharedContentAvailable", null)
        return true
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pending.clear()
    }

    companion object {
        private const val MAX_PENDING_SHARES = 8
        private const val MAX_SHARED_TEXT_LENGTH = 20_000
        private const val MAX_SUBJECT_LENGTH = 500
    }
}
