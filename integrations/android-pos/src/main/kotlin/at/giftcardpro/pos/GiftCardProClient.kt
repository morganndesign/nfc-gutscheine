package at.giftcardpro.pos

import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/**
 * An error answer of the GiftCard Pro API. [code] is stable (e.g. `INSUFFICIENT_BALANCE`, `CARD_NOT_USABLE`);
 * [message] is a human sentence in the language of `Accept-Language`; [context] carries details (e.g. `reason`).
 */
class GiftCardProException(val status: Int, val code: String, message: String, val context: JSONObject?) : Exception(message) {
    val reason: String? get() = context?.optString("reason")?.takeIf { it.isNotEmpty() }
}

/** The HTTP layer, replaceable (OkHttp, Ktor, tests). */
interface HttpTransport {
    /** @return status code and body; throws [IOException] when no answer arrived. */
    fun send(method: String, url: String, headers: Map<String, String>, body: String?): Pair<Int, String>
}

class UrlConnectionTransport(private val timeoutMs: Int = 10_000) : HttpTransport {
    override fun send(method: String, url: String, headers: Map<String, String>, body: String?): Pair<Int, String> {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = timeoutMs
            connection.readTimeout = timeoutMs
            headers.forEach { (k, v) -> connection.setRequestProperty(k, v) }
            if (body != null) {
                connection.doOutput = true
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val status = connection.responseCode
            val stream = if (status >= 400) connection.errorStream else connection.inputStream
            return status to (stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: "")
        } finally {
            connection.disconnect()
        }
    }
}

/**
 * GiftCard Pro for a till app (POS partner API `/api/partner/v1`). One instance per till and restaurant:
 *
 * ```
 * val gcp = GiftCardProClient(partnerKey = BuildConfig.GCP_KEY, connectionId = restaurant.gcpConnectionId,
 *                             terminalId = till.id, terminalName = till.name, language = "de")
 * val presented = gcp.readCard(IsoDepCardChannel(isoDep))      // on a background thread, card on the reader
 * val amount = presented.payable(billCents)                   // ask the guest, then:
 * val redemption = gcp.redeem(presented.id, amount, reference = bill.number, staff = waiter.name)
 * ```
 *
 * Every call blocks: call it from a background thread (coroutine on Dispatchers.IO, executor), never the UI thread.
 */
class GiftCardProClient(
    private val partnerKey: String,
    private val connectionId: String?,
    private val terminalId: String,
    private val terminalName: String? = null,
    private val baseUrl: String = "https://app.giftcardpro.at",
    private val language: String = "de",
    private val transport: HttpTransport = UrlConnectionTransport(),
) {
    init {
        require(partnerKey.startsWith("gcpp_")) { "A GiftCard Pro partner key starts with gcpp_" }
        require(Regex("^[A-Za-z0-9._-]{4,64}$").matches(terminalId)) { "terminalId: 4–64 characters A–Z a–z 0–9 . _ -" }
    }

    // ------------------------------------------------------------------ setup

    /** Connects a restaurant with the one-time code its owner created (Settings › Kassensysteme). Store the id. */
    fun connect(code: String): Connection = Json.connection(call("POST", "connections", JSONObject().put("code", code), withConnection = false))

    /** The connected restaurant and its redemption rules (also a health check of key and connection). */
    fun connection(): Connection = Json.connection(call("GET", "connection", null))

    // ------------------------------------------------------------------ redeeming

    /**
     * A gift card on the reader: reads it, relays its live authentication to GiftCard Pro and returns the voucher
     * behind it. Keep the card on the reader until this returns (about 300 ms).
     *
     * @throws CardProtocolException not a GiftCard Pro card, or moved away – ask to hold it again
     * @throws GiftCardProException e.g. CARD_NOT_USABLE (suspended, other restaurant), CARD_AUTHENTICATION_FAILED
     */
    fun readCard(card: CardChannel): Presentment {
        val tap = Ntag424.read(card)
        val begun = call("POST", "cards/authentications", JSONObject()
            .put("tap_url", tap.tapUrl).put("rf_uid", tap.rfUidHex).put("challenge", tap.challengeHex))
        val response = Ntag424.answer(card, begun.getString("command"))
        return Json.presentment(call("POST", "cards/authentications/" + begun.getString("authentication"), JSONObject().put("response", response)))
    }

    /** A printed or e-mailed voucher: the text of its QR code (starts with `GCPV1.`). */
    fun scanQr(code: String): Presentment = Json.presentment(call("POST", "vouchers/scan", JSONObject().put("code", code)))

    /**
     * Debits [amountCents] from the presented voucher. Safe to repeat: when no answer arrives (network), it asks
     * GiftCard Pro whether the booking went through and repeats it with the same [idempotencyKey] only if not –
     * a voucher is never debited twice.
     */
    fun redeem(
        presentmentId: String,
        amountCents: Long,
        reference: String? = null,
        staff: String? = null,
        idempotencyKey: String = UUID.randomUUID().toString(),
        attempts: Int = 3,
    ): Redemption {
        val body = JSONObject().put("presentment_id", presentmentId).put("amount", amountCents)
        if (reference != null) body.put("reference", reference)
        if (staff != null) body.put("staff", staff)
        var last: IOException? = null
        repeat(attempts) {
            try {
                return Json.redemption(call("POST", "redemptions", body, extra = mapOf("Idempotency-Key" to idempotencyKey)))
            } catch (e: IOException) {
                last = e
                try {
                    redemptionOutcome(idempotencyKey)?.let { return it }
                } catch (_: IOException) {
                    // Still offline: try again.
                }
            }
        }
        throw last ?: IOException("No answer from GiftCard Pro")
    }

    /** Was the redemption with this key booked? null: not booked (it can be sent again with the same key). */
    fun redemptionOutcome(idempotencyKey: String): Redemption? {
        val data = call("GET", "redemptions/$idempotencyKey", null)
        return if (data.getString("status") == "booked") Json.redemption(data) else null
    }

    /** The bill was cancelled: the amount goes back onto the voucher (own redemptions, within 60 minutes). */
    fun cancelRedemption(redemptionId: String, reason: String): Cancellation {
        val o = call("POST", "redemptions/$redemptionId/cancellation", JSONObject().put("reason", reason))
        return Cancellation(o.getString("id"), o.getString("cancelled_redemption_id"), o.getLong("amount"), o.getLong("balance_after"), o.getString("created_at"))
    }

    // ------------------------------------------------------------------ HTTP

    private fun call(method: String, path: String, body: JSONObject?, withConnection: Boolean = true, extra: Map<String, String> = emptyMap()): JSONObject {
        val headers = mutableMapOf(
            "Authorization" to "Bearer $partnerKey",
            "Accept" to "application/json",
            "Accept-Language" to language,
            "X-Terminal-Id" to terminalId,
        )
        if (body != null) headers["Content-Type"] = "application/json"
        if (terminalName != null) headers["X-Terminal-Name"] = terminalName
        if (withConnection) headers["X-Connection-Id"] = connectionId ?: throw IllegalStateException("No connection id: connect() first")
        headers.putAll(extra)
        val (status, text) = transport.send(method, baseUrl.trimEnd('/') + "/api/partner/v1/" + path, headers, body?.toString())
        val json = try { JSONObject(text) } catch (e: Exception) { JSONObject() }
        if (status >= 400) {
            throw GiftCardProException(status, json.optString("code", "HTTP_$status"), json.optString("message", "HTTP $status"), json.optJSONObject("context") ?: json.optJSONObject("errors"))
        }
        return json.optJSONObject("data") ?: throw IOException("Unexpected answer (HTTP $status)")
    }
}
