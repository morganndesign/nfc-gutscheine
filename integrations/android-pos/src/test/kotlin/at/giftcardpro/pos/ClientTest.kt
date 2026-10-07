package at.giftcardpro.pos

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.IOException

private const val KEY = "gcpp_testkey0123456789"
private const val CONNECTION = "0199a1b2-0000-7000-8000-000000000001"

/** A card that answers the GiftCard Pro sequence like an NTAG 424 DNA (and records what it was sent). */
private class FakeCard(private val url: String = "t.giftcardpro.at/ks-2026-01?e=AB&m=CD") : CardChannel {
    val sent = mutableListOf<String>()
    override val uid = Ntag424.hex("04A39493CC8680")
    override fun transceive(command: ByteArray): ByteArray {
        val hex = Ntag424.toHex(command)
        sent += hex
        return when {
            hex == "00A4040007D276000085010100" || hex == "00A4000C02E104" -> Ntag424.hex("9000")
            hex == "00B0000000" -> ndefFile(url) + Ntag424.hex("9000")
            hex == "9071000002030000" -> ByteArray(16) { 0x11 } + Ntag424.hex("91AF")
            hex.startsWith("90AF000020") -> ByteArray(32) { 0x22 } + Ntag424.hex("9100")
            else -> Ntag424.hex("6A82")
        }
    }

    private fun ndefFile(rest: String): ByteArray {
        val payload = byteArrayOf(0x04) + rest.toByteArray()
        val record = byteArrayOf(0xD1.toByte(), 0x01, payload.size.toByte(), 0x55) + payload
        return byteArrayOf(0, record.size.toByte()) + record
    }
}

private class FakeHttp(private val answers: MutableList<(String, String, Map<String, String>, String?) -> Pair<Int, String>>) : HttpTransport {
    val calls = mutableListOf<Triple<String, String, Map<String, String>>>()
    val bodies = mutableListOf<String?>()
    override fun send(method: String, url: String, headers: Map<String, String>, body: String?): Pair<Int, String> {
        calls += Triple(method, url, headers)
        bodies += body
        return answers.removeAt(0)(method, url, headers, body)
    }
}

private fun presentmentJson(balance: Long = 5000, redeemable: Boolean = true, partial: Boolean = true, method: String = "card") = """
    {"data":{"presentment_id":"p-1","expires_at":"2026-10-07T12:01:00+02:00","method":"$method",
     "voucher":{"id":"v-1","number":"1234 5678 9012 3456","status":"active","balance":$balance,"currency":"EUR","expires_at":null,"redeemable":$redeemable},
     "card":${if (method == "card") "{\"number\":\"B-2026-0001-0042\"}" else "null"},
     "rules":{"allow_partial_redemption":$partial,"max_debit_per_transaction":null}}}
""".trimIndent()

private val redemptionJson = """{"data":{"id":"t-1","amount":4500,"currency":"EUR","balance_after":500,"voucher_id":"v-1","voucher_number":"1234 5678 9012 3456","reference":"Bon 4711","created_at":"2026-10-07T12:00:30+02:00","replayed":false}}"""

class ClientTest {
    private fun client(http: HttpTransport) = GiftCardProClient(KEY, CONNECTION, "KASSE-01", "Theke", baseUrl = "https://example.test/", transport = http)

    @Test
    fun `reads a card with the fixed sequence and relays the server's command`() {
        val card = FakeCard()
        val http = FakeHttp(mutableListOf(
            { _, _, _, _ -> 200 to """{"data":{"authentication":"01JABCDEF0123456789","command":"90AF000020${"33".repeat(32)}00","expires_in":30}}""" },
            { _, _, _, _ -> 201 to presentmentJson() },
        ))
        val presented = client(http).readCard(card)

        assertEquals(listOf("00A4040007D276000085010100", "00A4000C02E104", "00B0000000", "9071000002030000", "90AF000020${"33".repeat(32)}00"), card.sent)
        assertEquals("https://example.test/api/partner/v1/cards/authentications", http.calls[0].second)
        val begin = JSONObject(http.bodies[0])
        assertEquals("https://t.giftcardpro.at/ks-2026-01?e=AB&m=CD", begin.getString("tap_url"))
        assertEquals("04A39493CC8680", begin.getString("rf_uid"))
        assertEquals("11".repeat(16), begin.getString("challenge"))
        assertEquals("https://example.test/api/partner/v1/cards/authentications/01JABCDEF0123456789", http.calls[1].second)
        assertEquals("22".repeat(32) + "9100", JSONObject(http.bodies[1]).getString("response"))
        val headers = http.calls[0].third
        assertEquals("Bearer $KEY", headers["Authorization"])
        assertEquals(CONNECTION, headers["X-Connection-Id"])
        assertEquals("KASSE-01", headers["X-Terminal-Id"])
        assertEquals("Theke", headers["X-Terminal-Name"])

        assertEquals(5000L, presented.voucher.balance)
        assertEquals("B-2026-0001-0042", presented.cardNumber)
        assertEquals(4500L, presented.payable(4500))
        assertEquals(5000L, presented.payable(9000))
    }

    @Test
    fun `whole-voucher restaurants and blocked vouchers pay only what the rules allow`() {
        val http = FakeHttp(mutableListOf({ _, _, _, _ -> 201 to presentmentJson(partial = false, method = "qr") }, { _, _, _, _ -> 201 to presentmentJson(redeemable = false, method = "qr") }))
        val whole = client(http).scanQr("GCPV1.abc")
        assertEquals(0L, whole.payable(4500))
        assertEquals(5000L, whole.payable(6000))
        assertEquals(0L, client(http).scanQr("GCPV1.abc").payable(6000))
    }

    @Test
    fun `a card that is not a GiftCard Pro card is refused before anything is sent`() {
        val http = FakeHttp(mutableListOf())
        val notOurs = object : CardChannel {
            override val uid = ByteArray(7)
            override fun transceive(command: ByteArray) = Ntag424.hex("6A82")
        }
        try {
            client(http).readCard(notOurs)
            fail()
        } catch (e: CardProtocolException) {
            assertEquals("select application", e.step)
        }
        assertTrue(http.calls.isEmpty())
    }

    @Test
    fun `errors carry the API code and reason`() {
        val http = FakeHttp(mutableListOf({ _, _, _, _ -> 422 to """{"message":"Nicht genug Guthaben.","code":"INSUFFICIENT_BALANCE","context":{"balance":500}}""" }))
        try {
            client(http).redeem("p-1", 4500)
            fail()
        } catch (e: GiftCardProException) {
            assertEquals(422, e.status)
            assertEquals("INSUFFICIENT_BALANCE", e.code)
            assertEquals("Nicht genug Guthaben.", e.message)
            assertEquals(500, e.context!!.getInt("balance"))
        }
    }

    @Test
    fun `a lost answer is resolved with the outcome and never booked twice`() {
        val keys = mutableListOf<String?>()
        val http = FakeHttp(mutableListOf(
            { _, _, h, _ -> keys += h["Idempotency-Key"]; throw IOException("timeout") },
            { _, url, _, _ -> assertTrue(url.endsWith("/redemptions/${keys[0]}")); 200 to """{"data":{"status":"not_booked"}}""" },
            { _, _, h, _ -> keys += h["Idempotency-Key"]; 201 to redemptionJson },
        ))
        val r = client(http).redeem("p-1", 4500, reference = "Bon 4711", staff = "Max")
        assertEquals(500L, r.balanceAfter)
        assertEquals(keys[0], keys[1])
        val body = JSONObject(http.bodies[0])
        assertEquals("Bon 4711", body.getString("reference"))
        assertEquals("Max", body.getString("staff"))

        // Booked although the answer was lost: the outcome is the result, no second POST.
        val http2 = FakeHttp(mutableListOf(
            { _, _, _, _ -> throw IOException("timeout") },
            { _, _, _, _ -> 200 to """{"data":{"status":"booked",${redemptionJson.substringAfter("{\"data\":{")}""" },
        ))
        assertEquals("t-1", client(http2).redeem("p-1", 4500).id)
        assertEquals(2, http2.calls.size)
        assertNull(client(FakeHttp(mutableListOf({ _, _, _, _ -> 200 to """{"data":{"status":"not_booked"}}""" }))).redemptionOutcome("k"))
    }

    @Test
    fun `NDEF URIs with long records and other prefixes`() {
        val long = byteArrayOf(0, 12, 0xC1.toByte(), 0x01, 0, 0, 0, 5, 0x55, 0x02, 'a'.code.toByte(), '.'.code.toByte(), 'a'.code.toByte(), 't'.code.toByte())
        assertEquals("https://www.a.at", Ntag424.parseNdefUri(long))
        try {
            Ntag424.parseNdefUri(byteArrayOf(0, 0, 0, 0, 0, 0, 0))
            fail()
        } catch (e: CardProtocolException) {
            assertEquals("NDEF", e.step)
        }
    }
}
