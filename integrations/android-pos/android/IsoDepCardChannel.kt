package at.giftcardpro.pos

import android.nfc.tech.IsoDep

/**
 * Android adapter: a card found in reader mode (`NfcAdapter.enableReaderMode` with FLAG_READER_NFC_A |
 * FLAG_READER_SKIP_NDEF_CHECK | FLAG_READER_NO_PLATFORM_SOUNDS) as a [CardChannel].
 *
 * ```
 * override fun onTagDiscovered(tag: Tag) {           // binder thread
 *     val isoDep = IsoDep.get(tag) ?: return
 *     executor.execute {
 *         isoDep.use { it.connect(); it.timeout = 2000
 *             val presented = gcp.readCard(IsoDepCardChannel(it))
 *             runOnUiThread { showVoucher(presented) }
 *         }
 *     }
 * }
 * ```
 */
class IsoDepCardChannel(private val isoDep: IsoDep) : CardChannel {
    override val uid: ByteArray get() = isoDep.tag.id
    override fun transceive(command: ByteArray): ByteArray = isoDep.transceive(command)
}
