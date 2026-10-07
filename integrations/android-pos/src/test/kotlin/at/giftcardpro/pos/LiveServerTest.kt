package at.giftcardpro.pos

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Assume.assumeTrue
import org.junit.Test

/**
 * Against a running GiftCard Pro backend (skipped otherwise): GCP_URL, GCP_KEY, GCP_CODE (a restaurant's one-time
 * code), GCP_QR (the QR text of a voucher of that restaurant with at least € 10 on it).
 */
class LiveServerTest {
    @Test
    fun `connect, scan a printed voucher, redeem, look up and cancel against a real server`() {
        val url = System.getenv("GCP_URL")
        assumeTrue(url != null)
        val partner = GiftCardProPartner(System.getenv("GCP_KEY"), baseUrl = url!!)
        val access = partner.connect(System.getenv("GCP_CODE"))
        assertTrue(partner.connections().any { it.id == access.connection.id })
        val gcp = GiftCardProClient(access.token, "KASSE-E2E", "E2E-Kasse", baseUrl = url)
        assertEquals(access.connection.id, gcp.connection().id)

        val presented = gcp.scanQr(System.getenv("GCP_QR"))
        val before = presented.voucher.balance
        assertTrue(presented.payable(1000) == 1000L)
        val key = java.util.UUID.randomUUID().toString()
        val redemption = gcp.redeem(presented.id, 1000, reference = "Bon E2E", staff = "Test", idempotencyKey = key)
        assertEquals(before - 1000, redemption.balanceAfter)
        assertNotNull(gcp.redemptionOutcome(key))
        // The same key again: the same booking.
        assertEquals(redemption.id, gcp.redeem(presented.id, 1000, idempotencyKey = key).id)

        val cancelled = gcp.cancelRedemption(redemption.id, "Bon storniert")
        assertEquals(before, cancelled.balanceAfter)
        try {
            gcp.scanQr("GCPV1.nope")
        } catch (e: GiftCardProException) {
            assertEquals("MEDIUM_NOT_RECOGNIZED", e.code)
        }

        // A new token: the old one stops at once.
        val renewed = partner.newToken(access.connection.id)
        assertEquals(access.connection.id, GiftCardProClient(renewed.token, "KASSE-E2E", baseUrl = url).connection().id)
        try {
            gcp.connection()
            fail()
        } catch (e: GiftCardProException) {
            assertEquals(401, e.status)
        }
    }
}
