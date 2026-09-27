package eu.tapredeem.waiter

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.nfc.FormatException
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.MifareUltralight
import android.nfc.tech.Ndef
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Card reading on Android (09 §7.1, 03a §6.1) behind the channels
 * `giftcard_waiter/nfc` and `giftcard_waiter/nfc/events`.
 *
 * Reader mode runs only while Dart asked for it AND the activity is resumed
 * (and, in multi-window, the top resumed activity). Events are always posted
 * on the main thread; events produced before Dart subscribes (a background tap
 * that launched the app) are buffered and delivered on subscription.
 */
internal class WaiterNfc(private val activity: Activity) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    NfcAdapter.ReaderCallback {

    private val adapter: NfcAdapter? =
        if (activity.packageManager.hasSystemFeature(PackageManager.FEATURE_NFC)) {
            NfcAdapter.getDefaultAdapter(activity)
        } else {
            null
        }
    private val mainHandler = Handler(Looper.getMainLooper())
    private val intentReader: ExecutorService = Executors.newSingleThreadExecutor()

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private val pending = ArrayDeque<Map<String, Any?>>()

    private var readerRequested = false
    private var resumed = false
    private var topResumed = true
    private var readerActive = false

    private val adapterStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != NfcAdapter.ACTION_ADAPTER_STATE_CHANGED) return
            val state = when (intent.getIntExtra(NfcAdapter.EXTRA_ADAPTER_STATE, NfcAdapter.STATE_OFF)) {
                NfcAdapter.STATE_ON -> STATE_ENABLED
                NfcAdapter.STATE_OFF -> STATE_DISABLED
                else -> return // STATE_TURNING_ON / STATE_TURNING_OFF
            }
            // The NFC service drops reader mode while the adapter is off; apply it
            // again once the adapter is back on.
            readerActive = false
            applyReaderMode()
            deliver(mapOf("type" to "adapter", "state" to state))
        }
    }
    private var receiverRegistered = false

    init {
        if (adapter != null) {
            val filter = IntentFilter(NfcAdapter.ACTION_ADAPTER_STATE_CHANGED)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                activity.registerReceiver(adapterStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                activity.registerReceiver(adapterStateReceiver, filter)
            }
            receiverRegistered = true
        }
    }

    // region Engine binding

    fun attach(messenger: BinaryMessenger) {
        methodChannel = MethodChannel(messenger, METHOD_CHANNEL).also { it.setMethodCallHandler(this) }
        eventChannel = EventChannel(messenger, EVENT_CHANNEL).also { it.setStreamHandler(this) }
    }

    fun detach() {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        sink = null
        readerRequested = false
        applyReaderMode()
    }

    fun dispose() {
        detach()
        if (receiverRegistered) {
            activity.unregisterReceiver(adapterStateReceiver)
            receiverRegistered = false
        }
        intentReader.shutdownNow()
        mainHandler.removeCallbacksAndMessages(null)
    }

    // endregion

    // region Activity lifecycle

    fun onResume() {
        resumed = true
        applyReaderMode()
    }

    fun onPause() {
        resumed = false
        applyReaderMode()
    }

    /** Multi-window (API 29+): reader mode only while the app window is focused (09 §7.11). */
    fun onTopResumedActivityChanged(isTopResumed: Boolean) {
        topResumed = isTopResumed
        applyReaderMode()
    }

    /**
     * A card tapped while the app was not in the foreground (NDEF_DISCOVERED
     * intent filter). The tag becomes an ordinary `tag` event. The URI is
     * removed from the intent so the app_links plugin does not report the same
     * tap again as a link. Must run before the activity forwards the intent to
     * Flutter (before `super.onCreate` / `super.onNewIntent`).
     */
    fun handleIntent(intent: Intent?, restoredActivity: Boolean) {
        if (intent == null || intent.action != NfcAdapter.ACTION_NDEF_DISCOVERED) return
        val tag = intent.tagExtra()
        intent.data = null
        val fromHistory = intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0
        if (restoredActivity || fromHistory || tag == null) return
        intentReader.execute { emit(readTag(tag)) }
    }

    // endregion

    // region MethodChannel

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> result.success(availability())
            "readerMode" -> {
                readerRequested = call.argument<Boolean>("enabled") == true
                applyReaderMode()
                result.success(null)
            }
            "openSettings" -> {
                openNfcSettings()
                result.success(null)
            }
            // iPhone-only session methods.
            else -> result.notImplemented()
        }
    }

    private fun availability(): String {
        val nfc = adapter ?: return STATE_UNSUPPORTED
        return if (nfc.isEnabled) STATE_ENABLED else STATE_DISABLED
    }

    private fun openNfcSettings() {
        try {
            activity.startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
        } catch (_: ActivityNotFoundException) {
            try {
                activity.startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
            } catch (_: ActivityNotFoundException) {
                // No settings activity on this device; the S16 button then does nothing.
            }
        }
    }

    // endregion

    // region EventChannel

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        while (pending.isNotEmpty()) {
            events.success(pending.removeFirst())
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    /** Posts [event] to the main thread (reader callbacks arrive on a binder thread). */
    private fun emit(event: Map<String, Any?>) {
        mainHandler.post { deliver(event) }
    }

    private fun deliver(event: Map<String, Any?>) {
        val events = sink
        if (events != null) {
            events.success(event)
            return
        }
        if (pending.size >= MAX_BUFFERED_EVENTS) pending.removeFirst()
        pending.addLast(event)
    }

    // endregion

    // region Reader mode

    private fun applyReaderMode() {
        val nfc = adapter ?: return
        val shouldRun = readerRequested && resumed && topResumed && nfc.isEnabled
        if (shouldRun == readerActive) return
        try {
            if (shouldRun) {
                val extras = Bundle().apply {
                    putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, PRESENCE_CHECK_DELAY_MS)
                }
                nfc.enableReaderMode(activity, this, READER_FLAGS, extras)
            } else {
                nfc.disableReaderMode(activity)
            }
            readerActive = shouldRun
        } catch (_: IllegalStateException) {
            // The activity is not in the resumed state; the next onResume applies it.
            readerActive = false
        }
    }

    /** Binder thread. The NDEF check is left enabled, so the message is cached on the tag. */
    override fun onTagDiscovered(tag: Tag) {
        emit(readTag(tag))
    }

    // endregion

    // region Tag parsing

    private fun readTag(tag: Tag): Map<String, Any?> {
        val uid = formatUid(tag.id)
        val ndef = Ndef.get(tag)
            ?: return if (isUnreadNdefUltralight(tag)) READ_FAILED else tagEvent(uid, null)

        val message: NdefMessage? = ndef.cachedNdefMessage ?: try {
            ndef.connect()
            ndef.ndefMessage
        } catch (_: IOException) {
            return READ_FAILED
        } catch (_: FormatException) {
            return READ_FAILED
        } catch (_: SecurityException) {
            // Tag is out of date (already left the field).
            return READ_FAILED
        } finally {
            closeQuietly(ndef)
        }
        return tagEvent(uid, message?.let(::firstUri))
    }

    /**
     * An NTAG21x (MIFARE Ultralight family) that the system delivered without
     * the Ndef technology even though it is NDEF-formatted: the NDEF check was
     * interrupted (card moved away mid-read), so this is a read failure (L11),
     * not a foreign tag. Page 3 holds the Capability Container, magic 0xE1.
     */
    private fun isUnreadNdefUltralight(tag: Tag): Boolean {
        val ultralight = MifareUltralight.get(tag) ?: return false
        return try {
            ultralight.connect()
            val pages = ultralight.readPages(CAPABILITY_CONTAINER_PAGE)
            pages.isNotEmpty() && pages[0] == NDEF_MAGIC
        } catch (_: IOException) {
            true
        } catch (_: SecurityException) {
            true
        } finally {
            try {
                ultralight.close()
            } catch (_: IOException) {
                // Nothing to release.
            }
        }
    }

    private fun closeQuietly(ndef: Ndef) {
        try {
            ndef.close()
        } catch (_: IOException) {
            // Nothing to release.
        }
    }

    // endregion

    private companion object {
        const val METHOD_CHANNEL = "giftcard_waiter/nfc"
        const val EVENT_CHANNEL = "giftcard_waiter/nfc/events"

        /** NFC-A only (NTAG21x, NTAG 424 DNA), no platform sounds; NDEF check stays on. */
        const val READER_FLAGS = NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS
        const val PRESENCE_CHECK_DELAY_MS = 250
        const val MAX_BUFFERED_EVENTS = 8

        const val CAPABILITY_CONTAINER_PAGE = 3
        const val NDEF_MAGIC: Byte = 0xE1.toByte()

        const val STATE_ENABLED = "enabled"
        const val STATE_DISABLED = "disabled"
        const val STATE_UNSUPPORTED = "unsupported"

        val READ_FAILED: Map<String, Any?> = mapOf("type" to "readFailed")

        fun tagEvent(uid: String, url: String?): Map<String, Any?> =
            mapOf("type" to "tag", "uid" to uid, "url" to url)

        /** `04:A2:3F:1B:6C:80:12` — upper-case hex bytes joined by colons. */
        fun formatUid(id: ByteArray?): String =
            id?.joinToString(":") { byte -> "%02X".format(byte.toInt() and 0xFF) }.orEmpty()

        /** First well-known URI (or smart poster URI) or absolute-URI record. */
        fun firstUri(message: NdefMessage): String? {
            for (record in message.records) {
                val isUriRecord = when (record.tnf) {
                    NdefRecord.TNF_ABSOLUTE_URI -> true
                    NdefRecord.TNF_WELL_KNOWN ->
                        record.type.contentEquals(NdefRecord.RTD_URI) ||
                            record.type.contentEquals(NdefRecord.RTD_SMART_POSTER)
                    else -> false
                }
                if (!isUriRecord) continue
                val uri = record.toUri() ?: continue
                return uri.toString()
            }
            return null
        }

        fun Intent.tagExtra(): Tag? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
            } else {
                @Suppress("DEPRECATION")
                getParcelableExtra(NfcAdapter.EXTRA_TAG)
            }
    }
}
