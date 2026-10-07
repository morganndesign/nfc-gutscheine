package at.giftcardpro.pos

/** What the server needs to start a card's live authentication. */
data class CardTap(val tapUrl: String, val rfUidHex: String, val challengeHex: String)

/**
 * The card did not take part: [step] is the command it refused (not a GiftCard Pro card, damaged), `NDEF`, or
 * `tag_lost` when it was moved away from the reader. Ask the guest to hold it again.
 */
class CardProtocolException(val step: String, cause: Throwable? = null) : Exception("Card refused: $step", cause)

/**
 * The fixed NTAG 424 DNA command sequence a till relays. It reads only what the card shows anyone (its NDEF URL)
 * and starts the authentication with key 3; everything that needs a key happens on the GiftCard Pro server.
 */
object Ntag424 {
    private val SELECT_APPLICATION = hex("00A4040007D276000085010100")
    private val SELECT_NDEF_FILE = hex("00A4000C02E104")
    private val READ_NDEF_FILE = hex("00B0000000")

    /** AuthenticateEV2First, key 3 (the live challenge key; it has no write rights). */
    private val AUTHENTICATE_KEY_3 = hex("9071000002030000")

    fun read(card: CardChannel): CardTap {
        expect(card, SELECT_APPLICATION, "select application", ::iso)
        expect(card, SELECT_NDEF_FILE, "select NDEF file", ::iso)
        val file = expect(card, READ_NDEF_FILE, "read NDEF file", ::iso)
        val url = parseNdefUri(file)
        val challenge = expect(card, AUTHENTICATE_KEY_3, "authenticate", ::additionalFrame)
        if (challenge.size != 16) throw CardProtocolException("authenticate")
        return CardTap(url, toHex(card.uid), toHex(challenge))
    }

    /**
     * Relays the server's command (AuthenticateEV2First part 2) and returns the card's full answer as hex
     * (32 bytes and 91 00). A refusal by the card is returned as well: the server decides.
     */
    fun answer(card: CardChannel, commandHex: String): String = toHex(send(card, hex(commandHex)))

    /** The URI of the first NDEF record of an NDEF file (2-byte NLEN, then the message). */
    fun parseNdefUri(file: ByteArray): String {
        try {
            if (file.size < 7) throw CardProtocolException("NDEF")
            val length = (u(file[0]) shl 8) or u(file[1])
            if (length < 5 || length + 2 > file.size) throw CardProtocolException("NDEF")
            val message = file.copyOfRange(2, 2 + length)
            val header = u(message[0])
            val shortRecord = header and 0x10 != 0
            val hasId = header and 0x08 != 0
            val typeLength = u(message[1])
            var offset = 2
            val payloadLength: Int
            if (shortRecord) {
                payloadLength = u(message[offset]); offset += 1
            } else {
                payloadLength = (u(message[offset]) shl 24) or (u(message[offset + 1]) shl 16) or (u(message[offset + 2]) shl 8) or u(message[offset + 3])
                offset += 4
            }
            val idLength = if (hasId) u(message[offset++]) else 0
            if (header and 0x07 != 0x01 || typeLength != 1 || u(message[offset]) != 0x55) throw CardProtocolException("NDEF")
            offset += typeLength + idLength
            if (payloadLength < 1 || offset + payloadLength > message.size) throw CardProtocolException("NDEF")
            val rest = String(message, offset + 1, payloadLength - 1, Charsets.UTF_8)
            return when (u(message[offset])) {
                0x04 -> "https://$rest"
                0x03 -> "http://$rest"
                0x02 -> "https://www.$rest"
                0x01 -> "http://www.$rest"
                0x00 -> rest
                else -> throw CardProtocolException("NDEF")
            }
        } catch (e: CardProtocolException) {
            throw e
        } catch (e: Exception) {
            throw CardProtocolException("NDEF")
        }
    }

    private fun iso(sw1: Int, sw2: Int) = sw1 == 0x90 && sw2 == 0x00

    private fun additionalFrame(sw1: Int, sw2: Int) = sw1 == 0x91 && sw2 == 0xAF

    private fun expect(card: CardChannel, command: ByteArray, step: String, ok: (Int, Int) -> Boolean): ByteArray {
        val answer = send(card, command)
        if (answer.size < 2 || !ok(u(answer[answer.size - 2]), u(answer[answer.size - 1]))) throw CardProtocolException(step)
        return answer.copyOfRange(0, answer.size - 2)
    }

    /** Android reports a card taken away as TagLostException (an IOException). */
    private fun send(card: CardChannel, command: ByteArray): ByteArray = try {
        card.transceive(command)
    } catch (e: java.io.IOException) {
        throw CardProtocolException("tag_lost", e)
    }

    private fun u(b: Byte) = b.toInt() and 0xFF

    fun toHex(bytes: ByteArray): String = bytes.joinToString("") { "%02X".format(it.toInt() and 0xFF) }

    fun hex(s: String): ByteArray = ByteArray(s.length / 2) { i -> s.substring(i * 2, i * 2 + 2).toInt(16).toByte() }
}
