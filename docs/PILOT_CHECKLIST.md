# Pilot go-live checklist

Use this list for the first restaurant. Tick each item. Everything here was run end to end with
[`e2e/pilot-journey.mjs`](../e2e/README.md) before the release.

## A. One week before

- [ ] **Server:** production stack running ([DEPLOYMENT.md](DEPLOYMENT.md)) and `https://APP_DOMAIN/up` returns `200`.
- [ ] **`CARD_BASE_URL`** is the final domain. Cards written with another domain stop working.
- [ ] **E-mail:** real SMTP configured. Send yourself an invitation and check that it does not land in spam.
- [ ] **`SCHEDULE_TIMEZONE=Europe/Vienna`** is set. The `scheduler` container shows `schedule:list` with expiry at 00:15.
- [ ] **Backups:** nightly dump and off-site sync configured, and **one restore tested**.
- [ ] **Monitoring:** uptime check on `/up`, and alerts on `warning` log lines (suspicious scans, locked accounts).
- [ ] **Platform admin created:** `php artisan platform:create-admin`.
- [ ] **Hardware:** order the NFC cards (NTAG215 recommended, or NTAG 424 DNA for clone protection) and one test card per phone model.

## B. Onboarding day (with the owner)

1. [ ] **Onboard the restaurant** under Restaurants → Onboard restaurant. The owner gets the invitation.
2. [ ] The owner **accepts the invitation** and follows the **Welcome** panel on the dashboard:
   - [ ] **Card rules**: values, validity (check the Austrian rules with their advisor), reloads, partial redemption.
   - [ ] **Restaurant profile**: legal name, VAT number (UID), address, language `Deutsch (Österreich)`, time zone.
   - [ ] **Brand color** and **e-mail footer** (company register, address).
   - [ ] **Team**: invite managers and waiters, each with their own e-mail.
3. [ ] **Test card:** sell € 5, write the tag with an Android phone, and check the public page on an iPhone and an Android phone.
4. [ ] **On every restaurant phone:** sign in as a waiter, tap the test card, redeem € 1, then press **Next card**.
   Rename the phone under Devices (for example "Bar iPhone").
5. [ ] **Reverse** the test redemption, then **Block** the test card, then **Replace** it. The team sees all three actions once.
6. [ ] Print the waiter page of the [user guide](USER_GUIDE.md) and place it at the till.

## C. First week

- [ ] Daily: look at the dashboard together with the owner (outstanding balance, recent activity).
- [ ] Check the audit log for red **security alerts** (cloned, copied or foreign cards).
- [ ] End of the week: **Transactions → Export CSV** and hand it to the bookkeeper. Ask whether the format works for them.
- [ ] Collect feedback from the waiters. Anything that took more than one tap is a candidate for the next release.
