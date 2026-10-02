# Pilot checklist

Use this list for the first restaurant. Tick each item. The journey in section B is automated in
[`e2e/pilot-journey.mjs`](../e2e/README.md).

## A. One week before

- [ ] **Server:** production stack running ([DEPLOYMENT.md](DEPLOYMENT.md)) and `https://<domain>/up` returns `200`.
- [ ] **E-mail:** real SMTP configured (`MAIL_MAILER=smtp` — Coolify pre-fills `log`). **System settings → Send test
      e-mail** succeeds (to a mailbox you can check) and the mail does not land in spam.
- [ ] **Scheduler:** `SCHEDULE_TIMEZONE=Europe/Vienna`; `php artisan schedule:list` in the api container shows
      `vouchers:expire` 00:15 and `giftcard:verify-chains` 04:00.
- [ ] **Integrity:** `php artisan giftcard:verify-chains` reports "All hash chains and voucher balances are intact",
      and `OPS_ALERT_EMAIL` (or the platform support e-mail) reaches someone who reads it.
- [ ] **Backups:** nightly dump, keystore copy and the encrypted off-site copy configured (`OFFSITE_*`);
      `php artisan ops:check-backups` (scheduler container) reports "current and off-site"; **one restore tested**
      (followed by `giftcard:verify-chains`).
- [ ] **Card keys** (for physical cards): `CRYPTO_KEYSTORE_KEY` set and kept offline, `TAP_URL` final, key ceremony
      done (`cards:key-set:create`, key check values on paper), `cards:key-set:verify` passes, the real-card
      validation ([NFC.md](NFC.md#validation-procedure-with-real-cards)) signed off.
- [ ] **Security alerts:** *Security alerts* in the platform dashboard is empty or acknowledged; a test alert reached
      `OPS_ALERT_EMAIL`.
- [ ] **Monitoring:** uptime check on `/up`, and alerts on `warning` and `critical` log lines (locked accounts,
      failed integrity check).
- [ ] **Platform admin created:** `php artisan platform:create-admin`.
- [ ] **Apps:** GiftCard Waiter available to the restaurant's phones (TestFlight / Play internal testing), minimum
      app versions set under System settings if needed.
- [ ] **Hardware:** every restaurant phone has a working camera; a printer reachable from the phones (AirPrint or
      the Android print service) and from the desk computer.

## B. Onboarding day (with the owner)

1. [ ] **Onboard the restaurant** under Restaurants → Onboard restaurant. The owner gets the invitation (the list
   shows "Invitation pending"; if it says "not delivered", fix the mail settings and use **⋯ → Invite again**).
2. [ ] The owner **accepts the invitation** and follows the **Welcome** panel on the dashboard:
   - [ ] **Voucher rules** (Settings → Vouchers): minimum value, maximum balance and per-redemption limits, validity
     (none, or at least 36 months — check the Austrian rules with their advisor), reloads, partial redemption.
   - [ ] **Restaurant profile**: legal name, VAT number (UID), address, language `Deutsch (Österreich)`, time zone.
   - [ ] **Brand color** and **e-mail footer** (company register, address).
   - [ ] **Team**: invite managers and waiters, each with their own e-mail.
3. [ ] **Test voucher:** sell € 5 at the desk (Vouchers → Sell voucher, payment *Cash*) and print it. Check that the
   sheet shows the QR code, the restaurant and the value, but no voucher number.
4. [ ] **On every restaurant phone:** sign in to GiftCard Waiter as a waiter, scan the test voucher, redeem € 1,
   then **Scan next voucher**. Rename the phone under Devices (for example "Bar iPhone").
5. [ ] **Manager on a phone:** sell a voucher in the app (**Sell voucher**) and print it from the phone.
6. [ ] **Reverse** the test redemption, then **Block** the test voucher, then scan it again: the app shows it
   blocked. The audit log shows each action once.
7. [ ] **Cards** (if the restaurant sells physical cards): confirm the delivery in the app (Menu → *Confirm a
   delivery*), sell a € 5 gift card (*Sell voucher* → *Gift card*), pay € 1 with *Tap card* on every phone, suspend
   and resume it under *Cards* in the dashboard.
8. [ ] Print the waiter page of the [user guide](USER_GUIDE.md) and place it at the till.

## C. First week

- [ ] Daily: look at the dashboard together with the owner (outstanding balance, recent activity).
- [ ] Check the audit log for failed and rejected presentments (`presentment.failed`, `presentment.rejected`) and
      locked accounts.
- [ ] End of the week: **Transactions → Export CSV** and hand it to the bookkeeper. Ask whether the format works
      for them (payment methods are included).
- [ ] Collect feedback from the waiters.
