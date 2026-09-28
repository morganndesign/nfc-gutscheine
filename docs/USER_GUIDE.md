# User guide

One page per role. Print the waiter page and leave it at the till for the first week.

---

## Waiter: redeem a gift card

![Waiter terminal](screenshots/waiter-amount.png)

1. **Open GiftCard Pro** on the restaurant phone. The app opens straight into waiter mode.
2. **Read the card:**
   - **Android (Chrome):** press **Scan card** once. After that, simply tap each card to the back of the phone.
   - **iPhone:** hold the card to the top of the phone and tap the notification. Or press **Scan QR code** and point the camera at the code on the back.
   - **No chip, no camera:** press **Card number** and type the 16 digits.
3. **Type the amount** on the keypad (`2 4 9 0` → € 24,90) or press **Full balance**.
4. Press **Redeem € 24,90**. The green check mark shows the remaining balance for the guest.
5. **Tap the next card**, or press **Next card**.

| You see | What to do |
|---|---|
| **More than the balance** | Redeem the full balance and collect the rest in cash or by card. |
| **This card is blocked** / **was replaced** | Do not accept the card. Call the manager. |
| **This card has expired** | Do not accept the card. The manager can check the details. |
| **No card with this number** | Check the digits. The number is printed under the QR code. |
| **No connection to the server** | Check the Wi-Fi. Nothing was booked. Press the button again. The app never books twice. |

---

## Manager: everyday card management

| Task | Where |
|---|---|
| Sell a card in the waiter app | Managers and owners on Android: **New gift card** on the start screen → amount (optionally the guest's e-mail) → **Create card** → hold a blank NFC card to the back of the phone until the check mark appears. The card number and balance are shown; **Program later** keeps the card without a tag (program it in the dashboard). |
| Sell a card | **Gift cards → New gift card**. Pick an amount, optionally add the customer's e-mail (they get a confirmation), then **Create card**. Next, write the NFC tag (Android: **Write NFC tag** — the tag is checked, written, read back and verified before its chip is saved) or **Print**. |
| Program many tags | On an Android phone with Chrome: **Gift cards → Program NFC tags → Start programming**. Each card without a tag comes up in turn; hold one blank tag to the phone, label it with the number on screen. Tags of other cards are refused and nothing is written. Progress (`12 / 300 cards programmed`), successes, failed attempts, skipped cards, elapsed time and the average time per card are shown; **CSV** downloads the session log. After any error, **Try again** (same session) or **Skip card**. With several phones, give each its own start number. The card page lists every attempt under **Tag programming**. |
| Look up a card | **Gift cards**, then search by number, customer, recipient or note. |
| Redeem or reload at the desk | Open the card, then **Redeem** or **Reload**. |
| Lost or damaged card | Open the card → **⋯ → Replace lost card** → choose **Lost** / **Damaged** / **Stolen**. The balance moves to a new card and the old card stops working immediately. |
| Stolen card or suspicious use | **⋯ → Block card**. Unblock it later from the same menu. |
| Wrong amount booked | **Transactions** or the card's history → ↺ **Reverse**. The correction is booked as a new line; nothing is deleted. |

![Card detail](screenshots/card-detail.png)

---

## Owner: the numbers

![Dashboard](screenshots/owner-dashboard.png)

- **Outstanding balance**: money guests can still spend with you (your open liability). This is the number for your bookkeeping.
- **Revenue this month**: gift cards sold plus reloads, compared with last month.
- **Redeemed this month**: what guests paid with gift cards (and today's amount).
- **Cards sold**: all cards ever sold, and how many are in use.
- **Recent activity**: the latest bookings. **View all** opens the full ledger.
- **Exports**: **Gift cards → Export CSV** and **Transactions → Export CSV** open directly in Excel (Austrian number format).
- **Lost phone**: **Devices → Revoke**. That phone can no longer scan or redeem cards, effective immediately (owners only; managers can see the device list).
- **Team**: invite managers and waiters. Each person gets their own 72-hour invitation link. Never share logins, because every booking is signed with the person's name.
- **Settings → Gift cards**: minimum and maximum value, default validity, reloads, partial redemption, customer e-mails, brand color.

---

## Guests: check the balance

Scanning the card (NFC or QR) opens a page in the restaurant's language with the current balance and expiry date. The card itself never stores money.

![Public balance page](screenshots/public-balance.png)
