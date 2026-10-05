# User guide

One page per role. Print the waiter page and leave it at the till for the first week.

A guest pays with a **voucher**: a printed sheet (or a photo or PDF of it on their phone) with a QR code. The QR
code is the voucher: whoever holds it can spend it, like cash. The sheet shows the restaurant, not the voucher
number and not the value.

**Signing in to the dashboard:** e-mail and password, then a **6-digit code** sent to your e-mail address (valid
for 10 minutes; **Send a new code** if it does not arrive). After the code, that browser does not ask for a code
for 15 days. A new password signs you out everywhere and every browser asks for a code again. The waiter app is
not affected.

---

## Waiter: redeem a voucher

In the **GiftCard Waiter** app (Android or iPhone), or in a browser under **Redeem** (`/waiter`) on a device with a
camera:

1. Press **Scan voucher** and point the camera at the QR code — printed or on the guest's phone.
2. The app shows the balance. **Type the amount** on the keypad (`2 4 9 0` → € 24,90) or use the full balance.
3. Press **Redeem**. The green check mark shows the remaining balance for the guest.
4. Press **Scan next voucher**.

A scan is valid for 60 seconds. If it takes longer, the app asks you to **Scan again**; the amount you typed is kept.

| You see | What to do |
|---|---|
| **More than the balance** | Redeem the balance and collect the rest in cash or by card. |
| **Not a voucher of this restaurant** | The code is not valid here. Ask the guest for another voucher or get a manager. |
| **Voucher blocked** / **Voucher expired** | Do not accept the voucher. Get a manager. |
| **Limit for this voucher reached** / **At most … more with this voucher today** | The restaurant's limits apply. Get a manager. |
| **Too many scans** | Wait a moment, then scan again. |
| **Connection interrupted – checking …** | Keep the guest waiting a moment. The app checks whether the redemption was booked. Nothing is ever booked twice. |
| **Redemption not confirmed yet** | The app checks it automatically. The same voucher can be redeemed again only after the check. |
| **Service not available right now** | The problem is not the voucher. Try again in a moment. |

**Recent** (top bar) lists this phone's redemptions of the day. A wrong amount is reversed by a manager in the
dashboard.

---

## Manager: everyday voucher work

| Task | Where |
|---|---|
| Sell a voucher at the desk | **Vouchers → Sell voucher**. Value, how the guest paid (**Cash**, **Card terminal** with the receipt number, **Bank transfer** with the reference), optionally the customer, the recipient ("for Anna"), a personal message from the buyer (up to 300 characters, printed on the voucher and its PDF) and internal notes → **Sell voucher** → **Print voucher**. Print it (or save it as PDF) right away: the QR code is shown only once. |
| Sell a voucher in the app | Managers and owners: **Sell voucher** on the ready screen → value → payment → optional guest e-mail → print with the phone's print dialog (AirPrint or the Android print service). |
| Find a voucher | **Vouchers**, then search by voucher number, customer, recipient or note, or filter by status. |
| Reload a voucher | Open the voucher → **Reload** → amount and payment. |
| Lost printout, stolen or suspicious voucher | Open the voucher → **⋯ → Block voucher** with a reason. From then on it cannot be redeemed. **Unblock** is in the same menu. |
| Wrong amount booked | **Transactions** or the voucher's history → **Reverse**. The correction is a new line; nothing is changed or deleted. |
| Edit customer, recipient, message, notes | Open the voucher → **⋯ → Edit details**. |

---

## Owner: the numbers and the rules

- **Outstanding balance**: money guests can still spend with you (your open liability), and on how many vouchers.
- **Revenue this month**: vouchers sold plus reloads, compared with last month.
- **Redeemed this month**: what guests paid with vouchers (and today's amount).
- **Vouchers**: sold in total and this month; active, empty, blocked and expired.
- **Recent activity**: the latest bookings. **Transactions** is the full ledger.
- **Exports**: **Vouchers → Export CSV** and **Transactions → Export CSV** open directly in Excel (Austrian number
  format); the transaction export includes the payment method.
- **Loyalty** (dashboard and app): value for regulars without payment, always with a reason (e.g. "regular guest, October"). A voucher becomes a loyalty voucher only when it is **sold** as Loyalty (a new voucher or a new card); only a loyalty voucher can be topped up with Loyalty again (and with paid money as well). A paid voucher or card never becomes a loyalty one — the server refuses it. Owners always give loyalty; in **Team → Loyalty vergeben** the owner chooses which managers may too (effective at once, recorded in the audit log). Waiters never. Loyalty vouchers carry a **Loyalty** badge and can be filtered in **Vouchers**; loyalty value is not revenue, is listed separately in the cash-up and is never paid out.
- **Expiry**: vouchers have no expiry unless you set a validity (at least 36 months) under **Settings → Vouchers**.
  An expired voucher keeps its balance. **⋯ → Expire now** (with a reason) and **⋯ → Reinstate** (with a new last
  valid day or none) are for owners.
- **Lost phone**: **Devices → Revoke**. That phone is signed out and can no longer redeem, effective immediately.
- **Team**: invite managers and waiters. Each person gets their own 72-hour invitation link. Never share logins:
  every booking carries the person's name and the device.
- **Settings → Vouchers**: minimum value, maximum balance, maximum per redemption, maximum per voucher and day,
  redemptions per voucher and hour, validity, reloads, partial redemption, customer e-mails, brand color, e-mail
  footer.

---

## Guests

Guests keep the printed sheet (or a photo of it) and show it when they pay. If they gave an e-mail address at the
sale of a printed voucher, the receipt (value, restaurant, date, how it was paid) carries the voucher itself as a PDF
attachment with its QR code — treat that e-mail like cash. A gift card sale only gets the receipt: the card is the
voucher. Before a validity ends, guests get a reminder. The e-mail text never contains the QR code, the voucher
number, a link or the current balance. If a QR code may have been copied, issue a new one: the old one stops working.
To learn the balance, guests ask the restaurant.
