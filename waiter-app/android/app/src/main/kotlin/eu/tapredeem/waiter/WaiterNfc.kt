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

/**
 * The NTAG 424 DNA relay (Android): it finds an ISO 14443-4 card with reader mode and forwards command bytes
 * to it and the answers back, nothing else. It holds no key, parses no answer and stores nothing; the server
 * does all cryptography. Channel `giftcard_waiter/nfc`:
 *
 * - `availability` → "ready" | "disabled" | "unsupported"
 * - `start` → { uid: hex } once a card is on the phone (IsoDep connected)
 * - `transceive` { apdu: bytes } → bytes (data ‖ SW1 SW2)
 * - `stop` → closes the card and leaves reader mode
 *
 * Errors: "unsupported", "disabled", "busy", "cancelled", "tag_lost", "io".
 */
internal class WaiterNfc(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
    private val main = Handler(Looper.getMainLooper())

    /** Card I/O blocks; it never runs on the main thread. One card at a time, in order. */
    private val io: ExecutorService = Executors.newSingleThreadExecutor()

    private var pendingStart: MethodChannel.Result? = null
    private var card: IsoDep? = null
    private var readerMode = false

    fun dispose() {
        channel.setMethodCallHandler(null)
        closeSession("cancelled")
        io.shutdown()
    }

    /** The activity went to the background: reader mode ends with it. */
    fun onPause() {
        if (readerMode || card != null) closeSession("cancelled")
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
        pendingStart = result
        val flags = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
            NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS
        val extras = Bundle().apply { putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 250) }
        adapter!!.enableReaderMode(activity, { tag -> onTag(tag) }, flags, extras)
        readerMode = true
    }

    /** Called on a binder thread for every tag that comes into the field while reader mode is on. */
    private fun onTag(tag: Tag) {
        val isoDep = IsoDep.get(tag) ?: return // Not ISO 14443-4 (e.g. an old NTAG 21x): keep looking.
        io.execute {
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
        card?.let { closing -> io.execute { closeQuietly(closing) } }
        card = null
        if (readerMode) {
            try {
                adapter()?.disableReaderMode(activity)
            } catch (_: IllegalStateException) {
                // Activity no longer resumed: reader mode already ended.
            }
            readerMode = false
        }
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
