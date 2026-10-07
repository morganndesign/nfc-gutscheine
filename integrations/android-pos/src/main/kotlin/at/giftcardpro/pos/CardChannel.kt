package at.giftcardpro.pos

/**
 * A GiftCard Pro gift card on the till's NFC reader (ISO 14443-4). The till only relays bytes: it holds no key and
 * never decides whether a card is genuine – the GiftCard Pro server does.
 *
 * On Android: [IsoDepCardChannel] (android/IsoDepCardChannel.kt) wraps `android.nfc.tech.IsoDep`.
 */
interface CardChannel {
    /** The UID the reader saw on the radio layer (7 bytes, `Tag.getId()`). */
    val uid: ByteArray

    /** Sends one command (APDU) and returns the card's answer including the two status bytes. */
    fun transceive(command: ByteArray): ByteArray
}
