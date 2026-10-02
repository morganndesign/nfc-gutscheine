package eu.tapredeem.waiter

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.TagLostException
import android.nfc.tech.IsoDep
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * The NTAG 424 DNA relay (Android): it finds an ISO 14443-4 card with reader mode and forwards command bytes
 * to it and the answers back, nothing else. It holds no key, parses no answer and stores nothing; the server
 * does all cryptography. Channel `giftcard_waiter/nfc`:
 *
 * - `availability` → "ready" | "disabled" | "unsupported"
 * - `start` → { uid: hex } once a card is on the phone (IsoDep connected)
 * - `transceive` { apdu: bytes } → bytes (data ‖ SW1 SW2)
 * - `stop` → closes the card (reader mode stays on)
 *
 * Reader mode is on for as long as the app is in the foreground, also between two cards: a card nobody is
 * waiting for is ignored. Otherwise a card still lying on the phone after its tap (or after a failed one at
 * the station) went to Android itself — "New tag detected", or the browser opening the card's link.
 *
 * Errors: "unsupported", "disabled", "busy", "cancelled", "tag_lost", "io".
 */
internal class WaiterNfc(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
    private val main = Handler(Looper.getMainLooper())

    /** Card I/O blocks; it never runs on the main thread. One card at a time, in order. */
    private val io: ExecutorService = Executors.newSingleThreadExecutor()

    // Touched on the main thread only (method calls, onPause, and the io executor's main.post callbacks); the
    // binder thread (onTag) and the io thread never read or write them.
    private var pendingStart: MethodChannel.Result? = null
    private var card: IsoDep? = null
    private var readerMode = false

    fun dispose() {
        channel.setMethodCallHandler(null)
        closeSession("cancelled")
        leaveReaderMode()
        io.shutdown()
    }

    /** The activity is in the foreground: cards are the app's, not Android's. */
    fun onResume() {
        enterReaderMode()
    }

    /** The activity went to the background: reader mode ends with it. */
    fun onPause() {
        closeSession("cancelled")
        leaveReaderMode()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> result.success(availability())
            "start" -> start(result)
            "transceive" -> transceive(call.argument<ByteArray>("apdu"), result)
            "stop" -> {
                closeSession(null)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun adapter(): NfcAdapter? = NfcAdapter.getDefaultAdapter(activity)

    private fun availability(): String {
        val adapter = adapter() ?: return "unsupported"
        return if (adapter.isEnabled) "ready" else "disabled"
    }

    private fun start(result: MethodChannel.Result) {
        val adapter = adapter()
        when {
            adapter == null -> return result.error("unsupported", "This phone has no NFC.", null)
            !adapter.isEnabled -> return result.error("disabled", "NFC is switched off.", null)
            pendingStart != null || card != null -> return result.error("busy", "A card session is already open.", null)
        }
        // Already on since the app came to the foreground; NFC may have been switched on only just now. A card
        // already lying on the phone is not reported again: it is taken away and held again.
        if (!enterReaderMode()) {
            // The activity is not resumed (the app went to the background while Dart asked for a card). Without
            // this, the start stayed pending and every later start answered "busy" until the app was restarted.
            return result.error("cancelled", "The app is not in the foreground.", null)
        }
        pendingStart = result
    }

    /** Turns reader mode on (once); false when the activity is not in the foreground or NFC is off. */
    private fun enterReaderMode(): Boolean {
        if (readerMode) return true
        val adapter = adapter() ?: return false
        if (!adapter.isEnabled) return false
        val flags = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
            NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS
        val extras = Bundle().apply { putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 250) }
        return try {
            adapter.enableReaderMode(activity, { tag -> onTag(tag) }, flags, extras)
            readerMode = true
            true
        } catch (e: IllegalStateException) {
            false
        }
    }

    private fun leaveReaderMode() {
        if (!readerMode) return
        try {
            adapter()?.disableReaderMode(activity)
        } catch (_: IllegalStateException) {
            // Activity no longer resumed: reader mode already ended.
        }
        readerMode = false
    }

    /**
     * Called on a binder thread for every tag that comes into the field while reader mode is on. Whether anyone
     * waits for it is decided on the main thread after connecting (a card nobody waits for is closed again).
     */
    private fun onTag(tag: Tag) {
        val isoDep = IsoDep.get(tag) ?: return // Not ISO 14443-4 (e.g. an old NTAG 21x): keep looking.
        try {
            io.execute { connect(tag, isoDep) }
        } catch (e: RejectedExecutionException) {
            // The engine went away (dispose) while this tag was being reported on the binder thread.
        }
    }

    private fun connect(tag: Tag, isoDep: IsoDep) {
        try {
            isoDep.connect()
            isoDep.timeout = TIMEOUT_MS
            main.post {
                val result = pendingStart
                if (result == null) {
                    closeQuietly(isoDep)
                    return@post
                }
                pendingStart = null
                card = isoDep
                result.success(mapOf("uid" to tag.id.toHex()))
            }
        } catch (e: IOException) {
            closeQuietly(isoDep) // Moved away while connecting: wait for the next tap.
        }
    }

    private fun transceive(apdu: ByteArray?, result: MethodChannel.Result) {
        val isoDep = card
        if (isoDep == null || apdu == null) return result.error("tag_lost", "No card is open.", null)
        io.execute {
            try {
                val answer = isoDep.transceive(apdu)
                main.post { result.success(answer) }
            } catch (e: TagLostException) {
                main.post { result.error("tag_lost", "The card moved away.", null) }
            } catch (e: IOException) {
                main.post { result.error("tag_lost", e.message ?: "The card moved away.", null) }
            } catch (e: Exception) {
                main.post { result.error("io", e.message, null) }
            }
        }
    }

    private fun closeSession(pendingError: String?) {
        pendingStart?.error(pendingError ?: "cancelled", "The card session ended.", null)
        pendingStart = null
        card?.let { closing ->
            try {
                io.execute { closeQuietly(closing) }
            } catch (_: RejectedExecutionException) {
                closeQuietly(closing)
            }
        }
        card = null
    }

    private fun closeQuietly(isoDep: IsoDep) {
        try {
            isoDep.close()
        } catch (_: IOException) {
        }
    }

    private fun ByteArray.toHex(): String = joinToString("") { "%02X".format(it) }

    private companion object {
        const val CHANNEL = "giftcard_waiter/nfc"
        const val TIMEOUT_MS = 2000
    }
}
