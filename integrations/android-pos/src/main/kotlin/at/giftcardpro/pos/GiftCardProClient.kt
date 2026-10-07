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

/**
 * A redemption whose outcome is still unknown: no answer, or a server error, on every attempt. Do not hand the
 * guest's bill over as paid or unpaid yet – ask again later with [GiftCardProClient.redemptionOutcome]([idempotencyKey]).
 */
class RedemptionOutcomeUnknownException(val idempotencyKey: String, cause: Exception?) :
    IOException("Outcome of redemption $idempotencyKey unknown", cause)

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
 * Setting up restaurants – for your back office or setup screen, NOT for the tills: it holds your partner key
 * (`gcpp_…`), which must never be stored on a till.
 *
 * ```
 * val partner = GiftCardProPartner(partnerKey = secrets.gcpKey)
 * val access = partner.connect(codeTheOwnerGaveYou)   // once per restaurant
 * restaurant.gcpToken = access.token                    // store like a password; hand it to that restaurant's tills
 * ```
 */
class GiftCardProPartner(
    partnerKey: String,
    baseUrl: String = DEFAULT_URL,
    language: String = "de",
    transport: HttpTransport = UrlConnectionTransport(),
) {
    private val api = Api(partnerKey, baseUrl, language, transport)

    init {
        require(partnerKey.startsWith("gcpp_")) { "A GiftCard Pro partner key starts with gcpp_" }
    }

    /**
     * Connects a restaurant with the one-time code its owner created (Settings › Kassensysteme). The answer holds
     * the restaurant's till token: it is shown only this once – store it.
     */
    fun connect(code: String): TillAccess = Json.tillAccess(api.call("POST", "connections", JSONObject().put("code", code)))

    /** The restaurants connected to you. */
    fun connections(): List<Connection> {
        val list = api.callList("GET", "connections")
        return (0 until list.length()).map { Json.connection(list.getJSONObject(it)) }
    }

    /** A new till token for a connected restaurant (lost or leaked); the old token stops working at once. */
    fun newToken(connectionId: String): TillAccess = Json.tillAccess(api.call("POST", "connections/$connectionId/token", null))
}

/**
 * GiftCard Pro on a till (POS partner API `/api/partner/v1`). One instance per till, with the token of the
 * restaurant it stands in (from [GiftCardProPartner.connect]):
 *
 * ```
 * val gcp = GiftCardProClient(connectionToken = restaurant.gcpToken, terminalId = till.id, terminalName = till.name)
 * val presented = gcp.readCard(IsoDepCardChannel(isoDep))      // on a background thread, card on the reader
 * val amount = presented.payable(billCents)                   // ask the guest, then:
 * val redemption = gcp.redeem(presented.id, amount, reference = bill.number, staff = waiter.name)
 * ```
 *
 * Every call blocks: call it from a background thread (coroutine on Dispatchers.IO, executor), never the UI thread.
 */
class GiftCardProClient(
    connectionToken: String,
    terminalId: String,
    terminalName: String? = null,
    baseUrl: String = DEFAULT_URL,
    language: String = "de",
    transport: HttpTransport = UrlConnectionTransport(),
) {
    private val api: Api

    init {
        require(connectionToken.startsWith("gcpc_")) { "A GiftCard Pro till token starts with gcpc_ (the partner key gcpp_ does not belong on a till)" }
        require(Regex("^[A-Za-z0-9._-]{4,64}$").matches(terminalId)) { "terminalId: 4–64 characters A–Z a–z 0–9 . _ -" }
        val till = mutableMapOf("X-Terminal-Id" to terminalId)
        if (terminalName != null) till["X-Terminal-Name"] = terminalName
        api = Api(connectionToken, baseUrl, language, transport, till)
    }

    /** The restaurant of this token and its redemption rules (also a health check of the token). */
    fun connection(): Connection = Json.connection(api.call("GET", "connection", null))

    /**
     * A gift card on the reader: reads it, relays its live authentication to GiftCard Pro and returns the voucher
     * behind it. Keep the card on the reader until this returns (about 300 ms).
     *
     * @throws CardProtocolException not a GiftCard Pro card, or moved away (step `tag_lost`) – ask to hold it again
     * @throws GiftCardProException e.g. CARD_NOT_USABLE (suspended, other restaurant), CARD_AUTHENTICATION_FAILED
     */
    fun readCard(card: CardChannel): Presentment {
        val tap = Ntag424.read(card)
        val begun = api.call("POST", "cards/authentications", JSONObject()
            .put("tap_url", tap.tapUrl).put("rf_uid", tap.rfUidHex).put("challenge", tap.challengeHex))
        val response = Ntag424.answer(card, begun.getString("command"))
        return Json.presentment(api.call("POST", "cards/authentications/" + begun.getString("authentication"), JSONObject().put("response", response)))
    }

    /** A printed or e-mailed voucher: the text of its QR code (starts with `GCPV1.`). */
    fun scanQr(code: String): Presentment = Json.presentment(api.call("POST", "vouchers/scan", JSONObject().put("code", code)))

    /**
     * Debits [amountCents] from the presented voucher. Safe to repeat: when no answer arrives (network) or the
     * server fails (HTTP 5xx), it asks GiftCard Pro whether the booking went through and repeats it with the same
     * [idempotencyKey] only if not – a voucher is never debited twice.
     *
     * @throws RedemptionOutcomeUnknownException still unknown after [attempts]: ask [redemptionOutcome] later
     * @throws GiftCardProException refused (e.g. INSUFFICIENT_BALANCE, PRESENTMENT_EXPIRED): nothing was debited
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
        var last: Exception? = null
        repeat(attempts) {
            try {
                return Json.redemption(api.call("POST", "redemptions", body, mapOf("Idempotency-Key" to idempotencyKey)))
            } catch (e: Exception) {
                if (!unknownOutcome(e)) throw e
                last = e
                try {
                    redemptionOutcome(idempotencyKey)?.let { return it }
                } catch (check: Exception) {
                    if (!unknownOutcome(check)) throw check
                    // Still no reliable answer: try again.
                }
            }
        }
        throw RedemptionOutcomeUnknownException(idempotencyKey, last)
    }

    /** Was the redemption with this key booked? null: not booked (it can be sent again with the same key). */
    fun redemptionOutcome(idempotencyKey: String): Redemption? {
        val data = api.call("GET", "redemptions/$idempotencyKey", null)
        return if (data.getString("status") == "booked") Json.redemption(data) else null
    }

    /** The bill was cancelled: the amount goes back onto the voucher (own redemptions, within 60 minutes). */
    fun cancelRedemption(redemptionId: String, reason: String): Cancellation {
        val o = api.call("POST", "redemptions/$redemptionId/cancellation", JSONObject().put("reason", reason))
        return Cancellation(o.getString("id"), o.getString("cancelled_redemption_id"), o.getLong("amount"), o.getLong("balance_after"), o.getString("created_at"))
    }

    /** No answer, or a server error: the booking may or may not have happened. */
    private fun unknownOutcome(e: Exception) = e is IOException || (e is GiftCardProException && e.status >= 500)
}

/** A connected restaurant and the token for its tills (`gcpc_…`, shown once). */
data class TillAccess(val connection: Connection, val token: String)

const val DEFAULT_URL = "https://app.giftcardpro.at"

internal class Api(
    private val bearer: String,
    private val baseUrl: String,
    private val language: String,
    private val transport: HttpTransport,
    private val fixed: Map<String, String> = emptyMap(),
) {
    fun call(method: String, path: String, body: JSONObject?, extra: Map<String, String> = emptyMap()): JSONObject =
        send(method, path, body, extra).optJSONObject("data") ?: throw IOException("Unexpected answer")

    fun callList(method: String, path: String) = send(method, path, null, emptyMap()).optJSONArray("data") ?: throw IOException("Unexpected answer")

    private fun send(method: String, path: String, body: JSONObject?, extra: Map<String, String>): JSONObject {
        val headers = mutableMapOf(
            "Authorization" to "Bearer $bearer",
            "Accept" to "application/json",
            "Accept-Language" to language,
        )
        headers.putAll(fixed)
        if (body != null) headers["Content-Type"] = "application/json"
        headers.putAll(extra)
        val (status, text) = transport.send(method, baseUrl.trimEnd('/') + "/api/partner/v1/" + path, headers, body?.toString())
        val json = try { JSONObject(text) } catch (e: Exception) { JSONObject() }
        if (status >= 400) {
            throw GiftCardProException(status, json.optString("code", "HTTP_$status"), json.optString("message", "HTTP $status"), json.optJSONObject("context") ?: json.optJSONObject("errors"))
        }
        // A 2xx without a JSON body (proxy, captive portal): no reliable answer.
        if (!json.has("data")) throw IOException("Unexpected answer (HTTP $status)")
        return json
    }
}
