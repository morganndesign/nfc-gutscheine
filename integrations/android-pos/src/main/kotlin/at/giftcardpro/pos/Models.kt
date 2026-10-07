package at.giftcardpro.pos

import org.json.JSONObject

/** Amounts are always in cents (minor units): 1250 = € 12,50. */
data class Voucher(
    val id: String,
    val number: String,
    val status: String,
    val balance: Long,
    val currency: String,
    val expiresAt: String?,
    /** False when the voucher is blocked, expired or empty: show [status] instead of offering it. */
    val redeemable: Boolean,
)

data class Rules(val allowPartialRedemption: Boolean, val maxDebitPerTransaction: Long?)

/** A card tap or QR scan: valid [expiresAt] (60 seconds) for one redemption on this till. */
data class Presentment(
    val id: String,
    val expiresAt: String,
    /** "card" or "qr". */
    val method: String,
    val voucher: Voucher,
    val cardNumber: String?,
    val rules: Rules,
) {
    /** The most this voucher pays towards [billCents] under the restaurant's rules (0: nothing). */
    fun payable(billCents: Long): Long {
        if (!voucher.redeemable) return 0
        val cap = rules.maxDebitPerTransaction ?: Long.MAX_VALUE
        return if (rules.allowPartialRedemption) minOf(voucher.balance, billCents, cap)
        else if (voucher.balance <= billCents && voucher.balance <= cap) voucher.balance else 0
    }
}

data class Redemption(
    val id: String,
    val amount: Long,
    val currency: String,
    val balanceAfter: Long,
    val voucherId: String,
    val voucherNumber: String,
    val reference: String?,
    val createdAt: String,
    /** True when this answer repeats a redemption already booked with the same Idempotency-Key. */
    val replayed: Boolean,
)

data class Cancellation(val id: String, val cancelledRedemptionId: String, val amount: Long, val balanceAfter: Long, val createdAt: String)

data class Connection(val id: String, val restaurantName: String, val currency: String, val locale: String, val rules: Rules)

internal object Json {
    fun rules(o: JSONObject) = Rules(
        o.getBoolean("allow_partial_redemption"),
        if (o.isNull("max_debit_per_transaction")) null else o.getLong("max_debit_per_transaction"),
    )

    fun presentment(o: JSONObject): Presentment {
        val v = o.getJSONObject("voucher")
        return Presentment(
            id = o.getString("presentment_id"),
            expiresAt = o.getString("expires_at"),
            method = o.getString("method"),
            voucher = Voucher(
                id = v.getString("id"),
                number = v.getString("number"),
                status = v.getString("status"),
                balance = v.getLong("balance"),
                currency = v.getString("currency"),
                expiresAt = if (v.isNull("expires_at")) null else v.getString("expires_at"),
                redeemable = v.getBoolean("redeemable"),
            ),
            cardNumber = if (o.isNull("card")) null else o.getJSONObject("card").getString("number"),
            rules = rules(o.getJSONObject("rules")),
        )
    }

    fun redemption(o: JSONObject) = Redemption(
        id = o.getString("id"),
        amount = o.getLong("amount"),
        currency = o.getString("currency"),
        balanceAfter = o.getLong("balance_after"),
        voucherId = o.getString("voucher_id"),
        voucherNumber = o.getString("voucher_number"),
        reference = if (o.isNull("reference")) null else o.getString("reference"),
        createdAt = o.getString("created_at"),
        replayed = o.optBoolean("replayed", false),
    )

    fun connection(o: JSONObject): Connection {
        val r = o.getJSONObject("restaurant")
        return Connection(o.getString("id"), r.getString("name"), r.getString("currency"), r.getString("locale"), rules(o.getJSONObject("rules")))
    }
}
