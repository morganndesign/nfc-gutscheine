# GiftCard Pro — implementation audit (read-only)

Audit date 2026-09-27. No code was modified. Sources: code in /home/claude/giftcard-pro, specification in docs/ (docs/design/waiter-app for the native app, docs/de for the product).

# Part 0 — What exists

## APK / AAB (cloud workspace, not in your Gutscheine folder)
```
-rw-r--r-- 1 root root 58390165 Sep 26 20:43 waiter-app/build/app/outputs/bundle/release/app-release.aab
-rw-r--r-- 1 root root 23571416 Sep 26 20:45 waiter-app/build/app/outputs/flutter-apk/app-release.apk
bd0a0fc1c83b64f41448dead880d6156c45c6a151d3d7672598cdea59cfa4c0e  waiter-app/build/app/outputs/flutter-apk/app-release.apk
```
Built with --dart-define=API_BASE_URL=https://app.example.at/api/v1 --dart-define=CARD_DOMAINS=app.example.at (placeholder domain), signed with the debug key (no android/key.properties). Not installable against your server as-is.

## API endpoints (php artisan route:list --path=api)
```
GET       /api/v1/admin/audit-logs                            Admin\PlatformController@auditLogs
GET       /api/v1/admin/restaurants                           Admin\RestaurantController@index
POST      /api/v1/admin/restaurants                           Admin\RestaurantController@store
GET       /api/v1/admin/restaurants/{restaurant}              Admin\RestaurantController@show
PATCH     /api/v1/admin/restaurants/{restaurant}              Admin\RestaurantController@update
POST      /api/v1/admin/restaurants/{restaurant}/reactivate   Admin\RestaurantController@reactivate
POST      /api/v1/admin/restaurants/{restaurant}/suspend      Admin\RestaurantController@suspend
GET       /api/v1/admin/stats                                 Admin\PlatformController@stats
GET       /api/v1/admin/system-settings                       Admin\PlatformController@settings
PUT       /api/v1/admin/system-settings                       Admin\PlatformController@updateSettings
GET       /api/v1/api-tokens                                  ApiTokenController@index
POST      /api/v1/api-tokens                                  ApiTokenController@store
POST      /api/v1/api-tokens/{token}/revoke                   ApiTokenController@revoke
GET       /api/v1/app/config                                  AppConfigController
GET       /api/v1/audit-logs                                  AuditLogController@index
POST      /api/v1/auth/forgot-password                        PasswordController@forgot
POST      /api/v1/auth/login                                  AuthController@login
POST      /api/v1/auth/logout                                 AuthController@logout
GET       /api/v1/auth/me                                     AuthController@me
PUT       /api/v1/auth/password                               PasswordController@change
PUT       /api/v1/auth/profile                                PasswordController@updateProfile
POST      /api/v1/auth/reset-password                         PasswordController@reset
POST      /api/v1/auth/token                                  AuthController@token
GET       /api/v1/cards                                       GiftCardController@index
POST      /api/v1/cards                                       GiftCardController@store
GET       /api/v1/cards/export                                GiftCardController@export
GET       /api/v1/cards/{card}                                GiftCardController@show
PATCH     /api/v1/cards/{card}                                GiftCardController@update
POST      /api/v1/cards/{card}/activate                       GiftCardActionController@activate
POST      /api/v1/cards/{card}/block                          GiftCardActionController@block
POST      /api/v1/cards/{card}/expire                         GiftCardActionController@expire
GET       /api/v1/cards/{card}/history                        GiftCardActionController@history
GET       /api/v1/cards/{card}/nfc                            GiftCardActionController@nfcPayload
POST      /api/v1/cards/{card}/nfc                            GiftCardActionController@bindNfc
GET       /api/v1/cards/{card}/qr                             GiftCardActionController@qr
POST      /api/v1/cards/{card}/redeem                         GiftCardActionController@redeem
POST      /api/v1/cards/{card}/reload                         GiftCardActionController@reload
POST      /api/v1/cards/{card}/replace                        GiftCardActionController@replace
POST      /api/v1/cards/{card}/transfer                       GiftCardActionController@transfer
POST      /api/v1/cards/{card}/unblock                        GiftCardActionController@unblock
GET       /api/v1/customers                                   CustomerController@index
POST      /api/v1/customers                                   CustomerController@store
GET       /api/v1/customers/{customer}                        CustomerController@show
PATCH     /api/v1/customers/{customer}                        CustomerController@update
POST      /api/v1/customers/{customer}/anonymize              CustomerController@anonymize
GET       /api/v1/dashboard/activity                          DashboardController@activity
GET       /api/v1/dashboard/charts                            DashboardController@charts
GET       /api/v1/dashboard/stats                             DashboardController@stats
GET       /api/v1/devices                                     DeviceController@index
GET       /api/v1/devices/current                             DeviceController@current
PATCH     /api/v1/devices/{device}                            DeviceController@update
POST      /api/v1/devices/{device}/restore                    DeviceController@restore
POST      /api/v1/devices/{device}/revoke                     DeviceController@revoke
GET       /api/v1/public/cards/{token}                        PublicCardController@show
GET       /api/v1/roles                                       RoleController@index
POST      /api/v1/scan                                        CardScanController
GET       /api/v1/settings                                    SettingsController@show
PUT       /api/v1/settings/cards                              SettingsController@updateCardSettings
GET       /api/v1/settings/notification-templates             NotificationTemplateController@index
PUT       /api/v1/settings/notification-templates/{key}       NotificationTemplateController@update
PUT       /api/v1/settings/restaurant                         SettingsController@updateRestaurant
GET       /api/v1/transactions                                TransactionController@index
GET       /api/v1/transactions/export                         TransactionController@export
GET       /api/v1/transactions/{transaction}                  TransactionController@show
POST      /api/v1/transactions/{transaction}/reverse          TransactionController@reverse
GET       /api/v1/users                                       UserController@index
POST      /api/v1/users                                       UserController@store
GET       /api/v1/users/{user}                                UserController@show
PATCH     /api/v1/users/{user}                                UserController@update
POST      /api/v1/users/{user}/activate                       UserController@activate
POST      /api/v1/users/{user}/deactivate                     UserController@deactivate
POST      /api/v1/users/{user}/password-reset                 UserController@sendPasswordReset
72 routes
```
Permission / throttle / idempotency middleware per route: backend/routes/api.php

## Database migrations
```
backend/database/migrations/2026_01_01_000001_create_platform_tables.php
    create('restaurants'
    create('restaurant_settings'
    create('system_settings'
backend/database/migrations/2026_01_01_000002_create_access_control_tables.php
    create('roles'
    create('permissions'
    create('permission_role'
    create('users'
    create('password_reset_tokens'
    create('sessions'
    create('personal_access_tokens'
backend/database/migrations/2026_01_01_000003_create_devices_and_customers_tables.php
    create('devices'
    create('customers'
backend/database/migrations/2026_01_01_000004_create_gift_card_tables.php
    create('gift_cards'
    create('gift_card_transactions'
    create('nfc_scans'
backend/database/migrations/2026_01_01_000005_create_audit_and_notification_tables.php
    create('audit_logs'
    create('notification_templates'
    create('notification_logs'
backend/database/migrations/2026_01_01_000006_create_framework_tables.php
    create('cache'
    create('cache_locks'
    create('job_batches'
    create('failed_jobs'
backend/database/migrations/2026_09_27_000001_bind_access_tokens_to_devices.php
    table('personal_access_tokens'
    table('personal_access_tokens'
backend/database/migrations/2026_09_27_000002_add_waiter_app_system_settings.php
```

## Web frontend pages / route handlers
```
frontend/src/app/(app)/account/page.tsx
frontend/src/app/(app)/admin/audit/page.tsx
frontend/src/app/(app)/admin/page.tsx
frontend/src/app/(app)/admin/restaurants/[id]/page.tsx
frontend/src/app/(app)/admin/settings/page.tsx
frontend/src/app/(app)/audit/page.tsx
frontend/src/app/(app)/cards/[id]/page.tsx
frontend/src/app/(app)/cards/new/page.tsx
frontend/src/app/(app)/cards/page.tsx
frontend/src/app/(app)/customers/[id]/page.tsx
frontend/src/app/(app)/customers/page.tsx
frontend/src/app/(app)/dashboard/page.tsx
frontend/src/app/(app)/devices/page.tsx
frontend/src/app/(app)/settings/page.tsx
frontend/src/app/(app)/team/page.tsx
frontend/src/app/(app)/transactions/page.tsx
frontend/src/app/(auth)/forgot-password/page.tsx
frontend/src/app/(auth)/login/page.tsx
frontend/src/app/(auth)/reset-password/page.tsx
frontend/src/app/.well-known/apple-app-site-association/route.ts
frontend/src/app/.well-known/assetlinks.json/route.ts
frontend/src/app/c/[token]/page.tsx
frontend/src/app/page.tsx
frontend/src/app/print/cards/[id]/page.tsx
frontend/src/app/waiter/page.tsx
```

## Flutter source (waiter-app/lib, lines)
```
   140 lib/app/app_navigator.dart
    75 lib/app/app_scope.dart
   126 lib/app/bootstrap.dart
    25 lib/app/money.dart
    79 lib/app/page_transitions.dart
    55 lib/app/session_sheet_host.dart
   132 lib/app/waiter_app.dart
   797 lib/components/amount_display.dart
   122 lib/components/avatar.dart
   704 lib/components/balance_card.dart
   210 lib/components/banner.dart
   539 lib/components/bottom_sheet.dart
    66 lib/components/button_label.dart
   580 lib/components/buttons.dart
   289 lib/components/card_number_field.dart
    38 lib/components/components.dart
   103 lib/components/countdown_hairline.dart
   229 lib/components/dialog.dart
    89 lib/components/empty_state.dart
    92 lib/components/history_card.dart
   453 lib/components/hold_button.dart
   114 lib/components/icon_button.dart
   476 lib/components/keypad.dart
    70 lib/components/money_context.dart
   389 lib/components/nfc_scan_animation.dart
   565 lib/components/problem_screen.dart
   269 lib/components/progress_ring.dart
   159 lib/components/quick_amount_chip.dart
   281 lib/components/skeleton.dart
   432 lib/components/snackbar.dart
   120 lib/components/spinner.dart
   139 lib/components/status_badge.dart
   270 lib/components/status_banner.dart
   212 lib/components/success_mark.dart
    18 lib/components/support/announce.dart
    91 lib/components/support/delayed_presence.dart
   163 lib/components/support/field_parts.dart
    98 lib/components/support/focus_ring.dart
    18 lib/components/support/hairline.dart
   368 lib/components/support/pressable.dart
   146 lib/components/support/shake.dart
   113 lib/components/support/shape.dart
    18 lib/components/support/text_emphasis.dart
   237 lib/components/text_field.dart
   222 lib/components/top_bar.dart
   186 lib/components/transaction_row.dart
   182 lib/core/api/api_client.dart
    89 lib/core/api/api_failure.dart
    44 lib/core/api/card_link.dart
   344 lib/core/api/models.dart
   146 lib/core/api/waiter_api.dart
    60 lib/core/config/environment.dart
    34 lib/core/diagnostics/diagnostic_log.dart
   145 lib/core/format/amount_entry.dart
    67 lib/core/format/business_day.dart
   158 lib/core/format/card_number.dart
   248 lib/core/format/date_time.dart
    14 lib/core/format/format.dart
   190 lib/core/format/money.dart
    42 lib/core/format/restaurant_locale.dart
   124 lib/core/format/spoken.dart
    28 lib/core/format/support_code.dart
    36 lib/core/l10n/l10n.dart
    46 lib/core/l10n/locale_resolution.dart
   934 lib/core/l10n/pseudo_app_localizations.g.dart
    31 lib/core/l10n/pseudo_localization.dart
    61 lib/core/l10n/pseudo_transform.dart
    39 lib/core/l10n/ui_language.dart
    83 lib/core/platform/biometrics_service.dart
     9 lib/core/platform/channels.dart
    45 lib/core/platform/connectivity_service.dart
    25 lib/core/platform/feedback_scope.dart
   124 lib/core/platform/feedback_service.dart
   179 lib/core/platform/nfc_service.dart
    49 lib/core/platform/system_service.dart
    44 lib/core/state/business_calendar.dart
    18 lib/core/state/client_identity.dart
    21 lib/core/state/clock.dart
  1011 lib/core/state/loop_controller.dart
   338 lib/core/state/loop_state.dart
    28 lib/core/state/redeem_attempts.dart
   672 lib/core/state/session_controller.dart
    80 lib/core/state/session_state.dart
   140 lib/core/storage/recent_store.dart
    53 lib/core/storage/secure_store.dart
    87 lib/core/storage/settings_store.dart
   353 lib/core/theme/brand_color.dart
    34 lib/core/theme/context_ext.dart
   199 lib/core/theme/illustrations.dart
   172 lib/core/theme/layout.dart
   223 lib/core/theme/scaled_text.dart
    71 lib/core/theme/svg_stroke_loader.dart
   269 lib/core/theme/text_styles.dart
    15 lib/core/theme/theme.dart
   123 lib/core/theme/theme_data.dart
    82 lib/core/theme/theme_scope.dart
   262 lib/core/theme/waiter_icons.dart
   124 lib/core/theme/waiter_theme.dart
   319 lib/core/tokens/token_types.dart
     8 lib/core/tokens/tokens.dart
  2262 lib/core/tokens/tokens.g.dart
  1765 lib/l10n/app_localizations.dart
     9 lib/main.dart
   143 lib/screens/access/access_layout.dart
    52 lib/screens/access/biometric_copy.dart
    85 lib/screens/access/countdown.dart
    31 lib/screens/access/forgot_password.dart
   124 lib/screens/access/sign_in_banner.dart
    47 lib/screens/charge/card_data.dart
   128 lib/screens/charge/card_region.dart
    71 lib/screens/charge/card_state_banner.dart
   148 lib/screens/charge/charge_metrics.dart
    93 lib/screens/charge/entrance.dart
   113 lib/screens/charge/helper_line.dart
    75 lib/screens/charge/money_text.dart
    58 lib/screens/charge/support_code_line.dart
   129 lib/screens/charge/uncertain_panel.dart
    17 lib/screens/ios_sheet_texts.dart
   113 lib/screens/s01_splash.dart
   323 lib/screens/s02_sign_in.dart
   123 lib/screens/s03_biometrics.dart
   190 lib/screens/s04_unlock.dart
  1178 lib/screens/s05_ready.dart
  1330 lib/screens/s07_charge.dart
   626 lib/screens/s09_success.dart
   273 lib/screens/s10_problem.dart
   459 lib/screens/s11_manual_entry.dart
   556 lib/screens/s12_qr_scan.dart
   350 lib/screens/s13_recent.dart
   299 lib/screens/s14_menu.dart
   414 lib/screens/s15_session.dart
   490 lib/screens/s17_intro.dart
    92 lib/screens/scan/card_slot.dart
    24 lib/screens/scan/focus_helpers.dart
   198 lib/screens/scan/qr_camera.dart
   297 lib/screens/scan/sheet_rows.dart
    87 lib/screens/scan/viewfinder.dart
 31211 total
```

## Native platform code
```
    7 android/app/src/debug/AndroidManifest.xml
   16 android/app/src/debug/res/xml/network_security_config.xml
   89 android/app/src/main/AndroidManifest.xml
   72 android/app/src/main/kotlin/eu/tapredeem/waiter/MainActivity.kt
  270 android/app/src/main/kotlin/eu/tapredeem/waiter/WaiterFeedback.kt
  362 android/app/src/main/kotlin/eu/tapredeem/waiter/WaiterNfc.kt
  185 android/app/src/main/kotlin/eu/tapredeem/waiter/WaiterSystem.kt
   10 android/app/src/main/res/xml/network_security_config.xml
    7 android/app/src/profile/AndroidManifest.xml
 1018 total
   19 ios/Runner/AppDelegate.swift
   91 ios/Runner/Info.plist
   22 ios/Runner/Runner.entitlements
    6 ios/Runner/SceneDelegate.swift
  182 ios/Runner/WaiterFeedback.swift
  324 ios/Runner/WaiterNfc.swift
   23 ios/Runner/WaiterPlatformPlugin.swift
  162 ios/Runner/WaiterSystem.swift
  829 total
```

## Test files
```
## Flutter test files
test/app/redeem_journey_test.dart
test/components/amount_display_test.dart
test/components/balance_card_test.dart
test/components/buttons_test.dart
test/components/display_test.dart
test/components/fields_test.dart
test/components/follow_up_test.dart
test/components/hold_button_test.dart
test/components/keypad_test.dart
test/components/overlays_test.dart
test/components/templates_test.dart
test/core/format/amount_entry_test.dart
test/core/format/business_day_test.dart
test/core/format/card_number_test.dart
test/core/format/date_time_test.dart
test/core/format/money_test.dart
test/core/format/spoken_test.dart
test/core/format/support_code_test.dart
test/core/l10n/app_localizations_test.dart
test/core/l10n/arb_integrity_test.dart
test/core/l10n/import_strings_test.dart
test/core/l10n/locale_resolution_test.dart
test/core/l10n/pseudo_localization_test.dart
test/core/state/loop_controller_test.dart
test/core/theme/assets_test.dart
test/core/theme/brand_color_test.dart
test/core/theme/contrast_test.dart
test/core/theme/scaled_text_test.dart
test/core/theme/theme_test.dart
test/core/theme/typography_test.dart
test/core/tokens/tokens_test.dart
test/screens/access/s01_splash_test.dart
test/screens/access/s02_sign_in_test.dart
test/screens/access/s03_biometrics_test.dart
test/screens/access/s04_unlock_test.dart
test/screens/access/s15_session_test.dart
test/screens/access/s17_intro_test.dart
test/screens/charge/charge_screen_test.dart
test/screens/charge/problem_page_test.dart
test/screens/charge/redeeming_test.dart
test/screens/charge/success_screen_test.dart
test/screens/scan/s05_ready_test.dart
test/screens/scan/s11_manual_entry_test.dart
test/screens/scan/s12_qr_scan_test.dart
test/screens/scan/s13_recent_test.dart
test/screens/scan/s14_menu_test.dart

## Backend test files
../backend/tests/Feature:
AuthenticationTest.php
CardScanTest.php
GiftCardLifecycleTest.php
HardeningTest.php
IdempotencyAndConcurrencyTest.php
NotificationTest.php
PermissionsTest.php
PilotReadinessTest.php
PlatformAdminTest.php
QueueBacklogAlertTest.php
ReportingTest.php
SettingsAndApiTokensTest.php
StaffManagementTest.php
TenantIsolationTest.php
WaiterAppConfigTest.php
WaiterAppTokenTest.php

../backend/tests/Unit:
AesCmacTest.php
CardNumberTest.php
CardUrlBuilderTest.php
CsvSanitizerTest.php
Ntag424SunVerifierTest.php

## E2E
../e2e/pilot-journey.mjs
../e2e/waiter-api.mjs
```

## Screenshots
Web app (docs/screenshots, from release 1.2.0): card-detail.png dark-dashboard.png gift-cards.png mobile-dashboard.png new-card.png owner-dashboard.png platform-admin.png print-card.png public-balance.png transactions.png waiter-amount.png waiter-ready.png waiter-success.png 

Native waiter app: none exist.

# Part 1 — Native waiter app vs. docs/design/waiter-app

Legend: WA = waiter-app/, BE = backend/, T = waiter-app/test/, LC = WA/lib/core/state/loop_controller.dart, SC = WA/lib/core/state/session_controller.dart.
Verified facts: iOS Swift code never compiled (no Xcode, no ios/build); no test ran on a device; no integration_test/ directory; no Flutter screenshots; Android release APK/AAB built.

## A. Screens and variants (03a, 03b)

| ID | Requirement | Status | Source | API | Test |
|---|---|---|---|---|---|
| A1 | S01 normal ≤600 ms, mark → route | ✅ | WA/lib/screens/s01_splash.dart; SC:160 | GET /app/config | T/screens/access/s01_splash_test.dart "a fast start never shows the spinner" |
| A2 | S01 slow >1 s spinner | ✅ | s01_splash.dart | — | s01_splash_test "spinner and announcement come after 1 s" |
| A3 | S01 config non-blocking, 1000 ms budget, background completion | ⚠ 2 s timeout, no background completion | SC:162-173; api_client.dart ApiTimeouts | GET /app/config | none |
| A4 | S01 routing S02/S04/S05/S15 update/S07 link | ✅ | SC:160-189; LC openLink | /app/config | s02/s04/s15 tests |
| A5 | S02 empty/filled/loading, fields read-only | ✅ | WA/lib/screens/s02_sign_in.dart | POST /auth/token | s02_sign_in_test "button needs both fields" |
| A6 | S02 prefilled | ✅ | s02_sign_in.dart | — | "prefills the last e-mail…" |
| A7 | S02 e-mail format error + shake | ✅ | s02_sign_in.dart | — | "e-mail format is checked on blur…" |
| A8 | S02 invalid credentials | ✅ | s02_sign_in.dart; SC | /auth/token | "A07: wrong credentials…" |
| A9 | S02 403 no permission | ✅ | SC | /auth/token | "A02 …danger banner" |
| A10 | S02 deactivated → S15 | ✅ | SC | /auth/token | s15_session_test "A10 deactivated" |
| A11 | S02 429 countdown | ✅ | SC; s02_sign_in.dart | /auth/token | "A08: 429 counts down live…" |
| A12 | S02 5xx/timeout | ✅ | SC | /auth/token | "A09: server error…" |
| A13 | S02 offline banner | ✅ | s02_sign_in.dart | — | "A09: offline disables…" |
| A14 | S03 Face ID/Touch ID/Android | ✅ | WA/lib/screens/s03_biometrics.dart; access/biometric_copy.dart | — | s03_biometrics_test (3 variants) |
| A15 | S03 prompt showing, buttons inert | ✅ | s03_biometrics.dart | — | "both buttons are inert…" |
| A16 | S03 cancelled / not enrolled | ✅ | s03_biometrics.dart | — | "P11…", "P10…" |
| A17 | S04 prompt on first frame | ✅ | WA/lib/screens/s04_unlock.dart | — | s04_unlock_test "prompt opens without a tap" |
| A18 | S04 no auto re-prompt after cancel | ✅ | s04_unlock.dart | — | "P11…" |
| A19 | S04 lockout → passcode | ⚠ hint shown; passcode fallback left to local_auth, unverified | SC; s04_unlock.dart | — | "P12: lockout shows the password hint" |
| A20 | S04 biometrics changed → S02 | ⚠ Android resetBiometricEnrollment never called → later changes undetected | SC; WaiterSystem.kt:97; system_service.dart:48 | — | "P13…" |
| A21 | S04 pending-card banner | ✅ | s04_unlock.dart | — | "a pending card link shows the info banner" |
| A22 | S05 V1 Android listening | ✅ | WA/lib/screens/s05_ready.dart | — | s05_ready_test "TopBar, instruction…" |
| A23 | S05 V2 iPhone ready | ✅ | s05_ready.dart | — | "Scan card opens the system sheet once…" |
| A24 | S05 V3 looking up (150 ms, 3 s, 10 s) | ✅ | s05_ready.dart; LC | POST /scan | "card read → looking up → skeleton…" |
| A25 | S05 V4 NFC off | ✅ | s05_ready.dart | — | "V4 NFC off: deep link…" |
| A26 | S05 V5 no NFC / iPad | ✅ | s05_ready.dart | — | "V5 no NFC…", "iPad: QR-first…" |
| A27 | S05 V6 offline (API probe, tap sound) | ⚠ OS reachability only; no probe; no sound.warning on offline tap | s05_ready.dart; LC; connectivity_service.dart | — | "V6 offline enters after 2 s…" |
| A28 | S05 V7 maintenance (dismiss until text changes) | ⚠ dismissed until cold start | SC | /app/config | "V7 … dismissible" |
| A29 | S05 V8 first-card tip | ✅ | LC showFirstCardTip; s05_ready.dart | — | "Android: tip replaces the hint…" |
| A30 | S05 V9 keep screen on | ✅ | WA/lib/app/waiter_app.dart; LC wantsKeepAwake | — | none |
| A31 | S05 V10 iPhone timeout hint 6 s | ✅ | LC; s05_ready.dart | — | "…timeout hint for 6 s" |
| A32 | S05 V11 NFC unavailable | ✅ | LC | — | "P09: …snackbar" |
| A33 | S06 Android read OK | ✅ | LC | POST /scan | "card read → looking up…" |
| A34 | S06 Android read failed | ⚠ failures 1–2 show nothing | LC | — | "three failed reads show the hold-still hint" |
| A35 | S06 not a gift card | ✅ | LC | — | "a tag that is not a gift card sends no request" |
| A36 | S06 duplicate UID 2 s | ✅ | LC | — | loop_controller_test "…duplicate reads are ignored" |
| A37 | S06 iPhone sheet behaviour | ⚠ Swift never compiled; lookup starts after finishSession | WA/ios/Runner/WaiterNfc.swift; LC | POST /scan | loop_controller_test "iPhone: sheet cancel…" (fake) |
| A38 | S07 base | ✅ | WA/lib/screens/s07_charge.dart | — | charge_screen_test amount entry |
| A39 | S07 amount 0 | ✅ | s07_charge.dart | — | charge_screen_test |
| A40 | S07 over balance | ✅ | s07_charge.dart | — | "over balance: red message, chip…" |
| A41 | S07 ≥ €100 hold | ✅ | s07_charge.dart | — | "€ 99,99 is a tap, € 100,00 needs the 600 ms hold" |
| A42 | S07 full-only | ✅ | LC; s07_charge.dart | — | "partial redemption disabled" group |
| A43 | S07 card states + precedence | ✅ | loop_state.dart; charge/card_state_banner.dart | — | "card states (03b §2.14)" group |
| A44 | S07 blocked reason | ✅ | card_state_banner.dart | — | "blocked with reason" |
| A45 | S07 max single | ✅ | LC; s07_charge.dart | /auth/me | "a known maximum…", redeeming_test "max single…" |
| A46 | S07 velocity/rate limit | ✅ | LC; s07_charge.dart | — | redeeming_test velocity/rate |
| A47 | S07 new card while charging | ✅ | LC; s07_charge.dart | — | charge_screen_test "connection and card switch" |
| A48 | S07 link skeleton | ✅ | s07_charge.dart | POST /scan | "skeleton, 'Still looking …' at 3 s, ✕ cancels" |
| A49 | S07 tablet/landscape | ✅ | s07_charge.dart | — | "tablet landscape: two panes…" |
| A50 | S08 submitting + locks | ✅ | LC; s07_charge.dart | POST /cards/{id}/redeem | redeeming_test "submitting…" |
| A51 | S08 slow 8 s, same key | ✅ | LC | redeem | loop_controller_test "I1/K4…" |
| A52 | S08 uncertain auto, 20 s cap | ⚠ cap checked between attempts only (can run ~25 s) | LC | redeem | redeeming_test "slow after 8 s…" |
| A53 | S08 uncertain final | ✅ | LC | redeem | redeeming_test "final: 'Try again'…"; loop test "Uncertain final…" |
| A54 | S08 card changed meanwhile | ✅ | LC; s07_charge.dart | redeem | "card blocked meanwhile…" |
| A55 | S08 idempotency conflict | ✅ | LC | redeem | "idempotency conflict…" |
| A56 | S08 insufficient balance | ✅ | LC | redeem | "balance changed…" |
| A57 | S08 replayed success | ✅ | LC | redeem | loop test I1/K4 |
| A58 | S09 base (pause in background) | ⚠ auto-return timer not paused in background | LC; WA/lib/screens/s09_success.dart | — | success_screen_test "returns to Ready 4.52 s…", "…10.52 s" |
| A59 | S09 card now empty | ✅ | s09_success.dart | — | "full balance: 'Card is now empty'…" |
| A60 | S09 show guest | ✅ | s09_success.dart; LC | — | "'Show guest' pauses the return…" |
| A61 | S09 next card | ✅ | s09_success.dart | — | "iPhone: 'Scan next card'…", "Android: a new card…" |
| A62 | S10 not found | ✅ | WA/lib/screens/s10_problem.dart; LC | /scan | problem_page_test "not found…" |
| A63 | S10 not found manual | ✅ | s10_problem.dart | /scan | "not found after manual entry…" |
| A64 | S10 foreign restaurant (support code) | ⚠ no support code passed | LC; s10_problem.dart | /scan | "another restaurant: Done → Ready" |
| A65 | S10 verification failed | ✅ | LC; s10_problem.dart | /scan | "verification failed: calm…" |
| A66 | S10 throttled | ✅ | LC; s10_problem.dart | /scan | "throttled: disabled countdown…" |
| A67 | S10 network (SUN rule) | ✅ | LC; s10_problem.dart | /scan | "network: 'Try again'…", "network with a SUN-signed card…" |
| A68 | S10 server | ✅ | s10_problem.dart | /scan | "server error: 'Try again' with support code" |
| A69 | S11 empty/typing/complete | ✅ | WA/lib/screens/s11_manual_entry.dart | — | s11 "16 digits enable the button…" |
| A70 | S11 loading/slow/cancel | ✅ | s11_manual_entry.dart | POST /scan | "slow lookup: 'Still looking …' and Cancel" |
| A71 | S11 422 / paste errors | ✅ | LC; s11_manual_entry.dart | /scan | "422 VALIDATION_FAILED…", "paste strips…" |
| A72 | S11 404 / offline | ✅ | s11_manual_entry.dart | /scan | "not found → 'Edit number'…", "offline…" |
| A73 | S12 starting/searching/torch | ✅ | WA/lib/screens/s12_qr_scan.dart | — | "searching: title, hint, torch…" |
| A74 | S12 detected | ✅ | s12_qr_scan.dart | POST /scan | "valid card: one request…" |
| A75 | S12 slow/cancel/not a card | ✅ | s12_qr_scan.dart | — | "not a gift card: warning line…" |
| A76 | S12 low light hint | ❌ string unused | — | — | none |
| A77 | S12 offline pause | ✅ | s12_qr_scan.dart | — | "offline pauses detection…" |
| A78 | S13 list | ✅ | WA/lib/screens/s13_recent.dart; WA/lib/core/storage/recent_store.dart | — | s13 "rows: summary, hour groups…" |
| A79 | S13 empty | ✅ | s13_recent.dart | — | "empty: EmptyState…" |
| A80 | S13 detail | ✅ | s13_recent.dart | — | "detail: facts, reversal hint exactly once…" |
| A81 | S13 clearing / no backup | ⚠ Android backup exclusion missing | recent_store.dart; SC; AndroidManifest.xml | — | s13 "a 04:00 clear…" |
| A82 | S14 rows | ✅ | WA/lib/screens/s14_menu.dart | GET /devices/current, POST /auth/logout | s14_menu_test |
| A83 | S14 Help row | ❌ | — | — | none |
| A84 | S14 haptics row disabled without engine | ❌ | — | — | none |
| A85 | S15 session expired sheet | ✅ | WA/lib/app/session_sheet_host.dart; s15_session.dart; SC | /auth/token | s15 "10.1 session expired sheet" |
| A86 | S15 device revoked | ✅ | SC; s15_session.dart | — | "A04 device revoked…" |
| A87 | S15 suspended | ✅ | SC; s15_session.dart | GET /auth/me | "A05 suspended…" |
| A88 | S15 locked, in place on S02 | ⚠ full-screen instead | SC; s15_session.dart | /auth/token | "A06 locked…" |
| A89 | S15 deactivated | ✅ | SC | — | "A10 deactivated" |
| A90 | S15 update required | ✅ | SC; s15_session.dart | /app/config | "10.6 update required" |
| A91 | S15 never interrupts money in flight | ⚠ update/refresh on foreground can replace S08 | SC | /app/config, /auth/me | none |
| A92 | S16 NFC off (Android 10+ panel, fallbacks) | ⚠ no NFC panel / fallback | WaiterNfc.kt | — | s05 "V4 NFC off…" |
| A93 | S16 NFC unsupported | ✅ | s05_ready.dart | — | "V5 no NFC…" |
| A94 | S16 camera denied | ✅ | s12_qr_scan.dart | — | "camera denied on the real app path…" |
| A95 | S16 camera restricted | ❌ not distinguished | scan/qr_camera.dart | — | none |
| A96 | S16 no notification permission | ✅ | AndroidManifest.xml | — | none |
| A97 | S17 intro | ✅ | WA/lib/screens/s17_intro.dart; SC | — | s17_intro_test |

## B. State machine and redeem rules

| ID | Requirement | Status | Source | API | Test |
|---|---|---|---|---|---|
| B1 | One loop state holder + global handlers | ✅ | LC; SC | — | loop_controller_test |
| B2 | Reader mode per state | ✅ | LC wantsReaderMode | — | s05 "…pause reader mode" |
| B3 | Keep-awake per state | ✅ | LC; waiter_app.dart | — | none |
| B4 | 500-entry diagnostic ring buffer | ✅ | WA/lib/core/diagnostics/diagnostic_log.dart | — | none |
| B5 | Screens render from state | ✅ | WA/lib/app/app_navigator.dart | — | screen tests |
| B6 | Monotonic timers | ✅ | WA/lib/core/state/clock.dart | — | fake-clock tests |
| B7 | 04:00 rollover drops attempts/context | ⚠ only when Recent has old rows | SC | — | s13 "a 04:00 clear…" |
| B8 | Redeem guards | ✅ | LC canRedeem | — | loop/charge tests |
| B9 | K1 key at Redeem start | ✅ | LC; redeem_attempts.dart | redeem | "I1/K4…" |
| B10 | K2 key bound to card+cents | ✅ | redeem_attempts.dart | — | "Uncertain final…new amount gets a new key" |
| B11 | K3 reuse pending key | ✅ | redeem_attempts.dart | — | same |
| B12 | K4 same key/body, new X-Request-Id | ✅ | api_client.dart; waiter_api.dart | redeem | "I1/K4…" |
| B13 | K5 close rules | ⚠ rollover gap (B7) | LC | — | loop tests |
| B14 | K6 keep rules | ✅ | LC | — | "401 during redeem…(K6)" |
| B15 | K7 memory only | ✅ | redeem_attempts.dart | — | — |
| B16 | K8 no auto-resubmit on conflict | ✅ | LC | — | redeeming_test |
| B17 | K9 key never logged | ✅ | api_client.dart | — | none |
| B18 | I1 | ✅ | LC | — | "I1/K4…" |
| B19 | I2 no redeem offline | ✅ | LC | — | "I2: no redeem request…" |
| B20 | I3 replay = 201, no duplicate row | ✅ | recent_store.dart add() | — | loop test (row count not asserted) |
| B21 | I4 no navigation while locked | ✅ | loop_state.dart; LC back() | — | redeeming_test "submitting…" |
| B22 | I5 server amounts | ✅ | LC | — | success_screen_test |
| B23 | I6 no "nothing booked" while retrying | ✅ | app_en.arb | — | redeeming_test |
| B24 | SUN rule | ✅ | LC; card_link.dart | /scan | "network with a SUN-signed card…" |
| B25 | Interaction locks | ✅ | LC; s07_charge.dart | — | redeeming_test |
| B26–B35 | N1–N10 navigation rules | ✅ ×10 | app_navigator.dart; page_transitions.dart; LC; SC | — | charge "✕ closes without booking (N6)", s04 background test; N10: none |
| B36 | R01 retry schedule | ⚠ (A52) | LC | redeem | loop tests |
| B37 | R02 support code | ✅ | WA/lib/core/format/support_code.dart | — | T/core/format/support_code_test.dart |
| B38 | R03 verification feedback | ✅ | components/problem_screen.dart | — | problem_page_test |
| B39 | R13 portrait lock | ✅ | WA/lib/app/bootstrap.dart; Info.plist | — | none |
| B40 | R14 401 keeps attempt | ✅ | LC | — | "401 during redeem…" |
| B41 | R15 uncertain haptic only | ✅ | LC | — | redeeming_test |
| B42 | R16 S10 haptics | ✅ | problem_screen.dart | — | problem_page_test |
| B43 | R19 read-failure feedback | ✅ | LC | — | s05 "three failed reads…" |
| B44 | R21 hold slop 12 pt | ✅ | components/hold_button.dart | — | hold_button_test "sliding more than 12 pt outside cancels" |

## C. Platform integration (09 §7)

| ID | Requirement | Status | Source | API | Test |
|---|---|---|---|---|---|
| C1 | Reader mode only in allowed states / resumed / focused | ✅ | WaiterNfc.kt; waiter_app.dart | — | s05 reader-pause (Kotlin untested) |
| C2 | NFC-A, no platform sounds, NDEF on, 250 ms | ✅ | WaiterNfc.kt | — | none |
| C3 | URI + colon-hex UID | ✅ | WaiterNfc.kt | — | none |
| C4 | URL validated before request | ✅ | WA/lib/core/api/card_link.dart | — | s05 "not a gift card sends no request" |
| C5 | Feedback after read; 2 s window | ✅ | LC | — | loop test |
| C6 | Background NDEF intent | ✅ | AndroidManifest.xml; WaiterNfc.kt | — | none |
| C7 | Adapter broadcast; NFC not required | ✅ | WaiterNfc.kt; manifest | — | s05 V4 |
| C8 | iOS ISO 14443 session | ⚠ never compiled | WaiterNfc.swift | — | none |
| C9 | iOS entitlements / AID | ✅ | Runner.entitlements; Info.plist | — | none |
| C10 | Usage strings DE/EN/BHS | ✅ | Info.plist; *.lproj/InfoPlist.strings | — | T/core/l10n/import_strings_test.dart |
| C11 | Associated Domains prod + staging | ⚠ single $(CARD_DOMAIN), unbuilt | Runner.entitlements | — | none |
| C12 | Android App Links autoVerify | ✅ | AndroidManifest.xml | — | none |
| C13 | Access gate + pending link 120 s | ✅ | SC; LC | /scan (link) | s04 pending banner |
| C14 | iOS Keychain class | ✅ | WA/lib/core/storage/secure_store.dart | — | none |
| C15 | Android Keystore, StrongBox, no backup | ⚠ no StrongBox, backup not excluded | secure_store.dart; manifest | — | none |
| C16 | Device id; iOS reinstall wipe | ✅ | bootstrap.dart | — | none |
| C17 | Biometrics gate UI not token | ✅ | SC | — | — |
| C18 | Enrolment change detection | ⚠ Android reset never called; iOS uncompiled | WaiterSystem.kt; WaiterSystem.swift | — | s04 P13 (fake) |
| C19 | Biometrics + device credential | ✅ | WA/lib/core/platform/biometrics_service.dart | — | s03/s04 (fakes) |
| C20 | Keep screen on | ✅ | waiter_app.dart | — | none |
| C21 | Android haptics/sounds | ✅ | WaiterFeedback.kt | — | none |
| C22 | iOS haptics/sounds | ⚠ never compiled | WaiterFeedback.swift | — | none |
| C23 | Menu switches gate feedback | ✅ | WA/lib/core/platform/feedback_service.dart | — | s14 "Sounds off/on…" |
| C24 | No capture protection | ✅ | — | — | — |
| C25 | TLS only, no cleartext | ✅ | res/xml/network_security_config.xml; environment.dart | — | none |
| C26 | Orientation / multi-window | ✅ | bootstrap.dart; Info.plist; WaiterNfc.kt | — | none |

## D. Backend prerequisites and API contract (09 §9)

| ID | Requirement | Status | Source | API | Test |
|---|---|---|---|---|---|
| D1 | Device-bound token login | ✅ | BE/app/Http/Controllers/Api/V1/AuthController.php; BE/app/Services/Auth/DeviceTokenService.php; BE/app/Http/Middleware/EnforceDeviceToken.php | POST /api/v1/auth/token, POST /api/v1/auth/logout | BE/tests/Feature/WaiterAppTokenTest.php (12); e2e/waiter-api.mjs |
| D2 | Settings in /auth/me; max in error context | ✅ | RestaurantSettingsResource.php; GiftCardService.php | GET /auth/me, redeem | e2e "/auth/me returns the restaurant settings…" |
| D3 | AASA + assetlinks | ✅ | frontend/src/lib/app-links.ts; frontend/src/app/.well-known/* | /.well-known/apple-app-site-association, /.well-known/assetlinks.json | frontend/src/lib/app-links.test.ts |
| D4 | /app/config | ⚠ notice not per locale; app ignores card_domains | BE/app/Http/Controllers/Api/V1/AppConfigController.php | GET /api/v1/app/config | BE/tests/Feature/WaiterAppConfigTest.php (4) |
| D5 | Waiter's own transactions today (optional) | ❌ | — | — | none |
| D6 | /scan accepts link/qr with picc/cmac | ✅ | BE/app/Enums/ScanMethod.php | /scan | CardScanTest "ntag424 sun…" |
| D7 | nfc_uid colon format | ✅ | NfcUid | /scan | CardScanTest "cloned ntag21x…" |
| D8 | Replay 200 replayed:true | ✅ | GiftCardActionController.php | redeem | WaiterAppTokenTest idempotency; e2e |
| D9 | Concurrent same key never 500 | ✅ | GiftCardService.php idempotent() | redeem | none (no concurrency test) |
| D10 | Headers | ✅ | api_client.dart; bootstrap.dart | all | loop test "I1/K4…" |
| D11 | Timeouts | ✅ | api_client.dart | all | redeeming_test slow |
| D12 | Cents; switch on code | ✅ | api_client.dart; LC | — | — |
| D13 | Error classification incl. "not sent" | ⚠ DNS/TLS treated as uncertain | api_client.dart; api_failure.dart | — | none |
| D14 | Per-screen calls | ✅ | SC | per spec | s14 "Sign out confirmed…also offline" |

## E. Performance, QA, Definition of Done (09 §10–§12)

| ID | Requirement | Status | Source | Test |
|---|---|---|---|---|
| E1 | Cold start <1.5 s | ❌ not measured (device) | — | none |
| E2 | Warm resume <400 ms | ❌ device | — | none |
| E3 | NFC read → haptic <50 ms | ❌ device | — | none |
| E4 | Lookup → S07 <150 ms | ❌ not measured | — | none |
| E5 | Skeleton only after 150 ms | ✅ | components/support/delayed_presence.dart | s05 "…skeleton after 150 ms…" |
| E6 | Key → digit+haptic <50 ms | ❌ device | — | none |
| E7 | Redeem → S09 frame <100 ms | ❌ | — | none |
| E8 | 60/120 fps | ⚠ flag set, not measured | Info.plist | none |
| E9 | Tap-to-ready 3.5/4.5 s | ❌ needs real cards | — | none |
| E10 | Download <25 MB | ⚠ APK arm64 23.6 MB; no store report | build outputs | none |
| E11 | Memory/battery | ❌ device | — | none |
| E12 | Warm HTTP/2 connection | ⚠ dio HTTP/1.1 keep-alive | api_client.dart | none |
| E13 | No analytics/crash SDKs | ✅ | pubspec.yaml | — |
| E14 | G1 strings, no truncation | ⚠ widget tests only | l10n | pseudo_localization_test; 200 % tests |
| E15 | G2 targets + labels | ⚠ widget level only | components | screen semantics tests |
| E16 | G3 light/dark/high contrast | ✅ | core/theme | theme_test, contrast_test |
| E17 | G4 Reduce Motion | ✅ | — | s05/s17 Reduce Motion tests |
| E18 | G5 primary action bottom 45 % | ✅ | layout | thumb-zone tests |
| E19 | G6 glyph coverage | ✅ | assets/fonts | typography_test |
| E20 | Per-screen acceptance criteria | ⚠ widget level; NFC/sheet/biometrics/camera unverified | — | T/screens/** |
| E21 | Device matrix | ❌ | — | none |
| E22 | DoD: all states on iOS + Android reference device | ❌ | — | none |
| E23 | DoD: I1–I5 automated | ✅ | — | loop_controller_test, redeeming_test |
| E24 | DoD: no hard-coded strings/colours/durations lint | ⚠ no lint rule; literal durations in screens | analysis_options.yaml | none |
| E25 | DoD: no sensitive data in logs | ✅ | diagnostic_log.dart | none |
| E26 | DoD: VoiceOver/TalkBack verified | ❌ | — | none |
| E27 | DoD: screenshot design review | ❌ no screenshots | — | none |
| E28 | Release: prerequisites live, links verified | ❌ not verifiable | — | none |

## F. Assets and strings

| ID | Requirement | Status | Source | Test |
|---|---|---|---|---|
| F1 | iOS icon default/dark/tinted | ✅ | WA/ios/Runner/Assets.xcassets/AppIcon.appiconset | none |
| F2 | Android adaptive icon | ✅ | res/mipmap-anydpi-v26, drawable/ic_launcher_* | none |
| F3 | Play icon 512 + feature graphic | ❌ | — | none |
| F4 | iOS launch storyboard + mark | ✅ | LaunchScreen.storyboard; LaunchMark.imageset | none |
| F5 | Android 12+ splash + legacy | ✅ | values-v31/styles.xml; drawable-*/splash_icon_legacy.png | none |
| F6 | Geist fonts + OFL | ✅ | WA/assets/fonts | typography_test |
| F7 | 4 sounds .caf/.ogg + masters | ✅ | ios/Runner/Sounds; res/raw; tool/sounds_src | assets_test |
| F8 | No Lottie/Rive | ✅ | pubspec.yaml | — |
| F9 | 46 icons | ✅ | WA/assets/icons | assets_test "46 icons…" |
| F10 | Custom NFC/card arcs icons | ✅ | assets/icons | assets_test |
| F11 | 10 illustrations | ✅ | WA/assets/illustrations | assets_test |
| F12 | Illustration sizes/strokes | ✅ | core/theme/illustrations.dart | assets_test |
| F13 | 272 string keys | ✅ | WA/lib/l10n/*.arb | arb_integrity_test "key count: 272…" |
| F14 | DE/EN/BHS (+hr/sr) | ✅ | 5 ARBs | arb_integrity_test |

## Part 1 totals

| Group | ✅ | ⚠ | ❌ | Total | (✅+0.5⚠)/total | ✅ only |
|---|---|---|---|---|---|---|
| A Screens | 79 | 14 | 4 | 97 | 88.7 % | 81.4 % |
| B State/rules | 41 | 3 | 0 | 44 | 96.6 % | 93.2 % |
| C Platform | 21 | 5 | 0 | 26 | 90.4 % | 80.8 % |
| D Backend/API | 11 | 2 | 1 | 14 | 85.7 % | 78.6 % |
| E Performance/QA/DoD | 8 | 7 | 13 | 28 | 41.1 % | 28.6 % |
| F Assets/strings | 13 | 0 | 1 | 14 | 92.9 % | 92.9 % |
| **Overall** | **173** | **31** | **19** | **223** | **84.5 %** | **77.6 %** |

# Part 2 — Web platform vs. docs/de product specification

Key: B = backend/app/, F = frontend/src/, T = backend/tests/Feature/, U = backend/tests/Unit/, E n = step n of e2e/pilot-journey.mjs; API paths under /api/v1.

## A. feature-overview.md (FO)

| # | Feature (FO §) | Status | Backend | API | Frontend | Tests |
|---|---|---|---|---|---|---|
| 1.1 | Create card (preset € 25–150 / free amount) | ✅ | B/Services/GiftCards/GiftCardService.php `issue`, Http/Requests/Cards/StoreGiftCardRequest.php | POST /cards | F/app/(app)/cards/new/page.tsx (`PRESETS`) | T/GiftCardLifecycleTest::test_manager_creates_a_card_with_ledger_entry_and_nfc_payload, ::test_card_value_limits_are_enforced; E 4 |
| 1.2 | Valid until (default / own date / no expiry, 23:59 local time) | ✅ | GiftCardService `issue`/`endOfDay`, Data/IssueGiftCardData.php | POST /cards | cards/new (default prefilled, empty = no expiry) | T/HardeningTest::test_expiry_is_the_end_of_the_day_in_the_restaurant_timezone, ::test_explicit_null_expiry_means_no_expiry_and_missing_means_default; GiftCardLifecycleTest::test_default_expiration_uses_restaurant_setting |
| 1.3 | Assign customer (Anonymous / Existing / New) | ✅ | GiftCardService `issue`, StoreGiftCardRequest | POST /cards | cards/new (segmented control) | T/ReportingTest::test_customer_management_and_gdpr_anonymisation; E 4 |
| 1.4 | Recipient name | ✅ | StoreGiftCardRequest, GiftCardService | POST/PATCH /cards | cards/new; F/app/print/cards/[id]/page.tsx | T/ReportingTest::test_customer_management_and_gdpr_anonymisation |
| 1.5 | Internal notes (searchable) | ✅ | Models/GiftCard.php `scopeSearch` | POST /cards, GET /cards?search | cards/new, cards/[id] | T/GiftCardLifecycleTest::test_manager_creates_a_card…; ReportingTest::test_card_search_filters_and_sorting |
| 1.6 | Activate immediately / create inactive | ✅ | GiftCardService `issue` | POST /cards `activate` | cards/new switch | T/GiftCardLifecycleTest::test_inactive_cards_must_be_activated_first |
| 1.7 | Card number: 16 digits, random, Luhn, grouped, optional prefix | ✅ | Services/GiftCards/CardNumberGenerator.php, Support/CardNumber.php | — | card-visual, cards list | U/CardNumberTest (all 3); T/GiftCardLifecycleTest::test_manager_creates_a_card… (prefix "42") |
| 1.8 | Card types NTAG213 / 215 / 216 | ✅ | Enums/NfcTagType.php | POST /cards `nfc_tag_type` | F/lib/nfc.ts `TAG_TYPES` | T/GiftCardLifecycleTest::test_manager_creates_a_card… (ntag215) |
| 1.9 | QR-only cards | ✅ | NfcTagType::QrOnly, Services/GiftCards/QrCodeService.php | GET /cards/{id}/qr | components/cards/nfc-writer.tsx, card-qr.tsx | T/GiftCardLifecycleTest::test_qr_code_is_rendered_as_svg |
| 1.10 | NTAG 424 DNA (SUN / AES-CMAC, counter) | ✅ (plan gating: see 12.5) | Services/Nfc/Ntag424SunVerifier.php, AesCmac.php, CardScanService `verifyChip` | POST /scan (picc/cmac) | nfc-writer (template), terminal.tsx | T/CardScanTest::test_ntag424_sun_messages_are_verified_and_replays_rejected; U/Ntag424SunVerifierTest (8) |
| 1.11 | Write NFC tag (Web NFC; copy link; Mark as written) | ✅ | GiftCardService `bindNfcTag` | GET/POST /cards/{id}/nfc | components/cards/nfc-writer.tsx, lib/nfc.ts `writeCardTag` | E 4 (Mark as written); T/CardScanTest::test_cloned_ntag21x… (POST nfc) |
| 1.12 | Bind chip serial number (UID) | ✅ | GiftCardService `bindNfcTag`, Http/Requests/Cards/BindNfcTagRequest.php | POST /cards/{id}/nfc | nfc-writer (auto UID + manual field) | T/CardScanTest::test_cloned_ntag21x_is_detected_by_uid_binding; HardeningTest::test_invalid_chip_serial_numbers_are_rejected |
| 1.13 | Lock tag after writing | ✅ | stores the `nfc_locked` flag only (the lock itself happens on the client) | POST /cards/{id}/nfc `locked` | lib/nfc.ts `makeReadOnly` | none |
| 1.14 | Print card / QR (ISO ID-1, front/back, restaurant language) | ✅ | QrCodeService | GET /cards/{id}/qr | app/print/cards/[id]/page.tsx, lib/guest-copy.ts | T/GiftCardLifecycleTest::test_qr_code_is_rendered_as_svg (QR only) |
| 1.15 | Statuses Active / Inactive / Redeemed / Blocked / Expired / Replaced | ✅ | Enums/GiftCardStatus.php | — | components/common/status-badge.tsx | multiple lifecycle tests |
| 1.16 | Redeem full/partial; partial can be switched off | ✅ | GiftCardService `redeem` | POST /cards/{id}/redeem | terminal.tsx, money-dialog.tsx | T/GiftCardLifecycleTest::test_partial_and_full_redemption, ::test_full_redemption_only_setting; E 5 |
| 1.17 | Reload; can be switched off | ✅ | GiftCardService `reload` | POST /cards/{id}/reload | money-dialog, terminal | T/GiftCardLifecycleTest::test_reload_revives_redeemed_cards_and_respects_limits; E 6 |
| 1.18 | Transfer balance (full/partial) | ✅ | GiftCardService `transfer` | POST /cards/{id}/transfer | components/cards/transfer-dialog.tsx | T/GiftCardLifecycleTest::test_balance_transfer_between_cards; HardeningTest::test_inactive_cards_cannot_transfer_value |
| 1.19 | Replace lost card (Lost / Damaged / Stolen) | ✅ | GiftCardService `replace` | POST /cards/{id}/replace | cards/[id] ReasonDialog suggestions | T/GiftCardLifecycleTest::test_lost_card_replacement_moves_balance_to_new_card; HardeningTest::test_replacing_*; E 6–7 |
| 1.20 | Block / Unblock with reason | ✅ | GiftCardService `block`/`unblock` | POST /cards/{id}/block, /unblock | cards/[id] (suggested reasons) | T/GiftCardLifecycleTest::test_blocked_and_expired_cards_cannot_be_redeemed |
| 1.21 | Expire now (writes off the balance) | ✅ | GiftCardService `expire` | POST /cards/{id}/expire | cards/[id] | T/GiftCardLifecycleTest::test_manual_expiration_writes_off_balance |
| 1.22 | Activate | ✅ | GiftCardService `activate` | POST /cards/{id}/activate | cards/[id] menu | T/GiftCardLifecycleTest::test_inactive_cards_must_be_activated_first |
| 1.23 | Edit details (customer, recipient, notes, validity) | ✅ | GiftCardService `update`, UpdateGiftCardRequest | PATCH /cards/{id} | components/cards/edit-card-dialog.tsx | none that succeeds (only T/TenantIsolationTest::test_cards_of_other_restaurants_are_invisible checks the 404) |
| 1.24 | Reverse (counter-booking, reason in one tap) | ✅ | GiftCardService `reverse`, TransactionController | POST /transactions/{id}/reverse | card-history.tsx, transactions page | T/GiftCardLifecycleTest::test_redemption_can_be_reversed_once |
| 1.25 | Card history: time, person, **device**, balance after | ⚠ events (block, replace, …) have no device and no balance | Services/GiftCards/CardHistoryService.php | GET /cards/{id}/history | card-history.tsx | T/GiftCardLifecycleTest::test_card_history_merges_ledger_and_events |
| 1.26 | Card list: search (number/customer/recipient/note), status filter, sort | ✅ | GiftCardController `filteredQuery`, GiftCard `scopeSearch` | GET /cards | app/(app)/cards/page.tsx | T/ReportingTest::test_card_search_filters_and_sorting |
| 1.27–29 | Card ordering service, Apple/Google Wallet, online voucher sales | not in scope (planned per spec) | — | — | — | — |
| 2.1 | Web app, installable on home screen | ✅ | — | — | public/manifest.webmanifest, layout.tsx appleWebApp (no service worker) | none |
| 2.2 | NFC Android: press once, then auto-read | ✅ | CardScanService | POST /scan | terminal.tsx `startNfc` + permission auto-listen | none (UI); T/CardScanTest::test_waiter_scans_nfc_url_and_sees_minimal_card_view |
| 2.3 | NFC iPhone (background tag → notification) | ✅ | — | POST /scan (link) | app/c/[token]/page.tsx → WaiterTerminal `initialToken` | none |
| 2.4 | **Scan QR code** "with the camera of any phone" | ⚠ in-app scanner uses `BarcodeDetector`, which Safari and Firefox don't support; iPhone falls back to the system camera → `/c/{token}` | — | POST /scan | components/waiter/qr-scanner.tsx | none |
| 2.5 | Card number / Find card | ✅ | CardScanService `find` | POST /scan (card_number) | terminal manual mode | T/CardScanTest::test_manual_card_number_lookup; E 5 |
| 2.6 | Till-style keypad 2490 → € 24,90 | ✅ | — | — | components/waiter/keypad.tsx | E 5 + 8 (CSV `-24,90`) |
| 2.7 | Full balance + warning if amount > balance | ✅ | — | — | terminal.tsx | E 5 (button waited for) |
| 2.8 | Big **Redeem € X** button | ✅ | — | — | terminal.tsx | E 5 |
| 2.9 | Success screen, Next card, auto-return after 8 s | ✅ | — | — | terminal.tsx `AUTO_RESET_MS` | E 5/7 |
| 2.10 | Tap next card directly on the success screen | ✅ | — | — | terminal.tsx `listenForTaps` | none |
| 2.11 | Vibration (Android) | ✅ | — | — | terminal.tsx `navigator.vibrate` | none |
| 2.12 | Clear warnings (blocked/replaced red, inactive/empty yellow, expired, not found) | ✅ | ScannedCardResource | POST /scan | terminal.tsx | E 7 ("This card was replaced") |
| 2.13 | Device-specific hints | ✅ | — | — | terminal.tsx `tapHint` | none |
| 2.14 | Small screens (iPhone SE) | ✅ | — | — | globals.css `@custom-variant short`, terminal | none |
| 2.15 | Block from the waiter app if the role allows | ✅ | ScannedCardResource `actions.block` | POST /cards/{id}/block | terminal.tsx | T/CardScanTest::test_waiter_scans_nfc_url… (`actions.block=false`) |
| 2.16 | Never double-booked | ✅ | Http/Middleware/RequireIdempotencyKey.php, GiftCardService `idempotent` | Idempotency-Key | terminal.tsx (keeps the key on 5xx) | T/IdempotencyAndConcurrencyTest::test_retried_redemption_is_not_charged_twice |
| 2.17 | Waiter app in German | not in scope (planned per spec) | — | — | — | — |
| 3.1 | Outstanding balance + "on N cards" | ✅ | Services/Dashboard/DashboardService.php `stats` | GET /dashboard/stats | app/(app)/dashboard/page.tsx | T/PilotReadinessTest::test_dashboard_reports_the_number_of_cards_carrying_the_liability |
| 3.2 | Revenue this month vs. previous month | ✅ | DashboardService `salesBetween` | GET /dashboard/stats | dashboard `Trend` | T/ReportingTest::test_dashboard_statistics |
| 3.3 | Redeemed this month and today | ✅ | DashboardService | same | dashboard | T/ReportingTest::test_dashboard_statistics |
| 3.4 | Cards sold total / month / in use | ✅ | DashboardService | same | dashboard | T/ReportingTest::test_dashboard_statistics |
| 3.5 | Sold vs. redeemed chart, 7/30/90 days | ✅ | DashboardService `dailySeries`, DashboardController | GET /dashboard/charts?days= | components/charts/sales-chart.tsx | T/ReportingTest::test_dashboard_statistics (days=7) |
| 3.6 | Monthly revenue, 12 months | ✅ | `monthlySeries` | same | monthly-revenue-chart.tsx | T/ReportingTest::test_dashboard_statistics |
| 3.7 | Cards by status | ✅ | `statusDistribution` | same | status-breakdown.tsx | none |
| 3.8 | Recent activity + View all | ✅ | DashboardController `activity` | GET /dashboard/activity | dashboard | T/ReportingTest::test_dashboard_statistics |
| 3.9 | Welcome / getting started (4 steps) | ✅ | — | — | components/dashboard/getting-started.tsx | E 2 |
| 3.10 | Transactions journal: immutable; date/type/search filters; reverse | ✅ | TransactionController, Models/Concerns/Immutable.php | GET /transactions | app/(app)/transactions/page.tsx | T/ReportingTest::test_transactions_listing_and_filters; GiftCardLifecycleTest::test_ledger_rows_are_immutable |
| 3.11 | CSV export (semicolon, decimal comma, readable names) | ✅ | Services/Exports/CsvExporter.php | GET /cards/export, /transactions/export | cards and transactions pages | T/HardeningTest::test_exports_use_decimal_comma_for_german_locales; PilotReadinessTest::test_exports_use_readable_status_and_type_names; E 8 |
| 3.12 | Light and dark mode | ✅ | — | — | app/providers.tsx (next-themes), app-sidebar.tsx | none |
| 3.13 | Multi-location dashboard | not in scope (planned per spec) | — | — | — | — |
| 4.1 | Customer list | ✅ | CustomerController `index` | GET /customers | app/(app)/customers/page.tsx | T/TenantIsolationTest::test_customers_and_users_are_isolated |
| 4.2 | Customer detail + cards | ✅ | CustomerController `show` | GET /customers/{id} | customers/[id]/page.tsx | T/ReportingTest::test_customer_management_and_gdpr_anonymisation |
| 4.3 | Edit name / e-mail / phone | ✅ | CustomerController `update` | PATCH /customers/{id} | components/common/customer-dialog.tsx | T/HardeningTest::test_customer_personal_data_never_enters_the_audit_trail |
| 4.4 | GDPR anonymisation | ✅ | CustomerController `anonymize` | POST /customers/{id}/anonymize | customers/[id] | T/ReportingTest::test_customer_management_and_gdpr_anonymisation |
| 5.1 | Roles Owner / Manager / Waiter | ✅ | Enums/RoleSlug.php, Enums/Permission.php | all `can:` routes | components/layout/nav.ts, auth-guard | T/PermissionsTest (3 role tests) |
| 5.2 | Unlimited team members | ✅ (no limit anywhere) | UserService | POST /users | team page | none |
| 5.3 | Invite by e-mail, link valid 72 h, own password | ✅ | Services/Users/UserService.php `create`/`sendInvitation`, config/auth.php `invitations` 4320 min | POST /users | app/(app)/team/page.tsx | T/StaffManagementTest::test_owner_invites_a_waiter, ::test_invited_staff_can_set_a_password_for_72_hours; E 1–3 |
| 5.4 | Resend invitation / password reset (60 min) | ✅ | UserService `sendPasswordReset` | POST /users/{id}/password-reset | team page | T/StaffManagementTest::test_forgot_password_links_expire_after_an_hour (endpoint itself untested) |
| 5.5 | Deactivate/reactivate ends sessions and API keys | ✅ | UserService `deactivate`/`terminateAccess`, ResolveTenant | POST /users/{id}/deactivate, /activate | team page | T/StaffManagementTest::test_deactivation_revokes_access_and_protects_last_owner |
| 5.6 | User status Invited → Active, Locked, Deactivated | ✅ | UserResource (`status`, `locked`) | GET /users | components/common/user-status-badge.tsx | E 3 ("Invited") |
| 5.7 | Devices auto-registered and named ("iPhone · Safari") | ✅ | Http/Middleware/TrackDevice.php, Services/Devices/DeviceService.php | GET /devices | app/(app)/devices/page.tsx | T/PilotReadinessTest::test_new_devices_are_named_after_hardware_and_browser_not_the_person |
| 5.8 | Rename device | ✅ | DeviceService `update` | PATCH /devices/{id} | devices RenameDialog | none |
| 5.9 | Revoke / Restore with confirmation | ✅ | DeviceService, TrackDevice | POST /devices/{id}/revoke, /restore | devices (AlertDialog) | T/PermissionsTest::test_revoked_devices_are_blocked; WaiterAppTokenTest::test_revoking_the_device_stops_the_token_and_restoring_allows_it_again |
| 5.10 | Unlimited devices | ✅ | — | — | — | none |
| 6.1 | Card value min/max (defaults € 5 / € 1,000) | ✅ | migration 000001 defaults, UpdateCardSettingsRequest | PUT /settings/cards | components/settings/card-settings-form.tsx | T/GiftCardLifecycleTest::test_card_value_limits_are_enforced |
| 6.2 | Max card balance (default € 2,000) | ✅ | same, GiftCardService `reload`/`transfer` | same | same | T/GiftCardLifecycleTest::test_reload_revives_redeemed_cards_and_respects_limits |
| 6.3 | Max single redemption | ✅ | GiftCardService `redeem` | same | same | T/WaiterAppTokenTest (sets `max_single_redemption`) |
| 6.4 | Default validity in months, 0 = none, factory setting 36 | ✅ | migration default 36 | same | same | T/GiftCardLifecycleTest::test_default_expiration_uses_restaurant_setting; SettingsAndApiTokensTest::test_owner_updates_card_settings_with_validation |
| 6.5 | Fraud limit: redemptions per card per hour (default 10) | ✅ | GiftCardService `assertVelocity` | same | same | T/IdempotencyAndConcurrencyTest::test_velocity_limit_stops_rapid_repeated_redemptions |
| 6.6 | Allow reloading | ✅ | GiftCardService `reload` | same | same | T/GiftCardLifecycleTest::test_reload_revives… (RELOAD_NOT_ALLOWED) |
| 6.7 | Allow partial redemption | ✅ | GiftCardService `redeem` | same | same | T/GiftCardLifecycleTest::test_full_redemption_only_setting |
| 6.8 | Public balance page on/off | ✅ | PublicCardController | same | same | T/CardScanTest::test_public_balance_check |
| 6.9 | Clone protection (chip binding) on/off | ✅ | CardScanService (`enforce_nfc_uid_binding`) | same | same | none for the switch |
| 6.10 | Lock chips after writing on/off | ✅ | GiftCardActionController `nfcPayload` | same | same | none |
| 6.11 | Guest e-mails on/off | ✅ | Services/Notifications/CardNotificationService.php | same | same | T/NotificationTest::test_no_email_when_disabled |
| 6.12 | Card number prefix, brand colour, e-mail footer | ✅ | CardNumberGenerator, TemplatedMail (`receipt_footer`) | same | same | T/GiftCardLifecycleTest (prefix); SettingsAndApiTokensTest::test_owner_updates_card_settings_with_validation (colour) |
| 6.13 | Restaurant profile (name, legal name, VAT, e-mail, phone, website, address) | ✅ | UpdateRestaurantRequest, RestaurantService | PUT /settings/restaurant | restaurant-profile-form.tsx | none |
| 6.14 | Language/number format de-AT, de-DE, de-CH, en-GB, en-US | ✅ | UpdateRestaurantRequest `locale` | same | same | T/HardeningTest::test_exports_use_decimal_comma_for_german_locales |
| 6.15 | Time zone (validity and daily figures) | ✅ | GiftCardService `endOfDay`, DashboardService | same | same | T/HardeningTest::test_expiry_is_the_end_of_the_day_in_the_restaurant_timezone |
| 6.16 | Currency: euro | ✅ | Restaurant `currency` | — | — | none |
| 6.17–18 | Factory setting "no expiry"; CHF/BAM/RSD | not in scope (planned per spec) | — | — | — | — |
| 7.1 | Card purchased e-mail | ✅ | Listeners/QueueCardNotifications.php `handleIssued` | — | — | T/NotificationTest::test_customer_receives_localised_issue_email_with_escaped_content |
| 7.2 | Card reloaded e-mail | ✅ | `handleReloaded` | — | — | T/HardeningTest::test_each_card_event_sends_exactly_one_email |
| 7.3 | Expiring soon, 30 days before | ✅ | Console/Commands/NotifyExpiringCards.php, routes/console.php | — | — | T/NotificationTest::test_expiring_reminders_are_sent_once |
| 7.4 | Low balance "under € 5" | ✅ (code also sends at exactly € 5.00: `<= 500`) | `handleRedeemed` | — | — | none |
| 7.5 | Edit templates DE/EN; **preview with real restaurant name** | ⚠ no preview in the editor; only the subject in the list shows the name | NotificationTemplateController | GET/PUT /settings/notification-templates | components/settings/notification-templates.tsx | T/SettingsAndApiTokensTest::test_notification_template_override |
| 7.6 | Templates in BCS | not in scope (planned per spec) | — | — | — | — |
| 8.1 | Guests check balance themselves (tap/QR) | ✅ | PublicCardController | GET /public/cards/{token} | app/c/[token]/page.tsx | T/CardScanTest::test_public_balance_check |
| 8.2 | Shows balance, status, validity, masked number, no personal data | ✅ | PublicCardController | same | same | T/CardScanTest::test_public_balance_check |
| 8.3 | Restaurant language (DE/EN) | ✅ | returns `locale` | same | lib/guest-copy.ts | none |
| 8.4 | Can be switched off | ✅ | `public_balance_check` | same | same | T/CardScanTest::test_public_balance_check |
| 9.1 | No money on the card, 122-bit ID | ✅ | CardUrlBuilder, `Str::uuid()` | — | — | T/GiftCardLifecycleTest::test_manager_creates… (v4 regex); U/CardUrlBuilderTest |
| 9.2 | Atomic, idempotent bookings | ✅ | GiftCardService `lock`/`idempotent` | money routes | — | T/IdempotencyAndConcurrencyTest (all 6); no parallel test (see W20) |
| 9.3 | Immutable journal, sum = balance | ✅ | Immutable trait, GiftCardTransaction | — | — | T/GiftCardLifecycleTest::test_ledger_rows_are_immutable, ::test_ledger_rows_cannot_be_deleted |
| 9.4 | Copy detection NTAG21x | ✅ | CardScanService `verifyChip` | POST /scan | — | T/CardScanTest::test_cloned_ntag21x_is_detected_by_uid_binding |
| 9.5 | Copy protection NTAG 424 DNA | ✅ | Ntag424SunVerifier, CardScanService | POST /scan | — | T/CardScanTest::test_ntag424_sun_messages…; U/Ntag424SunVerifierTest |
| 9.6 | Brute-force protection: rate limits, lockout after 10 (15 min), throttled card lookup | ✅ | AppServiceProvider `configureRateLimiting`, CredentialVerifier, CardScanService | — | — | T/AuthenticationTest::test_account_is_locked_after_repeated_failures, ::test_login_is_rate_limited; CardScanTest::test_failed_lookups_are_throttled |
| 9.7 | Device-bound sessions; password change signs out other sessions | ✅ | TrackDevice `pinSession`, Sanctum AuthenticateSession (config/sanctum.php) | — | — | T/HardeningTest::test_session_is_pinned_to_the_device_it_started_on (password logout untested) |
| 9.8 | Password rules: ≥12 characters, mixed case, digit, bcrypt | ✅ (production only; other environments allow 10) | AppServiceProvider `configurePasswords` | — | — | none |
| 9.9 | Audit log with person, time, IP; warnings in red | ✅ | Services/Audit/AuditLogger.php | GET /audit-logs | components/common/audit-table.tsx, lib/audit.ts `ALERTS` | T/AuthenticationTest::test_account_is_locked… (auth.locked) |
| 9.10 | Tenant separation | ✅ | BelongsToRestaurant, RestaurantScope, ResolveTenant, RequireTenant | all | — | T/TenantIsolationTest (5) |
| 9.11 | HTTPS / TLS / HSTS, CSP, CSRF | ✅ | infra/caddy/Caddyfile, Http/Middleware/SecurityHeaders.php, frontend/next.config.ts, Sanctum `statefulApi` | — | lib/api/client.ts (XSRF) | none |
| 9.12 | Backups: nightly, 14 days + off-site copy, daily snapshots | ⚠ only `infra/scripts/backup.sh` is in the repo (dump + 14-day prune). Cron, rclone off-site copy and snapshots are manual ops steps from the docs | infra/scripts/backup.sh, docker-compose.yml `backup` | — | — | none |
| 10.1–2 | EU hosting (Hetzner); AVV | n/a (organisational) | — | — | — | — |
| 10.3 | Only necessary cookies | ✅ no analytics; device ID in localStorage | — | — | lib/device.ts | none |
| 10.4 | Customer optional | ✅ | StoreGiftCardRequest | POST /cards | cards/new "Anonymous" | T/GiftCardLifecycleTest (issueCard without customer) |
| 10.5 | Anonymisation keeps financial data | ✅ | CustomerController `anonymize` | same as 4.4 | — | T/ReportingTest::test_customer_management_and_gdpr_anonymisation |
| 10.6 | No personal data in the audit log ("[personal data]") | ✅ | AuditLogger `PERSONAL_DATA` | — | — | T/HardeningTest::test_customer_personal_data_never_enters_the_audit_trail |
| 10.7 | Data export anytime; deletion 30 days after contract end | ⚠ only card and transaction CSV (no customer or full export); no deletion process in code (restaurants can't be deleted: HTTP 405) | CsvExporter | /cards/export, /transactions/export | — | T/PlatformAdminTest::test_restaurant_data_is_never_deleted (shows the opposite of deletion) |
| 11.1 | Create restaurant + owner invitation | ✅ | Services/Restaurants/RestaurantService.php `create` | POST /admin/restaurants | app/(app)/admin/page.tsx | T/PlatformAdminTest::test_admin_onboards_a_restaurant_with_owner_invitation; E 1 |
| 11.2 | Suspend / reactivate with reason | ✅ | RestaurantService | POST /admin/restaurants/{id}/suspend, /reactivate | admin/restaurants/[id] | T/PlatformAdminTest::test_admin_lists_and_suspends_restaurants |
| 11.3 | **Open restaurant**: banner, fully audited | ✅ | ResolveTenant (X-Restaurant-Id), AuditLogger | any + header | components/layout/acting-banner.tsx | T/PlatformAdminTest::test_admin_can_act_inside_a_restaurant_explicitly |
| 11.4 | Platform audit log | ✅ | PlatformController `auditLogs` | GET /admin/audit-logs | admin/audit/page.tsx | T/PlatformAdminTest::test_platform_stats_and_audit |
| 11.5 | System settings (default plan, maintenance notice, support e-mail) | ✅ | PlatformController, database/seeders/SystemSettingsSeeder.php | GET/PUT /admin/system-settings | admin/settings/page.tsx | T/WaiterAppConfigTest::test_platform_admin_sets_minimum_versions_with_validation_and_audit |
| 11.6 | Automatic billing (Stripe/SEPA) | not in scope (planned per spec) | — | — | — | — |
| 12.1 | REST API (cards, bookings, redeem, reload, transfer, customers, KPIs, exports) | ✅ | routes/api.php | all | — | T/SettingsAndApiTokensTest::test_api_token_is_restricted_to_its_abilities_and_can_be_revoked |
| 12.2 | API keys: restricted, max. 365 days, revocable, last use logged | ✅ (IP not shown: see RC32) | Services/ApiTokens/ApiTokenService.php, Listeners/RecordTokenUsage.php | GET/POST /api-tokens, /revoke | components/settings/api-tokens.tsx | T/SettingsAndApiTokensTest (2 token tests); 365-day cap untested |
| 12.3 | Idempotent bookings via API | ✅ | RequireIdempotencyKey | money routes | — | T/IdempotencyAndConcurrencyTest::test_money_endpoints_require_an_idempotency_key |
| 12.4 | CSV export | ✅ (same as 3.11) | CsvExporter | exports | — | T/ReportingTest::test_csv_exports_are_streamed_and_sanitized |
| 12.5 | **Plan columns** (NTAG 424, REST API, API keys, idempotent API not in Start; Gruppe-only items) | ❌ `restaurants.plan` is free text; nothing checks it | Models/Restaurant.php `plan` | — | — | none |
| 12.6 | POS integrations (ready2order, orderbird, SumUp) | not in scope (planned, under review Q1 2027) | — | — | — | — |
| 13.1–7 | Video onboarding, personal onboarding, on-site setup, e-mail/phone support, card design help, contact person/SLA | n/a (organisational) | — | — | — | — |

**Feature overview totals:** 120 rows checked: 114 ✅ · 5 ⚠ · 1 ❌ (95.0 % / 97.1 %). Plus 10 planned and 9 n/a.

---

## B. security-whitepaper.md (WP)

| # | Control (WP §) | Status | Backend | API | Frontend | Tests |
|---|---|---|---|---|---|---|
| W1 | Card carries only link + UUID v4 (§1, 2, 5.1) | ✅ | CardUrlBuilder | — | lib/nfc.ts | U/CardUrlBuilderTest (2); T/GiftCardLifecycleTest::test_manager_creates… |
| W2 | 16-digit random number with Luhn (§5.1) | ✅ | CardNumberGenerator | — | — | U/CardNumberTest |
| W3 | Replace lost card: new ID, old one dead immediately (§5.1) | ✅ | GiftCardService `replace` | /replace | cards/[id] | T/GiftCardLifecycleTest::test_lost_card_replacement…; E 6–7 |
| W4 | Failed/suspicious lookups: 10 per 5 min per user and IP, logged, app-log warning (§5.2) | ✅ | CardScanService `hit`/`log`, config/giftcard.php | /scan | — | T/CardScanTest::test_failed_lookups_are_throttled |
| W5 | Public page 20/min/IP; can be switched off per restaurant (§5.2) | ✅ | AppServiceProvider `public-card`, PublicCardController | /public/cards/{token} | — | T/CardScanTest::test_public_balance_check (rate limit untested) |
| W6 | NTAG21x UID binding, reject + audit warning, can be switched off (§5.3) | ✅ | CardScanService | /scan | — | T/CardScanTest::test_cloned_ntag21x_is_detected_by_uid_binding |
| W7 | One chip cannot be bound to two active cards (§5.3) | ✅ (checked in the service, no unique DB index) | GiftCardService `bindNfcTag` | /cards/{id}/nfc | — | T/CardScanTest::test_one_tag_cannot_be_bound_to_two_active_cards |
| W8 | Optional permanent lock after writing (§5.3) | ✅ | flag only | /cards/{id}/nfc | lib/nfc.ts `makeReadOnly` | none |
| W9 | NTAG 424: decrypt, CMAC, counter strictly greater, atomic (§5.4) | ✅ | Ntag424SunVerifier, CardScanService (compare-and-set update) | /scan | — | T/CardScanTest::test_ntag424_sun_messages_are_verified_and_replays_rejected; HardeningTest::test_rebinding_the_same_secure_chip_keeps_the_replay_counter |
| W10 | Per-chip key derivation (§5.4) | ✅ | Ntag424SunVerifier (HMAC-SHA256 diversification) | — | — | U/Ntag424SunVerifierTest::test_diversified_keys_change_the_mac |
| W11 | Checked against NXP AN12196 vectors (§5.4) | ✅ | — | — | — | U/Ntag424SunVerifierTest::test_an12196_reference_vector; U/AesCmacTest::test_rfc4493_vectors |
| W12 | 424 check works on Android and iPhone (§5.4) | ✅ | ScanCardRequest `toInput` (picc/cmac from URL) | /scan | terminal.tsx `initialToken` secure detection | none end-to-end |
| W13 | Row lock `SELECT … FOR UPDATE`; balance read from the locked row (§6) | ✅ | GiftCardService `lock` | — | — | T/IdempotencyAndConcurrencyTest::test_sequential_redemptions_can_never_overdraw |
| W14 | Idempotency key mandatory for redeem/reload/transfer; replay; conflict rejected (§6) | ✅ | RequireIdempotencyKey, `idempotent`/`replayTransfer` | — | — | T/IdempotencyAndConcurrencyTest (first 3 + scoped); HardeningTest::test_card_creation_is_idempotent_and_validates_the_key |
| W15 | Immutable journal; balance = sum (§6) | ✅ | Immutable trait | — | — | T/GiftCardLifecycleTest::test_ledger_rows_*; `assertLedgerConsistent` |
| W16 | Reversal as counter-booking (§6) | ✅ | GiftCardService `reverse` | — | — | T/GiftCardLifecycleTest::test_redemption_can_be_reversed_once |
| W17 | No negative balances (UNSIGNED), whole cents (§6) | ✅ | migration 000004 `unsignedBigInteger`, `record()` guard | — | — | T/GiftCardLifecycleTest::test_redemption_rejects_invalid_amounts |
| W18 | Fixed lock order for transfers (§6) | ✅ | GiftCardService `transfer` (`strcmp`) | — | — | none |
| W19 | Abuse limits (§6) | ✅ | see 6.1–6.7 | — | — | see 6.x |
| W20 | "Tested with 20 concurrent redemptions, 10 same-key requests, opposing transfers; **the automated tests also cover these cases**" (§1, 6) | ⚠ only a manual test (CHANGELOG 1.1.0, README). No parallel, same-key-race or opposing-transfer test in the repo; `IdempotencyAndConcurrencyTest` is sequential only | — | — | — | none (parallel) |
| W21 | Tenant isolation, 6 layers (§4) | ✅ | ResolveTenant, RestaurantScope, BelongsToRestaurant `guardTenant`, route bindings, RequireTenant, ApiRequest `existsInTenant` | all | — | T/TenantIsolationTest (5); PlatformAdminTest::test_admin_can_act_inside… (TENANT_NOT_RESOLVED) |
| W22 | Foreign-card scan rejected + logged without naming the other restaurant (§4) | ✅ | CardScanService | /scan | — | T/TenantIsolationTest::test_foreign_card_scan_is_rejected_and_logged |
| W23 | `TenantIsolationTest` guards isolation permanently (§4) | ✅ | — | — | — | T/TenantIsolationTest |
| W24 | Password ≥12, mixed case, digit; HIBP k-anonymity in production; bcrypt (§7) | ✅ | AppServiceProvider `configurePasswords` | — | — | none |
| W25 | Login 5/min per e-mail+IP, 30/min per IP (§7) | ✅ | AppServiceProvider `login` limiter | /auth/login, /auth/token | — | T/AuthenticationTest::test_login_is_rate_limited (IP limit untested) |
| W26 | Lock after 10 consecutive failures for 15 min (§7) | ✅ | Services/Auth/CredentialVerifier.php | — | — | T/AuthenticationTest::test_account_is_locked_after_repeated_failures |
| W27 | No account enumeration (login, forgot password) (§7) | ✅ | CredentialVerifier (dummy hash), PasswordController `forgot` | — | — | T/AuthenticationTest::test_invalid_credentials_are_rejected_generically (forgot untested) |
| W28 | Invitations 72 h, reset 60 min, no passwords by e-mail (§7) | ✅ | config/auth.php, PasswordController `reset` | — | — | T/StaffManagementTest::test_invited_staff_can_set_a_password_for_72_hours, ::test_forgot_password_links_expire_after_an_hour |
| W29 | Device auto-registration; session bound to device; revoked device rejected at once (§7) | ✅ | TrackDevice, DeviceService | — | lib/device.ts | T/HardeningTest::test_session_is_pinned…; PermissionsTest::test_revoked_devices_are_blocked |
| W30 | 8 h inactivity unless "Keep me signed in" is **deliberately** chosen (§7) | ⚠ 480 min exists only in `.env*.example` (config default is 120); the login checkbox is **pre-checked** (`remember: true`) | config/session.php | /auth/login | app/(auth)/login/page.tsx | none |
| W31 | Password change signs out other sessions (§7) | ✅ | config/sanctum.php `authenticate_session` | PUT /auth/password | account page | T/AuthenticationTest::test_user_can_change_password (doesn't check other sessions) |
| W32 | Deactivation revokes tokens and ends sessions (§7) | ✅ | UserService `terminateAccess`, ResolveTenant | — | — | T/StaffManagementTest::test_deactivation_revokes_access_and_protects_last_owner |
| W33 | 4 roles; every endpoint needs a permission; waiter only scan+redeem; manager no team/settings/tokens (§8) | ✅ | RoleSlug, routes/api.php `can:*`, Gate::before | all | nav.ts | T/PermissionsTest (4) |
| W34 | No self role change or self-deactivation (§8) | ✅ | UserService | — | — | T/StaffManagementTest::test_owner_cannot_change_own_role, ::test_deactivation_revokes… |
| W35 | Always ≥1 active owner (§8) | ✅ | UserService `activeOwnerCount` | — | — | none that reaches the check (the self-deactivation check fires first) |
| W36 | Platform role never assignable in a restaurant (§8) | ✅ | StoreUserRequest, UpdateUserRequest, UserService `assertAssignable` | — | — | T/StaffManagementTest::test_platform_role_cannot_be_assigned_by_owner |
| W37 | API tokens never exceed their creator (§8) | ✅ | ApiTokenService, User `hasPermission` | — | — | T/SettingsAndApiTokensTest::test_tokens_cannot_exceed_creator_permissions |
| W38 | Vendor access only via Open restaurant; banner; audited with identity (§8) | ✅ | ResolveTenant, AuditLogger | — | acting-banner.tsx | T/PlatformAdminTest::test_admin_can_act_inside_a_restaurant_explicitly |
| W39 | HTTPS only, Let's Encrypt, HTTP/3 (§9) | ✅ | Caddyfile, docker-compose (443/udp) | — | — | none |
| W40 | HSTS 2 years, subdomains, preload (§9) | ✅ | Caddyfile, SecurityHeaders | — | — | none |
| W41 | CSP: web self, API `default-src 'none'`; `frame-ancestors 'none'`; XFO DENY (§9) | ✅ (web allows `'unsafe-inline'` scripts) | SecurityHeaders | — | next.config.ts | none |
| W42 | nosniff, Referrer-Policy, Permissions-Policy, **Cross-Origin-Opener-Policy** (§9) | ⚠ COOP is only on API responses; missing from the Next.js pages | SecurityHeaders | — | next.config.ts | none |
| W43 | Session cookie httpOnly, encrypted, Secure, SameSite=Lax (§9) | ✅ (encrypt/secure come from env; `.env.production.example` sets them) | config/session.php, .env.production.example | — | — | none |
| W44 | CSRF via XSRF-TOKEN double submit (§9) | ✅ | bootstrap/app.php `statefulApi` | /sanctum/csrf-cookie | lib/api/client.ts | none |
| W45 | CORS disabled (§1, 9) | ✅ | config/cors.php (empty) | — | — | T/HardeningTest::test_cors_is_disabled |
| W46 | API `Cache-Control: no-store, private` (§9) | ✅ | SecurityHeaders | — | — | none |
| W47 | Bound parameters, React escaping, e-mail placeholders escaped, CSV formulas neutralised (§9) | ✅ | TemplateRenderer, Support/CsvSanitizer.php | — | — | T/NotificationTest::test_customer_receives_localised_issue_email_with_escaped_content; U/CsvSanitizerTest; T/ReportingTest::test_csv_exports_are_streamed_and_sanitized |
| W48 | Forwarded IPs accepted only from private ranges (§9) | ✅ | bootstrap/app.php `trustProxies`, Caddyfile `trusted_proxies` | — | — | none |
| W49 | GDPR roles / AVV (§10) | n/a | — | — | — | — |
| W50 | Hetzner Germany hosting, sub-processors (§10) | n/a | — | — | — | — |
| W51 | Data minimisation; anonymous sale (§10) | ✅ | StoreGiftCardRequest | — | cards/new | T/GiftCardLifecycleTest (anonymous issue) |
| W52 | No personal data in the audit log (§10) | ✅ | AuditLogger | — | — | T/HardeningTest::test_customer_personal_data_never_enters_the_audit_trail |
| W53 | Anonymisation incl. recipient names and e-mail in the send log; finance data kept (§10) | ✅ | CustomerController `anonymize` | — | — | T/ReportingTest::test_customer_management_and_gdpr_anonymisation (send-log part untested) |
| W54 | Only necessary cookies + random device ID in browser storage (§10) | ✅ | — | — | lib/device.ts | none |
| W55 | Export anytime; deletion 30 days after contract end (§10) | ⚠ same as FO 10.7 | CsvExporter | exports | — | none |
| W56 | Audit: person, device, IP, microsecond time, request ID; immutable; passwords/tokens redacted (§11) | ✅ | AuditLogger, AuditLog (Immutable), migration 000005 `timestamp(…, 6)`, AssignRequestId | /audit-logs | audit page | T/PlatformAdminTest::test_platform_stats_and_audit (immutability of AuditLog untested) |
| W57 | Security warnings red in the audit log + application-log warning (§11) | ✅ | CardScanService `Log::warning`, CredentialVerifier | — | lib/audit.ts `ALERTS`, audit-table.tsx | T/AuthenticationTest::test_account_is_locked… |
| W58 | Card history with time, person, device, balance after (§11) | ⚠ same as FO 1.25 | CardHistoryService | /history | card-history.tsx | T/GiftCardLifecycleTest::test_card_history_merges_ledger_and_events |
| W59 | Every scan logged, including failures (§11) | ✅ | CardScanService `log` → NfcScan | /scan | — | T/TenantIsolationTest::test_foreign_card_scan_is_rejected_and_logged |
| W60 | Token last-use time + IP stored (§11) | ✅ | RecordTokenUsage, Sanctum `last_used_at` | — | — | none |
| W61 | Nightly consistent dump, 14 days local + Storage Box (§12) | ⚠ same as FO 9.12 | infra/scripts/backup.sh | — | — | none |
| W62 | Daily Hetzner server snapshots (§12) | n/a (infra console) | — | — | — | — |
| W63 | No hard deletes; foreign keys (§12) | ✅ | migrations `restrictOnDelete`, SoftDeletes | no DELETE routes | — | T/StaffManagementTest::test_users_are_never_hard_deleted; PlatformAdminTest::test_restaurant_data_is_never_deleted; GiftCardLifecycleTest::test_ledger_rows_cannot_be_deleted |
| W64 | `/up` checks DB + cache (§12) | ✅ | Listeners/CheckApplicationHealth.php | GET /up | — | T/HardeningTest::test_health_check_verifies_database_and_cache |
| W65 | 99.5 % / RPO 24 h / RTO 4 h targets (§12) | n/a | — | — | — | — |
| W66 | Previous version keeps running during rollout; commit tag; rollback (§12) | ⚠ `IMAGE_TAG=<sha>` and rollback exist, but `up -d --no-deps api` recreates the container (not zero-downtime) | infra/scripts/deploy.sh | — | — | none |
| W67 | No offline bookings (§12) | ✅ | — | — | terminal needs the server | none |
| W68 | "113 backend tests (513 assertions) on SQLite + MySQL; suites incl. concurrency" (§13) | ⚠ CI does run both DBs. Actual count is 124 methods / 130 cases (doc is stale); there is no real concurrency suite; last cached run shows 86 errors, 4 failures | .github/workflows/ci.yml | — | — | — |
| W69 | Larastan level 8, TypeScript check, ESLint (§13) | ✅ | phpstan.neon `level: 8`, ci.yml | — | — | CI |
| W70 | `composer audit` + `npm audit` in CI (§13) | ✅ | ci.yml | — | — | CI |
| W71 | Browser acceptance test of day one incl. replacement + rejection (§13) | ✅ (not run in CI) | — | — | — | E 1–8 |
| W72 | axe WCAG 2.1 AA clean on **all main screens, light and dark** (§1, 13) | ⚠ only /dashboard, /cards, /transactions, light theme only | — | — | — | E 9 |
| W73 | Internal security review documented in the changelog (§13) | ✅ | CHANGELOG.md 1.1.0 "Security (pentest findings)" | — | — | — |
| W74 | Images built in GitHub Actions; production deploy needs approval (§13) | ⚠ build ✓ and `environment: production` ✓; the approval rule is a GitHub setting, not visible in the repo | .github/workflows/deploy.yml | — | — | — |
| W75–77 | SSH keys / firewall / auto-updates; secrets in a password manager; incident process (§13–14) | n/a (`.env*` files are gitignored ✓) | — | — | — | — |
| W78 | DB and Redis only on the internal network (§3) | ✅ only Caddy publishes ports | docker-compose.yml | — | — | none |
| W79 | Dashboard and API on the same origin (§3) | ✅ | Caddyfile routing, next.config.ts rewrites | — | — | E (all steps) |

**Whitepaper totals:** 72 rows checked: 62 ✅ · 10 ⚠ · 0 ❌ (86.1 % / 93.1 %). Plus 7 n/a.

---

## C. Roles document (there is no roles file in 02-product; the source is `07-security/access-control-guide.md`)

**Permission matrix:** 31 rows, all ✅. All permissions are defined in `B/Enums/RoleSlug.php::defaultPermissions`, seeded by `database/seeders/RolesAndPermissionsSeeder.php` and enforced by `routes/api.php` `can:*`. The frontend gates are in `F/components/layout/nav.ts` plus the `RequirePermission` wrappers.

| Permission (Admin/Owner/Manager/Waiter) | API | Tests |
|---|---|---|
| dashboard.view (✔✔✔–) | /dashboard/* | T/PermissionsTest::test_waiter_can_only_scan_and_redeem, ::test_manager_manages_cards_but_not_staff_or_settings |
| cards.view (✔✔✔–) | GET /cards, /cards/{id}, /history | same two |
| cards.scan (✔✔✔✔) | POST /scan | ::test_waiter_can_only_scan_and_redeem |
| cards.create (✔✔✔–) | POST /cards | waiter 403 + GiftCardLifecycleTest::test_manager_creates… |
| cards.update (✔✔✔–) | PATCH /cards/{id} | none at role level |
| cards.activate (✔✔✔–) | /activate | manager positive only (test_inactive_cards_must_be_activated_first) |
| cards.redeem (✔✔✔✔) | /redeem | ::test_waiter_can_only_scan_and_redeem |
| cards.reload (✔✔✔–) | /reload | waiter 403 tested |
| cards.block (✔✔✔–) | /block | waiter 403 tested; CardScanTest (actions.block=false) |
| cards.unblock / expire / transfer / replace / write_nfc / export (✔✔✔–), 6 rows | respective routes | manager positive only (GiftCardLifecycleTest, ReportingTest); waiter denial untested |
| transactions.view (✔✔✔–) | /transactions | waiter 403 tested |
| transactions.reverse / export (✔✔✔–), 2 rows | /reverse, /transactions/export | manager positive only |
| customers.view / manage (✔✔✔–), 2 rows | /customers* | ReportingTest (manager) |
| users.view (✔✔––) | /users, /roles | waiter 403, owner 200 (manager denial untested) |
| users.manage (✔✔––) | POST/PATCH /users… | manager 403 tested |
| devices.view (✔✔✔–) | GET /devices | owner only (PermissionsTest::test_revoked_devices_are_blocked) |
| devices.manage (✔✔––) | PATCH /devices, /revoke, /restore | owner positive; manager denial untested |
| settings.manage (✔✔––) | /settings/* | waiter + manager 403, owner 200 |
| api_tokens.manage (✔✔––) | /api-tokens* | manager 403, owner 200 |
| audit.view (✔✔✔–) | /audit-logs | manager 200 |
| platform.restaurants.manage / settings.manage / audit.view (✔–––), 3 rows | /admin/* | ::test_owner_has_full_restaurant_access_but_no_platform_access; PlatformAdminTest |
| Totals 30 / 27 / 22 / 2 | — | matches the enum exactly |

**Other role claims:** 35 rows.

| # | Claim | Status | Code | Tests |
|---|---|---|---|---|
| RC1 | Server checks every endpoint; the UI only hides things | ✅ | routes `can:*`, Gate::before | T/PermissionsTest |
| RC2 | One role per user, fixed and identical for all restaurants | ✅ | `users.role_id`, global `roles` table | none |
| RC3 | Permissions only apply in the user's own restaurant | ✅ | ResolveTenant + scopes | T/TenantIsolationTest |
| RC4 | Ranks 100 / 30 / 20 / 10 | ✅ | RoleSlug `rank` | none |
| RC5 | Platform admin gets restaurant permissions only in Open restaurant | ✅ | RequireTenant | T/PlatformAdminTest::test_admin_can_act_inside… |
| RC6 | Everyone may see own device, edit profile, change password | ✅ | `/devices/current`, `/auth/profile`, `/auth/password` (no permission needed) | T/AuthenticationTest::test_user_can_change_password |
| RC7 | Managing users needs users.manage **and** a higher rank; owners may manage owners | ✅ | User `canManageRole`, UserService `assertManageable` | none directly |
| RC8 | Platform admin manages all roles in every restaurant | ✅ | UserService bypass | none |
| RC9 | No self-promotion | ✅ | UserService `update` | T/StaffManagementTest::test_owner_cannot_change_own_role |
| RC10 | No self-deactivation | ✅ | UserService `deactivate` | T/StaffManagementTest::test_deactivation_revokes… |
| RC11 | Last active owner cannot be deactivated | ✅ | UserService | none effective |
| RC12 | Platform role not assignable; invites only owner/manager/waiter; platform accounts via console only | ✅ | StoreUserRequest, Console/Commands/CreatePlatformAdmin.php | T/StaffManagementTest::test_platform_role_cannot_be_assigned_by_owner |
| RC13 | Other restaurants' staff invisible and unmanageable | ✅ | AppServiceProvider `user` binding | T/TenantIsolationTest::test_customers_and_users_are_isolated |
| RC14 | Users are deactivated, never deleted | ✅ | no DELETE route, SoftDeletes | T/StaffManagementTest::test_users_are_never_hard_deleted |
| RC15 | Statuses Invited / Active / Locked / Deactivated | ✅ | UserResource | E 3 |
| RC16 | Devices auto-registered and named; rename | ✅ | DeviceService | T/PilotReadinessTest::test_new_devices_are_named… |
| RC17 | Session bound to random device ID | ✅ | TrackDevice | T/HardeningTest::test_session_is_pinned… |
| RC18 | Revoke (confirmed) blocks from the next request regardless of session; Restore | ✅ | TrackDevice, EnforceDeviceToken | T/PermissionsTest::test_revoked_devices_are_blocked |
| RC19 | 8 h inactivity; longer only with "Keep me signed in" | ⚠ same as W30 | config/session.php, login page | none |
| RC20 | Password change ends the user's other sessions | ✅ | Sanctum AuthenticateSession | none effective |
| RC21 | Deactivation ends sessions and revokes tokens | ✅ | UserService | T/StaffManagementTest::test_deactivation_revokes… |
| RC22 | Users of a suspended restaurant cannot sign in | ✅ | CredentialVerifier, ResolveTenant | T/AuthenticationTest::test_users_of_suspended_restaurants_cannot_log_in |
| RC23 | Admin without a selected restaurant is rejected | ✅ | RequireTenant | T/PlatformAdminTest::test_admin_can_act_inside… |
| RC24 | Open restaurant shows a closable banner | ✅ | — | F/components/layout/acting-banner.tsx |
| RC25 | Admin actions in that mode are audited with admin ID, device, IP, request ID | ✅ | AuditLogger | none |
| RC26 | Platform actions go into the platform-wide audit | ✅ | RestaurantService, PlatformController | T/PlatformAdminTest::test_platform_stats_and_audit |
| RC27 | Creating tokens needs api_tokens.manage | ✅ | routes | T/PermissionsTest (manager 403) |
| RC28 | Abilities "freely choosable", always a subset of the creator's | ⚠ subset is enforced ✓, but the UI offers only 8 preset abilities (`api-tokens.tsx` `PRESET_ABILITIES`) | ApiTokenService | T/SettingsAndApiTokensTest::test_tokens_cannot_exceed_creator_permissions |
| RC29 | A token acts as its creator | ✅ | Sanctum tokenable | T/SettingsAndApiTokensTest::test_api_token_is_restricted… |
| RC30 | Max. 365 days | ✅ | ApiTokenService | none |
| RC31 | SHA-256 hash, shown once, `gcp_` prefix | ✅ (prefix via env `SANCTUM_TOKEN_PREFIX`; config default is empty) | config/sanctum.php, .env examples | none for the prefix |
| RC32 | Last use (time **and IP**) visible | ⚠ IP is stored but not in ApiTokenResource or the UI | ApiTokenResource, api-tokens.tsx | none |
| RC33 | Revoke anytime; automatic on creator deactivation | ✅ | ApiTokenService, UserService | T/SettingsAndApiTokensTest, T/StaffManagementTest |
| RC34 | Tokens use no cookies, so no CSRF | ✅ | Sanctum bearer | T/SettingsAndApiTokensTest |
| RC35 | Role change takes effect on the next request | ✅ | role loaded per request | none |

**Roles totals:** 66 rows checked: 63 ✅ · 3 ⚠ · 0 ❌ (95.5 % / 97.7 %).

---

## Totals (planned and n/a excluded)

| Document | Rows | ✅ | ⚠ | ❌ | ✅ only | (✅ + 0.5⚠)/total |
|---|---|---|---|---|---|---|
| Feature overview | 120 | 114 | 5 | 1 | 95.0 % | 97.1 % |
| Security whitepaper | 72 | 62 | 10 | 0 | 86.1 % | 93.1 % |
| Roles document | 66 | 63 | 3 | 0 | 95.5 % | 97.7 % |
| **Overall** | **258** | **239** | **18** | **1** | **92.6 %** | **96.1 %** |

Planned per spec: 10 rows. Organisational n/a: 16 rows.

## Findings worth acting on first

1. **Plan gating (❌):** `restaurants.plan` is a free-text label, so Start-plan restaurants currently get NTAG 424, the REST API and API keys.
2. **Test evidence is thinner than the docs say:**
   - There is no automated concurrency, same-key-race or opposing-transfer test, although the whitepaper says the automated tests cover these cases.
   - The axe scan covers 3 screens in light mode only.
   - The test count in the docs is stale, and the cached last run is red.
   - Only one frontend unit test exists (`F/lib/app-links.test.ts`), and it covers native-app deep links, not any spec feature.
3. **Session length:** the 8-hour inactivity limit is effectively off by default, because "Keep me signed in" is pre-checked.
4. **Operations claims not in code:** off-site backup copy, snapshots, zero-downtime rollout, and deletion 30 days after contract end.
5. **Smaller gaps:**
   - COOP header missing on the web pages.
   - API token IP is stored but not shown.
   - Card-history events have no device.
   - E-mail template editor has no preview.
   - In-app QR scanning doesn't work on iOS Safari.
   - Several negative permission cases (for example, manager revoking a device) are untested.

# Part 3 — Definition of Done per feature (owner's 16-feature list)

Criteria: backend · frontend · database · API · validation · permissions · audit logging · unit · integration · E2E tests.
Unit = backend/tests/Unit, frontend *.test.ts, waiter-app/test/core + test/components. Integration = backend/tests/Feature, waiter-app/test/screens + test/app. E2E = e2e/pilot-journey.mjs (step n), e2e/waiter-api.mjs.

| # | Feature | Backend | Frontend | Database | API | Validation | Permissions | Audit | Unit | Integration | E2E |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Authentication | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 2 | Organizations | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 3 | Users | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 4 | Roles | ✅ | ⚠ | ✅ | ⚠ | ⚠ | ✅ | ⚠ | ❌ | ✅ | ⚠ |
| 5 | Gift Cards | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 6 | Transactions | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 7 | NFC | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠ |
| 8 | QR | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠ | ⚠ | ✅ | ❌ |
| 9 | Printing | ⚠ | ✅ | ❌ | ⚠ | ❌ | ⚠ | ❌ | ❌ | ⚠ | ❌ |
| 10 | Customer Portal | ✅ | ✅ | ✅ | ✅ | ⚠ | ⚠ | ❌ | ⚠ | ✅ | ❌ |
| 11 | Waiter App | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 12 | Dashboard | ✅ | ✅ | ✅ | ✅ | ⚠ | ✅ | ❌ | ❌ | ✅ | ⚠ |
| 13 | Reports | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| 14 | Platform Admin | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 15 | Settings | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| 16 | Final polishing | ✅ | ✅ | ⚠ | ✅ | ❌ | ⚠ | ❌ | ❌ | ✅ | ⚠ |

Totals: ✅ 118 · ⚠ 20 · ❌ 22 of 160 cells → (118 + 10)/160 = **80.0 %**. Features meeting the full DoD: **5 Gift Cards, 11 Waiter App**.

## Evidence

**1 Authentication** — Backend: AuthController, PasswordController, Services/Auth/CredentialVerifier.php, Services/Auth/DeviceTokenService.php · Frontend: app/(auth)/login, forgot-password, reset-password · DB: users, sessions, password_reset_tokens, personal_access_tokens (+ device_id, migration 2026_09_27_000001) · API: auth/login, auth/token, auth/forgot-password, auth/reset-password, auth/me, auth/logout, auth/profile, auth/password · Validation: LoginRequest, DeviceTokenRequest, ForgotPasswordRequest, ResetPasswordRequest, ChangePasswordRequest, UpdateProfileRequest · Permissions: auth:sanctum, device.token, throttle:login, throttle:password-reset · Audit: auth.login, auth.logout, auth.failed, auth.locked, auth.password_reset, auth.device_token_issued, user.profile_updated · Unit: none · Integration: AuthenticationTest (8), WaiterAppTokenTest · E2E: pilot steps 1–3, 5; waiter-api.mjs.

**2 Organizations** — RestaurantService, Admin/RestaurantController, Support/Tenancy · admin/page.tsx, admin/restaurants/[id], settings · restaurants, restaurant_settings · admin/restaurants (list/create/show/update/suspend/reactivate), settings/restaurant · StoreRestaurantRequest, UpdateRestaurantRequest, ReasonRequest · can:platform.restaurants.manage, tenant, tenant.required · restaurant.created/updated/suspended/reactivated · Unit: none · PlatformAdminTest, TenantIsolationTest · E2E step 1.

**3 Users** — UserService, UserController, Notifications/StaffInvitation · (app)/team, (app)/account · users · users CRUD + deactivate/activate/password-reset · StoreUserRequest, UpdateUserRequest · can:users.view, can:users.manage + rank checks · user.created/updated/deactivated/activated/password_changed/invitation_resent/password_reset_sent · Unit: none · StaffManagementTest (7) · E2E steps 2, 3, 5.

**4 Roles** — Models/Role, Enums/RoleSlug, RolesAndPermissionsSeeder, RoleController · ⚠ Frontend only a role picker in team/page.tsx:61 · roles, permissions, permission_role · ⚠ API read-only GET roles · ⚠ validation only the role rule in StoreUserRequest/UpdateUserRequest · can:users.view, canManageRole · ⚠ no role.* audit action (captured in user.created/updated) · Unit: none · PermissionsTest (4), StaffManagementTest role tests · ⚠ E2E indirect only.

**5 Gift Cards** — GiftCardService, CardNumberGenerator, CardHistoryService · cards, cards/new, cards/[id] · gift_cards, customers · cards CRUD + activate/block/unblock/expire/replace/transfer/history · StoreGiftCardRequest, UpdateGiftCardRequest, ReplaceCardRequest, TransferBalanceRequest, CardIndexRequest · can:cards.* · gift_card.issued/activated/blocked/unblocked/expired/updated/replaced/balance_transferred · Unit/CardNumberTest · GiftCardLifecycleTest (18), HardeningTest · E2E steps 4, 6, 7.

**6 Transactions** — GiftCardService redeem/reload/reverse, TransactionController · (app)/transactions · gift_card_transactions · cards/{card}/redeem, /reload, transactions, transactions/{transaction}/reverse · MoneyOperationRequest, TransactionIndexRequest, ReasonRequest · can:cards.redeem, cards.reload, transactions.view, transactions.reverse · gift_card.redeemed, gift_card.reloaded, transaction.reversed · Unit: none · IdempotencyAndConcurrencyTest (6), GiftCardLifecycleTest, ReportingTest · E2E steps 5, 6, 8; waiter-api.mjs.

**7 NFC** — Services/Nfc/Ntag424SunVerifier, AesCmac, CardScanService, GenerateNfcKeys · components/cards/nfc-writer.tsx, lib/nfc, web terminal, Flutter core/platform/nfc_service.dart · gift_cards.nfc_*, nfc_scans · GET/POST cards/{card}/nfc, POST scan · BindNfcTagRequest, ScanCardRequest · can:cards.write_nfc, can:cards.scan · gift_card.nfc_written/nfc_signature_invalid/nfc_uid_mismatch/nfc_replay/foreign_scan · Unit/AesCmacTest, Unit/Ntag424SunVerifierTest · CardScanTest, HardeningTest, s05_ready_test · ⚠ E2E never reads a real tag.

**8 QR** — QrCodeService, ScanMethod::Qr · components/cards/card-qr.tsx, components/waiter/qr-scanner, Flutter s12_qr_scan.dart · gift_cards.public_token, nfc_scans.method · GET cards/{card}/qr, POST scan method=qr · ScanCardRequest · can:cards.write_nfc (on /qr), can:cards.scan · ⚠ QR rendering not audited; scans only in nfc_scans · ⚠ Unit only CardUrlBuilderTest · GiftCardLifecycleTest::test_qr_code_is_rendered_as_svg, s12_qr_scan_test · E2E: none.

**9 Printing** — ⚠ no backend of its own · app/print/cards/[id]/page.tsx · ❌ nothing stored · ⚠ reuses GET cards/{id}, /qr · ❌ no validation · ⚠ AuthGuard + inherited gates · ❌ no audit · ❌ no unit · ⚠ only indirect QR SVG test · ❌ no E2E.

**10 Customer Portal** — PublicCardController · app/c/[token]/page.tsx · gift_cards.public_token, restaurant_settings.public_balance_check · GET public/cards/{token} (throttle:public-card) · ⚠ route regex, no FormRequest · ⚠ public by design (throttle, active restaurant, setting) · ❌ no audit · ⚠ CardUrlBuilderTest only · CardScanTest::test_public_balance_check, HardeningTest::test_cards_of_closed_restaurants_are_not_disclosed · ❌ no E2E.

**11 Waiter App** — DeviceTokenService, AppConfigController, DeviceService · app/waiter/page.tsx + components/waiter/terminal.tsx; Flutter waiter-app/lib (142 files) · devices; migrations 2026_09_27_000001, 2026_09_27_000002 · app/config, auth/token, devices/current, scan, redeem · DeviceTokenRequest, ScanCardRequest, MoneyOperationRequest · token abilities, can:cards.scan, can:cards.redeem, device, device.token · auth.device_token_issued, device.registered/updated/revoked/restored · Unit: waiter-app/test/core/** (22 files), test/components/** (10), frontend app-links.test.ts · WaiterAppTokenTest (12), WaiterAppConfigTest (4), waiter-app/test/screens/** (15), test/app/redeem_journey_test.dart · E2E pilot steps 5, 7 (web waiter), waiter-api.mjs (11 steps). Native screens never on a device.

**12 Dashboard** — DashboardService, DashboardController · (app)/dashboard · aggregates · dashboard/stats, /charts, /activity · ⚠ inline clamping only · can:dashboard.view · ❌ no audit (read-only) · ❌ no unit · ReportingTest::test_dashboard_statistics, PilotReadinessTest · ⚠ E2E steps 2, 9 only.

**13 Reports** — Services/Exports/CsvExporter, Support/CsvSanitizer · Export CSV on cards, transactions · existing tables · cards/export, transactions/export · CardIndexRequest, TransactionIndexRequest · can:cards.export, can:transactions.export · ❌ exports not audit-logged · Unit/CsvSanitizerTest · ReportingTest, HardeningTest, PilotReadinessTest · E2E step 8.

**14 Platform Admin** — Admin/PlatformController, RestaurantController, CreatePlatformAdmin · admin, admin/audit, admin/settings, admin/restaurants/[id] · system_settings, restaurants · admin/stats, admin/restaurants*, admin/audit-logs, admin/system-settings · StoreRestaurantRequest, UpdateSystemSettingsRequest · can:platform.restaurants.manage, platform.audit.view, platform.settings.manage · restaurant.*, system_setting.updated · Unit: none · PlatformAdminTest (5), WaiterAppConfigTest · E2E step 1.

**15 Settings** — SettingsController, NotificationTemplateController, ApiTokenController, ApiTokenService · (app)/settings, (app)/devices, (app)/audit · restaurant_settings, notification_templates · settings/*, api-tokens* · UpdateRestaurantRequest, UpdateCardSettingsRequest, UpdateNotificationTemplateRequest, StoreApiTokenRequest, UpdateDeviceRequest · can:settings.manage, can:api_tokens.manage · restaurant.settings_updated, notification_template.updated, api_token.created/revoked · Unit: none · SettingsAndApiTokensTest (4) · ❌ no E2E step opens /settings.

**16 Final polishing** — /up health route, CheckApplicationHealth, AlertOnQueueBacklog · error.tsx, not-found.tsx, CI lint/typecheck/build · ⚠ DB only via healthchecks / MySQL CI job · /up · ❌ validation n/a · ⚠ docs/SECURITY.md, HardeningTest::test_cors_is_disabled · ❌ audit n/a · ❌ no unit · HardeningTest::test_health_check_verifies_database_and_cache, QueueBacklogAlertTest · ⚠ E2E step 9 only; CI never runs the e2e scripts.

## Run evidence for E2E scripts
- No result artifacts (no Playwright report, not run in CI).
- backend/storage/logs/laravel-2026-09-26.log contains invitation mails of four pilot-journey runs (owner-mui4nxja, mui4ottl, mui4prig, mui4wxgc @pilot.test) — proves steps 1–3 ran; no pass/fail record.
- waiter-api.mjs: its 11-step pass on 2026-09-26 was only visible in the session terminal; no stored artifact.
- backend/.phpunit.result.cache still lists 90 "defects" entries although the run that last wrote it (2026-09-27 09:30, this audit) finished with 130 passed — see Part 5 for the terminal output.

# Part 4 — Implementation percentage

| Scope | Rows | ✅ | ⚠ | ❌ | ✅ only | (✅ + 0.5×⚠)/total |
|---|---|---|---|---|---|---|
| Part 1 Native waiter app spec | 223 | 173 | 31 | 19 | 77.6 % | 84.5 % |
| Part 2 Web platform product spec | 258 | 239 | 18 | 1 | 92.6 % | 96.1 % |
| Part 3 Definition of Done (16 features × 10) | 160 | 118 | 20 | 22 | 73.8 % | 80.0 % |
| **All rows combined** | **641** | **530** | **69** | **42** | **82.7 %** | **88.1 %** |

# Part 5 — Terminal output

## backend: php artisan test
```

   PASS  Tests\Unit\AesCmacTest
  ✓ rfc4493 vectors with data set "empty"                                0.07s  
  ✓ rfc4493 vectors with data set "16 bytes"
  ✓ rfc4493 vectors with data set "40 bytes"
  ✓ rfc4493 vectors with data set "64 bytes"

   PASS  Tests\Unit\CardNumberTest
  ✓ it validates luhn numbers with data set "valid visa-like"            0.02s  
  ✓ it validates luhn numbers with data set "classic luhn example"
  ✓ it validates luhn numbers with data set "one digit off"
  ✓ it validates luhn numbers with data set "too short"
  ✓ check digit is computed
  ✓ formatting and masking

   PASS  Tests\Unit\CardUrlBuilderTest
  ✓ extracts token from urls and raw values                              0.01s  
  ✓ rejects non v4 or garbage

   PASS  Tests\Unit\CsvSanitizerTest
  ✓ formula injection is neutralised
  ✓ numbers and plain values are untouched

   PASS  Tests\Unit\Ntag424SunVerifierTest
  ✓ an12196 reference vector
  ✓ non zero keys and max counter
  ✓ counter is little endian
  ✓ corrupted mac is rejected
  ✓ mac of other counter is rejected
  ✓ invalid picc tag is rejected
  ✓ missing keys are reported
  ✓ diversified keys change the mac

   PASS  Tests\Feature\AuthenticationTest
  ✓ staff can log in and receives profile with permissions               2.50s  
  ✓ invalid credentials are rejected generically                         0.28s  
  ✓ account is locked after repeated failures                            0.05s  
  ✓ login is rate limited                                                1.22s  
  ✓ deactivated users cannot log in                                      0.03s  
  ✓ users of suspended restaurants cannot log in                         0.03s  
  ✓ guests receive 401 on protected routes                               0.21s  
  ✓ user can change password                                             0.29s  

   PASS  Tests\Feature\CardScanTest
  ✓ waiter scans nfc url and sees minimal card view                      0.05s  
  ✓ manual card number lookup                                            0.04s  
  ✓ failed lookups are throttled                                         0.05s  
  ✓ cloned ntag21x is detected by uid binding                            0.04s  
  ✓ one tag cannot be bound to two active cards                          0.04s  
  ✓ ntag424 sun messages are verified and replays rejected               0.06s  
  ✓ public balance check                                                 0.04s  

   PASS  Tests\Feature\GiftCardLifecycleTest
  ✓ manager creates a card with ledger entry and nfc payload             0.05s  
  ✓ card value limits are enforced                                       0.03s  
  ✓ default expiration uses restaurant setting                           0.03s  
  ✓ partial and full redemption                                          0.05s  
  ✓ redemption rejects invalid amounts                                   0.04s  
  ✓ full redemption only setting                                         0.03s  
  ✓ blocked and expired cards cannot be redeemed                         0.04s  
  ✓ inactive cards must be activated first                               0.03s  
  ✓ reload revives redeemed cards and respects limits                    0.04s  
  ✓ redemption can be reversed once                                      0.04s  
  ✓ balance transfer between cards                                       0.06s  
  ✓ lost card replacement moves balance to new card                      0.05s  
  ✓ manual expiration writes off balance                                 0.03s  
  ✓ scheduled expiration command                                         0.03s  
  ✓ card history merges ledger and events                                0.05s  
  ✓ ledger rows are immutable                                            0.03s  
  ✓ ledger rows cannot be deleted                                        0.03s  
  ✓ qr code is rendered as svg                                           0.06s  

   PASS  Tests\Feature\HardeningTest
  ✓ expiry is the end of the day in the restaurant timezone              0.05s  
  ✓ explicit null expiry means no expiry and missing means default       0.04s  
  ✓ replacing an inactive card keeps it inactive                         0.04s  
  ✓ replacing an empty card writes no zero ledger entries                0.04s  
  ✓ inactive cards cannot transfer value                                 0.04s  
  ✓ rebinding the same secure chip keeps the replay counter              0.04s  
  ✓ card creation is idempotent and validates the key                    0.05s  
  ✓ session is pinned to the device it started on                        0.03s  
  ✓ cards of closed restaurants are not disclosed                        0.03s  
  ✓ each card event sends exactly one email                              0.07s  
  ✓ customer personal data never enters the audit trail                  0.05s  
  ✓ invalid chip serial numbers are rejected                             0.04s  
  ✓ health check verifies database and cache                             0.09s  
  ✓ cors is disabled                                                     0.03s  
  ✓ exports use decimal comma for german locales                         0.04s  

   PASS  Tests\Feature\IdempotencyAndConcurrencyTest
  ✓ retried redemption is not charged twice                              0.05s  
  ✓ reusing a key for a different request is rejected                    0.04s  
  ✓ money endpoints require an idempotency key                           0.05s  
  ✓ sequential redemptions can never overdraw                            0.04s  
  ✓ idempotency is scoped per card and type                              0.04s  
  ✓ velocity limit stops rapid repeated redemptions                      0.05s  

   PASS  Tests\Feature\NotificationTest
  ✓ customer receives localised issue email with escaped content         0.04s  
  ✓ no email when disabled                                               0.04s  
  ✓ expiring reminders are sent once                                     0.04s  

   PASS  Tests\Feature\PermissionsTest
  ✓ waiter can only scan and redeem                                      0.06s  
  ✓ manager manages cards but not staff or settings                      0.30s  
  ✓ owner has full restaurant access but no platform access              0.04s  
  ✓ revoked devices are blocked                                          0.05s  

   PASS  Tests\Feature\PilotReadinessTest
  ✓ dashboard reports the number of cards carrying the liability         0.06s  
  ✓ new devices are named after hardware and browser not the person      0.03s  
  ✓ replacement ledger notes use the printed card number format          0.05s  
  ✓ exports use readable status and type names                           0.07s  

   PASS  Tests\Feature\PlatformAdminTest
  ✓ admin onboards a restaurant with owner invitation                    0.14s  
  ✓ admin lists and suspends restaurants                                 0.04s  
  ✓ admin can act inside a restaurant explicitly                         0.05s  
  ✓ platform stats and audit                                             0.04s  
  ✓ restaurant data is never deleted                                     0.03s  

   PASS  Tests\Feature\QueueBacklogAlertTest
  ✓ a queue backlog mails the ops address once per half hour             0.04s  

   PASS  Tests\Feature\ReportingTest
  ✓ dashboard statistics                                                 0.05s  
  ✓ card search filters and sorting                                      0.07s  
  ✓ csv exports are streamed and sanitized                               0.04s  
  ✓ customer management and gdpr anonymisation                           0.05s  
  ✓ transactions listing and filters                                     0.05s  

   PASS  Tests\Feature\SettingsAndApiTokensTest
  ✓ owner updates card settings with validation                          0.04s  
  ✓ notification template override                                       0.04s  
  ✓ api token is restricted to its abilities and can be revoked          0.07s  
  ✓ tokens cannot exceed creator permissions                             0.03s  

   PASS  Tests\Feature\StaffManagementTest
  ✓ owner invites a waiter                                               0.04s  
  ✓ platform role cannot be assigned by owner                            0.03s  
  ✓ deactivation revokes access and protects last owner                  0.04s  
  ✓ users are never hard deleted                                         0.03s  
  ✓ owner cannot change own role                                         0.03s  
  ✓ invited staff can set a password for 72 hours                        0.05s  
  ✓ forgot password links expire after an hour                           0.23s  

   PASS  Tests\Feature\TenantIsolationTest
  ✓ cards of other restaurants are invisible                             0.06s  
  ✓ foreign card scan is rejected and logged                             0.04s  
  ✓ transfer to foreign card is impossible                               0.04s  
  ✓ customers and users are isolated                                     0.04s  
  ✓ cards cannot be looked up by number across restaurants               0.04s  

   PASS  Tests\Feature\WaiterAppConfigTest
  ✓ config is public and cacheable                                       0.04s  
  ✓ update is required below the minimum version of the platform         0.03s  
  ✓ maintenance notice is passed through                                 0.03s  
  ✓ platform admin sets minimum versions with validation and audit       0.03s  

   PASS  Tests\Feature\WaiterAppTokenTest
  ✓ waiter signs in and gets a device bound token                        0.04s  
  ✓ token can scan and redeem with idempotency                           0.06s  
  ✓ token is limited to the waiter endpoints even for owners             0.06s  
  ✓ token is rejected from another device                                0.04s  
  ✓ revoking the device stops the token and restoring allows it again    0.06s  
  ✓ signing in again replaces the previous token                         0.05s  
  ✓ logout revokes the token                                             0.05s  
  ✓ expiry rolls forward while the phone is used and expired tokens fai… 0.04s  
  ✓ sign in rules match the web login                                    0.05s  
  ✓ platform admins and suspended restaurants get no token               0.04s  
  ✓ deactivated accounts get a dedicated code                            0.05s  
  ✓ device tokens are not listed as integration tokens                   0.04s  

  Tests:    130 passed (623 assertions)
  Duration: 11.93s

```

## frontend: npm test
```

> giftcard-pro-web@1.0.0 test
> node --test --experimental-strip-types 'src/**/*.test.ts'

TAP version 13
# (node:3076) [MODULE_TYPELESS_PACKAGE_JSON] Warning: Module type of file:///home/claude/giftcard-pro/frontend/src/lib/app-links.test.ts is not specified and it doesn't parse as CommonJS.
# Reparsing as ES module because module syntax was detected. This incurs a performance overhead.
# To eliminate this warning, add "type": "module" to /home/claude/giftcard-pro/frontend/package.json.
# (Use `node --trace-warnings ...` to show where the warning was created)
# Subtest: apple-app-site-association lists valid app IDs for card links only
ok 1 - apple-app-site-association lists valid app IDs for card links only
  ---
  duration_ms: 1.598818
  type: 'test'
  ...
# Subtest: assetlinks.json needs a package name and a SHA-256 fingerprint
ok 2 - assetlinks.json needs a package name and a SHA-256 fingerprint
  ---
  duration_ms: 0.279298
  type: 'test'
  ...
1..2
# tests 2
# suites 0
# pass 2
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 140.47065
```

## waiter-app: flutter test -r expanded (complete)
```
   Woah! You appear to be trying to run flutter as root.
   We strongly recommend running the flutter tool without superuser privileges.
  /
📎
Resolving dependencies...
Downloading packages...
  code_assets 1.2.1 (2.1.0 available)
  dbus 0.7.15 (0.8.0 available)
  hooks 2.0.2 (2.2.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  meta 1.18.3 (1.19.0 available)
  nm 0.5.0 (0.6.0 available)
  objective_c 9.5.0 (9.6.0 available)
  record_use 0.6.0 (1.1.1 available)
  test_api 0.7.12 (0.7.14 available)
  vector_math 2.4.0 (2.4.3 available)
Got dependencies!
10 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart
00:00 +0: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: (setUpAll)
00:00 +0: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: Snackbar shows, then auto-dismisses after 4 s (Brightness.light)
00:00 +1: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: Snackbar shows, then auto-dismisses after 4 s (Brightness.dark)
00:01 +2: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: Snackbar one action; activating it dismisses; 56-pt target
00:01 +3: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: Snackbar timer pauses while paused and with a screen reader
00:01 +4: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: Snackbar a new snackbar replaces the current one
00:01 +5: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: Dialog sign-out: danger on top, safe below; confirm (Brightness.light)
00:01 +6: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: Dialog sign-out: danger on top, safe below; confirm (Brightness.dark)
00:01 +7: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: Dialog scrim tap = the safe action
00:01 +8: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: Dialog opening a dialog dismisses the snackbar
00:01 +9: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: BottomSheet content-fit sheet: grabber, header, ✕ closes (Brightness.light)
00:01 +10: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: BottomSheet content-fit sheet: grabber, header, ✕ closes (Brightness.dark)
00:02 +11: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: BottomSheet drag down dismisses; a locked sheet stays
00:02 +12: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: BottomSheet scroll sheet opens at the medium detent
00:02 +13: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: WaiterBanner offline banner: full width, ≥ 48 pt (Brightness.light)
00:02 +14: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: WaiterBanner offline banner: full width, ≥ 48 pt (Brightness.dark)
00:02 +15: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: WaiterBanner with an action it is ≥ 56 pt
00:02 +16: /home/claude/giftcard-pro/waiter-app/test/components/overlays_test.dart: (tearDownAll)
00:02 +16: loading /home/claude/giftcard-pro/waiter-app/test/components/hold_button_test.dart
00:03 +16: /home/claude/giftcard-pro/waiter-app/test/components/hold_button_test.dart: (setUpAll)
00:03 +16: /home/claude/giftcard-pro/waiter-app/test/components/hold_button_test.dart: renders in Brightness.light at 64 pt and full width
00:03 +17: /home/claude/giftcard-pro/waiter-app/test/components/hold_button_test.dart: renders in Brightness.dark at 64 pt and full width
00:03 +18: /home/claude/giftcard-pro/waiter-app/test/components/hold_button_test.dart: 599 ms does not commit, 600 ms commits with three ticks
00:03 +19: /home/claude/giftcard-pro/waiter-app/test/components/hold_button_test.dart: release before 600 ms cancels and drains the ring
00:04 +20: /home/claude/giftcard-pro/waiter-app/test/components/hold_button_test.dart: sliding more than 12 pt outside cancels
00:04 +21: /home/claude/giftcard-pro/waiter-app/test/components/hold_button_test.dart: a quick tap teaches: caption announced, no commit
00:04 +22: /home/claude/giftcard-pro/waiter-app/test/components/hold_button_test.dart: accessible paths: arm then confirm; custom action; long press
00:04 +23: /home/claude/giftcard-pro/waiter-app/test/components/hold_button_test.dart: Reduce Motion keeps the ring (progress indicator)
00:04 +24: /home/claude/giftcard-pro/waiter-app/test/components/hold_button_test.dart: disabled: no commit, hint is the reason
00:04 +25: /home/claude/giftcard-pro/waiter-app/test/components/hold_button_test.dart: (tearDownAll)
00:04 +25: loading /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart
00:04 +25: /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart: (setUpAll)
00:05 +25: /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart: PrimaryButton large is 64 pt and full width in Brightness.light
00:05 +26: /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart: PrimaryButton large is 64 pt and full width in Brightness.dark
00:05 +27: /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart: PrimaryButton large is 56 pt at compact height; regular is 56 pt
00:05 +28: /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart: PrimaryButton activates on touch-up inside; a move out cancels
00:05 +29: /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart: PrimaryButton semantics: label, disabled hint
00:05 +30: /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart: PrimaryButton loading: no spinner before 150 ms, spinner after
00:05 +31: /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart: PrimaryButton an amount label breaks at " · " when it does not fit
00:05 +32: /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart: Secondary, Tertiary, Danger meet the 56-pt target in Brightness.light
00:05 +33: /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart: Secondary, Tertiary, Danger meet the 56-pt target in Brightness.dark
00:05 +34: /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart: Secondary, Tertiary, Danger TertiaryButton can be a link
00:05 +35: /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart: WaiterIconButton 56 target, toggle semantics, icon swap
00:06 +36: /home/claude/giftcard-pro/waiter-app/test/components/buttons_test.dart: (tearDownAll)
00:06 +36: loading /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart
00:06 +36: /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart: (setUpAll)
00:06 +36: /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart: ID-1 ratio, capped at 220 pt, in Brightness.light
00:07 +37: /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart: ID-1 ratio, capped at 220 pt, in Brightness.dark
00:07 +38: /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart: compact strip is 88 pt
00:07 +39: /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart: density: compact at compact height or 130 % text
00:07 +40: /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart: one accessibility element with spoken balance and status
00:07 +41: /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart: active card shows no badge; zero balance shows "Used up"
00:07 +42: /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart: contrast fallback: a mid grey falls back to brand ink
00:07 +43: /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart: good brand colour does not fall back
00:07 +44: /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart: skeleton: brand fill, busy label, then content cross-fade
00:07 +45: /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart: arrival springs in; Reduce Motion only fades
00:07 +46: /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart: swapping cards cross-fades over 300 ms
00:07 +47: /home/claude/giftcard-pro/waiter-app/test/components/balance_card_test.dart: (tearDownAll)
00:07 +47: loading /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart
00:08 +47: /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart: (setUpAll)
00:08 +47: /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart: WaiterTextField 56-pt container, border.control at rest (Brightness.light)
00:09 +48: /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart: WaiterTextField 56-pt container, border.control at rest (Brightness.dark)
00:09 +49: /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart: WaiterTextField focus ring on focus, danger on error
00:09 +50: /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart: WaiterTextField error shake: 240 ms, ±6 pt; none under Reduce Motion
00:09 +51: /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart: WaiterTextField password toggle: 56 target, toggle semantics
00:09 +52: /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart: CardNumberField 64 pt, groups of four, empty cells "·" (Brightness.light)
00:09 +53: /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart: CardNumberField 64 pt, groups of four, empty cells "·" (Brightness.dark)
00:09 +54: /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart: CardNumberField reads in groups; label and hint
00:09 +55: /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart: CardNumberField fits a 320-pt phone at 200 % without overflow
00:09 +56: /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart: CardNumberField error border and message
00:10 +57: /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart: QuickAmountChip 40 visual / 56 target, spoken label, haptic.select
00:10 +58: /home/claude/giftcard-pro/waiter-app/test/components/fields_test.dart: (tearDownAll)
00:10 +58: loading /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart
00:10 +58: /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart: (setUpAll)
00:10 +58: /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart: 3 × 4 keys at 72 pt in Brightness.light
00:11 +59: /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart: 3 × 4 keys at 72 pt in Brightness.dark
00:11 +60: /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart: keys are 64 pt at compact height
00:11 +61: /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart: input registers on touch-down with haptic.key
00:11 +62: /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart: leading zero is ignored silently
00:11 +63: /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart: 8th digit is rejected with haptic.warning
00:11 +64: /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart: long-press ⌫ for 500 ms clears with haptic.select
00:11 +65: /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart: a short ⌫ tap deletes one digit only
00:11 +66: /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart: disabled keypad ignores input
00:11 +67: /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart: hardware keyboard: digits, Backspace, Ctrl + Backspace
00:12 +68: /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart: card-number variant has an empty bottom-left cell
00:12 +69: /home/claude/giftcard-pro/waiter-app/test/components/keypad_test.dart: (tearDownAll)
00:12 +69: loading /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart
00:12 +69: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: (setUpAll)
00:12 +69: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: WaiterTextField an error toggling on/off/on within 160 ms is fine
00:13 +70: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: WaiterTextField read-only: not editable, keeps the resting look
00:13 +71: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: PrimaryButton loading label beside the spinner after 150 ms
00:13 +72: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: StatusBanner ticking text is not re-announced; a tone change is
00:13 +73: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: WaiterBanner dismiss ✕ and a 2-line cap with the full text in a11y
00:14 +74: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: Snackbar own duration; onDismissed on timeout
00:14 +75: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: Snackbar the action does not call onDismissed
00:14 +76: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: TopBar.task: ✕ stays, dimmed and disabled while locked
00:14 +77: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: AmountDisplay balance changed: no shake and no warning haptic
00:14 +78: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: AmountDisplay message and chip are reachable by screen readers
00:14 +79: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: BalanceCard sizing ratio kept inside a lower max height, centred
00:14 +80: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: BalanceCard sizing tablet cap 277 pt
00:14 +81: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: BalanceCard sizing no keypad: full card even at compact window height
00:14 +82: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: Keypad: 80-pt keys in the tall tablet two-pane
00:14 +83: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: ProblemScreen throttled: ill_wait, ring below, caption
00:14 +84: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: Avatar 72 pt
00:14 +85: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: showWaiterScrollSheet opens at the large detent on compact height
00:14 +86: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: showWaiterScrollSheet custom scrim label
00:14 +87: /home/claude/giftcard-pro/waiter-app/test/components/follow_up_test.dart: (tearDownAll)
00:14 +87: loading /home/claude/giftcard-pro/waiter-app/test/components/amount_display_test.dart
00:15 +87: /home/claude/giftcard-pro/waiter-app/test/components/amount_display_test.dart: (setUpAll)
00:15 +87: /home/claude/giftcard-pro/waiter-app/test/components/amount_display_test.dart: placeholder € 0,00 in fg.tertiary (Brightness.light)
00:16 +88: /home/claude/giftcard-pro/waiter-app/test/components/amount_display_test.dart: placeholder € 0,00 in fg.tertiary (Brightness.dark)
00:16 +89: /home/claude/giftcard-pro/waiter-app/test/components/amount_display_test.dart: POS entry: digits shift in from the right
00:16 +90: /home/claude/giftcard-pro/waiter-app/test/components/amount_display_test.dart: semantics: "Amount {spoken}", debounced 400 ms
00:16 +91: /home/claude/giftcard-pro/waiter-app/test/components/amount_display_test.dart: never truncates € 99.999,99 at 200 % on a 320-pt phone
00:16 +92: /home/claude/giftcard-pro/waiter-app/test/components/amount_display_test.dart: over balance: danger colour, message, warning, shake
00:16 +93: /home/claude/giftcard-pro/waiter-app/test/components/amount_display_test.dart: limit nudge is ±3 pt; none under Reduce Motion
00:16 +94: /home/claude/giftcard-pro/waiter-app/test/components/amount_display_test.dart: Reduce Motion: value replaced by a cross-fade
00:16 +95: /home/claude/giftcard-pro/waiter-app/test/components/amount_display_test.dart: fixed: full balance in fg.primary with a caption
00:16 +96: /home/claude/giftcard-pro/waiter-app/test/components/amount_display_test.dart: de-DE puts the symbol after the number
00:16 +97: /home/claude/giftcard-pro/waiter-app/test/components/amount_display_test.dart: (tearDownAll)
00:16 +97: loading /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart
00:17 +97: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: (setUpAll)
00:17 +97: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: StatusBadge 6 statuses, icon + text, 24 pt (Brightness.light)
00:18 +98: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: StatusBadge 6 statuses, icon + text, 24 pt (Brightness.dark)
00:18 +99: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: StatusBadge high contrast adds a border in the text colour
00:18 +100: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: StatusBanner tones render with title, body and action (Brightness.light)
00:18 +101: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: StatusBanner tones render with title, body and action (Brightness.dark)
00:18 +102: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: StatusBanner danger is announced assertively with haptic on appear
00:18 +103: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: StatusBanner uncertain: spinner instead of the icon
00:18 +104: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: indicators Spinner 20/32 and ProgressRing 28/48 (Brightness.light)
00:18 +105: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: indicators Spinner 20/32 and ProgressRing 28/48 (Brightness.dark)
00:18 +106: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: indicators countdown ticks down, fades and announces at 0
00:18 +107: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: indicators Skeleton: static at 60 % under Reduce Motion
00:18 +108: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: indicators SkeletonSwitcher appears after 150 ms, stays ≥ 240 ms
00:18 +109: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: NfcScanAnimation 176 × 120 canvas, hidden from semantics (Brightness.light)
00:18 +110: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: NfcScanAnimation 176 × 120 canvas, hidden from semantics (Brightness.dark)
00:18 +111: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: NfcScanAnimation states retarget without errors; Reduce Motion is static
00:19 +112: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: SuccessMark 96 pt; success haptic + sound at t = 0
00:19 +113: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: SuccessMark Reduce Motion: fades in over 160 ms
00:19 +114: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: CountdownHairline 2 pt, full width, finishes after 4 s (Brightness.light)
00:19 +115: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: CountdownHairline 2 pt, full width, finishes after 4 s (Brightness.dark)
00:19 +116: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: CountdownHairline pauses while paused, then resumes
00:19 +117: /home/claude/giftcard-pro/waiter-app/test/components/display_test.dart: (tearDownAll)
00:19 +117: loading /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart
00:19 +117: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: (setUpAll)
00:19 +117: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: ProblemScreen title header, actions, error feedback (Brightness.light)
00:20 +118: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: ProblemScreen title header, actions, error feedback (Brightness.dark)
00:20 +119: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: ProblemScreen long-press on the code copies the request id
00:20 +120: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: ProblemScreen verification uses the calm warning tone
00:20 +121: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: ProblemScreen countdown visual; no stagger under Reduce Motion
00:20 +122: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: TopBar and Avatar home: 56 pt, avatar, two 56-pt buttons (Brightness.light)
00:21 +123: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: TopBar and Avatar home: 56 pt, avatar, two 56-pt buttons (Brightness.dark)
00:21 +124: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: TopBar and Avatar task: ✕ and the card number read in groups
00:21 +125: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: TopBar and Avatar initials: given + family name, digraphs, fallbacks
00:21 +126: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: TopBar and Avatar user icon when there are no Latin initials
00:21 +127: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: Recent TransactionRow: ≥ 64 pt, one button element (Brightness.light)
00:21 +128: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: Recent TransactionRow: ≥ 64 pt, one button element (Brightness.dark)
00:21 +129: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: Recent HistoryCard: total, count and spoken summary
00:21 +130: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: Recent EmptyState: title and body, optional action
00:21 +131: /home/claude/giftcard-pro/waiter-app/test/components/templates_test.dart: (tearDownAll)
00:21 +131: loading /home/claude/giftcard-pro/waiter-app/test/app/redeem_journey_test.dart
00:21 +131: /home/claude/giftcard-pro/waiter-app/test/app/redeem_journey_test.dart: first shift: sign in, redeem € 24,90, see it in Recent, sign out
00:24 +132: loading /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart
00:25 +132: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §1.5 — date on balance card / problem bodies DE (de-AT and de-DE/CH): 26.09.2029
00:25 +133: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §1.5 — date on balance card / problem bodies EN: 26 Sep 2029 (day–month abbreviation everywhere)
00:25 +134: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §1.5 — date on balance card / problem bodies BHS: 26. 9. 2029.
00:25 +135: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §1.5 — month names written out DE: Jänner (de-AT), Januar (de-DE/CH), Februar
00:25 +136: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §1.5 — month names written out EN: January; BHS lower case: januar, februar
00:25 +137: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §1.5 — month names written out long date for screen readers
00:25 +138: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §1.5 — times rows and details: 18:30; en-US 6:30 pm
00:25 +139: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §1.5 — times 12-hour clock edges
00:25 +140: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §1.5 — times time in a sentence: 18:30 Uhr · 18:30 / 6:30 pm · 18:30 h
00:25 +141: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §1.5 — times business-day reference: seit 04:00 Uhr · since 04:00 · od 04:00 h
00:25 +142: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §1.5 — times wall time is taken in the restaurant zone, not the device zone
00:25 +143: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §4.2 {time} countdown m:ss below one hour
00:25 +144: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §4.2 {time} countdown h:mm:ss from one hour
00:25 +145: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §4.2 {time} countdown partial seconds round up; 0:00 only when over
00:25 +146: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: 12 §4.2 {time} countdown {seconds} and {minutes} round up
00:25 +147: /home/claude/giftcard-pro/waiter-app/test/core/format/date_time_test.dart: CalendarDate parses the API expires_at
00:25 +148: loading /home/claude/giftcard-pro/waiter-app/test/core/format/business_day_test.dart
00:25 +148: /home/claude/giftcard-pro/waiter-app/test/core/format/business_day_test.dart: BusinessDay — 04:00 rollover (12 §1.5, 09 §4.5–4.6) 03:59 local belongs to the previous day, 04:00 starts a new one
00:25 +149: /home/claude/giftcard-pro/waiter-app/test/core/format/business_day_test.dart: BusinessDay — 04:00 rollover (12 §1.5, 09 §4.5–4.6) late evening and after midnight are the same business day
00:25 +150: /home/claude/giftcard-pro/waiter-app/test/core/format/business_day_test.dart: BusinessDay — 04:00 rollover (12 §1.5, 09 §4.5–4.6) DST start (2026-03-29, 02:00 → 03:00): offset at 04:00 is +2 h
00:25 +151: /home/claude/giftcard-pro/waiter-app/test/core/format/business_day_test.dart: BusinessDay — 04:00 rollover (12 §1.5, 09 §4.5–4.6) DST end (2026-10-25, 03:00 → 02:00): offset at 04:00 is +1 h
00:25 +152: /home/claude/giftcard-pro/waiter-app/test/core/format/business_day_test.dart: BusinessDay — 04:00 rollover (12 §1.5, 09 §4.5–4.6) device zone is irrelevant (local DateTime input)
00:25 +153: /home/claude/giftcard-pro/waiter-app/test/core/format/business_day_test.dart: BusinessDay — 04:00 rollover (12 §1.5, 09 §4.5–4.6) negative offsets, month and year boundaries
00:25 +154: /home/claude/giftcard-pro/waiter-app/test/core/format/business_day_test.dart: BusinessDay — 04:00 rollover (12 §1.5, 09 §4.5–4.6) ordering
00:25 +155: loading /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart
00:26 +155: /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart: Spoken.amount — 12 §1.4 spoken table de
00:26 +156: /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart: Spoken.amount — 12 §1.4 spoken table en
00:26 +157: /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart: Spoken.amount — 12 §1.4 spoken table bhs
00:26 +158: /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart: Spoken.amount — 07 §5.2 mirror and edge cases thousands are not grouped (07 §5.2: "1250 euros")
00:26 +159: /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart: Spoken.amount — 07 §5.2 mirror and edge cases zero reads "0 euro" (05 §2.2 empty AmountDisplay)
00:26 +160: /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart: Spoken.amount — 07 §5.2 mirror and edge cases BHS euro plural: one / few / other (12 §1.9)
00:26 +161: /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart: Spoken.amount — 07 §5.2 mirror and edge cases cents-only form uses the grammatical plural (07 §5.2)
00:26 +162: /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart: Spoken.amount — 07 §5.2 mirror and edge cases cents are spoken as a number, without leading zero
00:26 +163: /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart: Spoken.amount — 07 §5.2 mirror and edge cases non-EUR and negative amounts are rejected
00:26 +164: /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart: Spoken characters and card numbers card ending read digit by digit (12 §1.10)
00:26 +165: /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart: Spoken characters and card numbers full and partial card number in groups (07 §5.2, 05 §2.5)
00:26 +166: /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart: bhsPluralCategory (12 §1.9) examples of the table
00:26 +167: /home/claude/giftcard-pro/waiter-app/test/core/format/spoken_test.dart: bhsPluralCategory (12 §1.9) 12–14 are other, 22–24 few, 0 other
00:26 +168: loading /home/claude/giftcard-pro/waiter-app/test/core/format/amount_entry_test.dart
00:26 +168: /home/claude/giftcard-pro/waiter-app/test/core/format/amount_entry_test.dart: AmountEntry — 03b §2.9 digits shift in from the right: 0,00 → 0,02 → 0,24 → 2,49 → 24,90
00:26 +169: /home/claude/giftcard-pro/waiter-app/test/core/format/amount_entry_test.dart: AmountEntry — 03b §2.9 0 and 00 at amount 0 are a no-op without feedback
00:26 +170: /home/claude/giftcard-pro/waiter-app/test/core/format/amount_entry_test.dart: AmountEntry — 03b §2.9 0 after a digit is accepted
00:26 +171: /home/claude/giftcard-pro/waiter-app/test/core/format/amount_entry_test.dart: AmountEntry — 03b §2.9 00 adds two zeros
00:26 +172: /home/claude/giftcard-pro/waiter-app/test/core/format/amount_entry_test.dart: AmountEntry — 03b §2.9 00 with 6 digits typed adds one 0
00:26 +173: /home/claude/giftcard-pro/waiter-app/test/core/format/amount_entry_test.dart: AmountEntry — 03b §2.9 8th digit is ignored with the limit nudge (max € 99.999,99)
00:26 +174: /home/claude/giftcard-pro/waiter-app/test/core/format/amount_entry_test.dart: AmountEntry — 03b §2.9 ⌫ removes the last digit (24,90 → 2,49)
00:26 +175: /home/claude/giftcard-pro/waiter-app/test/core/format/amount_entry_test.dart: AmountEntry — 03b §2.9 ⌫ at 0 does nothing
00:26 +176: /home/claude/giftcard-pro/waiter-app/test/core/format/amount_entry_test.dart: AmountEntry — 03b §2.9 long-press ⌫ clears to 0
00:26 +177: /home/claude/giftcard-pro/waiter-app/test/core/format/amount_entry_test.dart: AmountEntry — 03b §2.9 QuickAmountChip sets the amount to the balance
00:26 +178: /home/claude/giftcard-pro/waiter-app/test/core/format/amount_entry_test.dart: AmountEntry — 03b §2.9 digit outside 0–9 is a programming error
00:26 +179: /home/claude/giftcard-pro/waiter-app/test/core/format/amount_entry_test.dart: AmountEntry — 03b §2.9 value semantics
00:26 +180: loading /home/claude/giftcard-pro/waiter-app/test/core/format/card_number_test.dart
00:27 +180: /home/claude/giftcard-pro/waiter-app/test/core/format/card_number_test.dart: CardNumber — 12 §1.4 full number in groups of 4 with no-break spaces
00:27 +181: /home/claude/giftcard-pro/waiter-app/test/core/format/card_number_test.dart: CardNumber — 12 §1.4 masked: four U+2022 bullets, no-break space, last four
00:27 +182: /home/claude/giftcard-pro/waiter-app/test/core/format/card_number_test.dart: CardNumber — 12 §1.4 lastFour
00:27 +183: /home/claude/giftcard-pro/waiter-app/test/core/format/card_number_test.dart: CardNumber.fromPaste — 03a §7 all non-digits stripped; exactly 16 → number
00:27 +184: /home/claude/giftcard-pro/waiter-app/test/core/format/card_number_test.dart: CardNumber.fromPaste — 03a §7 anything else → null
00:27 +185: /home/claude/giftcard-pro/waiter-app/test/core/format/card_number_test.dart: CardNumberEntry — 03a §7 typing and counter
00:27 +186: /home/claude/giftcard-pro/waiter-app/test/core/format/card_number_test.dart: CardNumberEntry — 03a §7 leading zero is a real digit
00:27 +187: /home/claude/giftcard-pro/waiter-app/test/core/format/card_number_test.dart: CardNumberEntry — 03a §7 17th digit rejected with the limit nudge
00:27 +188: /home/claude/giftcard-pro/waiter-app/test/core/format/card_number_test.dart: CardNumberEntry — 03a §7 00 inserts two zeros, one if only one position is left
00:27 +189: /home/claude/giftcard-pro/waiter-app/test/core/format/card_number_test.dart: CardNumberEntry — 03a §7 ⌫ deletes one digit, long-press clears all
00:27 +190: /home/claude/giftcard-pro/waiter-app/test/core/format/card_number_test.dart: CardNumberEntry — 03a §7 paste replaces the field or is rejected unchanged
00:27 +191: /home/claude/giftcard-pro/waiter-app/test/core/format/card_number_test.dart: CardNumberEntry — 03a §7 restore previous number (S10 → S11)
00:27 +192: loading /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart
00:27 +192: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: 12 §1.4 table — every row, every column de UI · de-AT
00:27 +193: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: 12 §1.4 table — every row, every column de UI · de-DE
00:27 +194: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: 12 §1.4 table — every row, every column de UI · de-CH
00:27 +195: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: 12 §1.4 table — every row, every column en UI · de-AT
00:27 +196: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: 12 §1.4 table — every row, every column en UI · en-GB
00:27 +197: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: 12 §1.4 table — every row, every column en UI · en-US
00:27 +198: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: 12 §1.4 table — every row, every column BHS UI · any restaurant locale → 24,90 €
00:27 +199: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: 12 §1.4 bullet rules always two decimals, also for whole euros
00:27 +200: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: 12 §1.4 bullet rules symbol ↔ number space is U+00A0, never U+0020
00:27 +201: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: 12 §1.4 bullet rules grouping beyond the 7-digit limit (balances)
00:27 +202: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: 12 §1.4 bullet rules negative amounts are rejected (never shown)
00:27 +203: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: 12 §1.4 bullet rules currency comes from the API and is not hard-coded
00:27 +204: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: MoneyParts (AmountDisplay / BalanceCard, 04 §3.4) de-AT leading, spaced
00:27 +205: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: MoneyParts (AmountDisplay / BalanceCard, 04 §3.4) de-DE trailing, spaced
00:27 +206: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: MoneyParts (AmountDisplay / BalanceCard, 04 §3.4) en-GB leading, tight
00:27 +207: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: RestaurantLocale.parse brief list, separators and case
00:27 +208: /home/claude/giftcard-pro/waiter-app/test/core/format/money_test.dart: RestaurantLocale.parse unknown tags fall back by language
00:27 +209: loading /home/claude/giftcard-pro/waiter-app/test/core/format/support_code_test.dart
00:28 +209: /home/claude/giftcard-pro/waiter-app/test/core/format/support_code_test.dart: SupportCode — 12 §2.5, 13 · R02 last 6 characters, upper case, no hyphens
00:28 +210: /home/claude/giftcard-pro/waiter-app/test/core/format/support_code_test.dart: SupportCode — 12 §2.5, 13 · R02 hyphens are removed before taking 6 characters
00:28 +211: /home/claude/giftcard-pro/waiter-app/test/core/format/support_code_test.dart: SupportCode — 12 §2.5, 13 · R02 too short → FormatException
00:28 +212: /home/claude/giftcard-pro/waiter-app/test/core/format/support_code_test.dart: SupportCode — 12 §2.5, 13 · R02 screen reader reads characters singly: "7 F 3 A 9 C"
00:28 +213: loading /home/claude/giftcard-pro/waiter-app/test/core/theme/assets_test.dart
00:29 +213: /home/claude/giftcard-pro/waiter-app/test/core/theme/assets_test.dart: icons 46 icons: every file exists and follows the grid rules
00:29 +214: /home/claude/giftcard-pro/waiter-app/test/core/theme/assets_test.dart: icons file names follow ic_<lucide-name> (10 §1.2)
00:29 +215: /home/claude/giftcard-pro/waiter-app/test/core/theme/assets_test.dart: icons stroke compensation per size (04 §11.2)
00:29 +216: /home/claude/giftcard-pro/waiter-app/test/core/theme/assets_test.dart: icons stroke rewrite scales every width, including mask cuts
00:29 +217: /home/claude/giftcard-pro/waiter-app/test/core/theme/assets_test.dart: icons accent arcs are addressable for recolouring
00:29 +218: /home/claude/giftcard-pro/waiter-app/test/core/theme/assets_test.dart: icons renders with semantics only when labelled
00:29 +219: /home/claude/giftcard-pro/waiter-app/test/core/theme/assets_test.dart: illustrations 10 illustrations with roles and budget
00:29 +220: /home/claude/giftcard-pro/waiter-app/test/core/theme/assets_test.dart: illustrations sizes per use (10 §4.3)
00:29 +221: /home/claude/giftcard-pro/waiter-app/test/core/theme/assets_test.dart: illustrations stroke stays 1.75 pt at every size, +0.25 in high contrast
00:29 +222: /home/claude/giftcard-pro/waiter-app/test/core/theme/assets_test.dart: illustrations renders decoratively at the use size
00:30 +223: /home/claude/giftcard-pro/waiter-app/test/core/theme/assets_test.dart: sounds ship only as platform files, not Flutter assets (10 §2.5)
00:30 +224: loading /home/claude/giftcard-pro/waiter-app/test/core/theme/contrast_test.dart
00:30 +224: /home/claude/giftcard-pro/waiter-app/test/core/theme/contrast_test.dart: neutral text ≥ 4.5 : 1 on canvas, surface, raised
00:30 +225: /home/claude/giftcard-pro/waiter-app/test/core/theme/contrast_test.dart: documented failure: fg.tertiary on bg.key (light) is 4.28
00:30 +226: /home/claude/giftcard-pro/waiter-app/test/core/theme/contrast_test.dart: actions
00:30 +227: /home/claude/giftcard-pro/waiter-app/test/core/theme/contrast_test.dart: border.control ≥ 3 : 1 as input boundary (13 · R06)
00:30 +228: /home/claude/giftcard-pro/waiter-app/test/core/theme/contrast_test.dart: focus ring ≥ 3 : 1 (13 · R17)
00:30 +229: /home/claude/giftcard-pro/waiter-app/test/core/theme/contrast_test.dart: hold ring ≥ 3 : 1 on the button fill (13 · R05)
00:30 +230: /home/claude/giftcard-pro/waiter-app/test/core/theme/contrast_test.dart: status text on canvas, surface and own tint
00:30 +231: /home/claude/giftcard-pro/waiter-app/test/core/theme/contrast_test.dart: on-colour labels (04 §8.4)
00:30 +232: /home/claude/giftcard-pro/waiter-app/test/core/theme/contrast_test.dart: saffron text and inverse (snackbar)
00:30 +233: /home/claude/giftcard-pro/waiter-app/test/core/theme/contrast_test.dart: high contrast raises secondary and tertiary text
00:30 +234: /home/claude/giftcard-pro/waiter-app/test/core/theme/contrast_test.dart: brand ink
00:30 +235: loading /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart
00:31 +235: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: (setUpAll)
00:31 +235: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: per-style clamps (04 §3.7) type.body.l caps at 200.0%
00:31 +236: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: per-style clamps (04 §3.7) type.caption caps at 200.0%
00:31 +237: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: per-style clamps (04 §3.7) type.label.l caps at 200.0%
00:31 +238: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: per-style clamps (04 §3.7) type.title.l caps at 150.0%
00:31 +239: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: per-style clamps (04 §3.7) type.title.m caps at 150.0%
00:31 +240: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: per-style clamps (04 §3.7) type.overline caps at 130.0%
00:31 +241: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: per-style clamps (04 §3.7) type.key caps at 120.0%
00:31 +242: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: per-style clamps (04 §3.7) extra cap inside the BalanceCard (130 %)
00:31 +243: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: per-style clamps (04 §3.7) overline renders uppercase
00:31 +244: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: shrink-to-fit steps 2 pt down, never below the minimum
00:31 +245: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: shrink-to-fit amount caps at 130 % then shrinks to fit, min 40
00:31 +246: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: shrink-to-fit rich spans scale together (currency keeps 60 %)
00:31 +247: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: shrink-to-fit card number shrinks to min 20
00:31 +248: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: WaiterThemeScope caps the global scaler at 200 %, folds in Bold Text and high contrast
00:31 +249: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: resolveBrightness honours the Menu override
00:31 +250: /home/claude/giftcard-pro/waiter-app/test/core/theme/scaled_text_test.dart: (tearDownAll)
00:32 +250: loading /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart
00:32 +250: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: parseBrandColor accepts 6-digit hex with or without #, any case
00:32 +251: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: parseBrandColor treats other forms as missing
00:32 +252: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: parseBrandColor missing colour renders the ink card
00:32 +253: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: sheen stops for ink: #1D2537 → #0E1627
00:32 +254: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: worked examples (04 §8.6 table) #0F172A
00:32 +255: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: worked examples (04 §8.6 table) #7F1D1D
00:32 +256: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: worked examples (04 §8.6 table) #14532D
00:32 +257: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: worked examples (04 §8.6 table) #1E3A8A
00:32 +258: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: worked examples (04 §8.6 table) #2563EB
00:32 +259: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: worked examples (04 §8.6 table) #C2410C
00:32 +260: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: worked examples (04 §8.6 table) #DC2626
00:32 +261: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: worked examples (04 §8.6 table) #0D9488
00:32 +262: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: worked examples (04 §8.6 table) #E8A33D
00:32 +263: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: worked examples (04 §8.6 table) #F5F0E6
00:32 +264: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: worked examples (04 §8.6 table) #FFFFFF
00:32 +265: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: worked examples (04 §8.6 table) #6B7280 falls back to ink
00:32 +266: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: worked examples (04 §8.6 table) #808080 falls back to ink
00:32 +267: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: glow uses the original brand colour at 28 % (light only)
00:32 +268: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: desaturated states (blocked, expired, replaced) a borderline colour that fails after desaturation falls back
00:32 +269: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: desaturated states (blocked, expired, replaced) status mapping
00:32 +270: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: desaturated states (blocked, expired, replaced) chroma −40 % keeps lightness and hue, grey stays grey
00:32 +271: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: desaturated states (blocked, expired, replaced) recomputes text and swaps glow for elev.2
00:32 +272: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: dark theme: same card colour, outline, no shadow
00:32 +273: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: high contrast: secondary card text at 100 %
00:32 +274: /home/claude/giftcard-pro/waiter-app/test/core/theme/brand_color_test.dart: badge outline only on dark-text cards
00:32 +275: loading /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart
00:33 +275: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: (setUpAll)
00:33 +275: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: bundled fonts (09 §3, 10 §2.4) assets/fonts/Geist-Regular.ttf covers the required glyphs and tnum
00:33 +276: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: bundled fonts (09 §3, 10 §2.4) assets/fonts/Geist-Medium.ttf covers the required glyphs and tnum
00:33 +277: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: bundled fonts (09 §3, 10 §2.4) assets/fonts/Geist-SemiBold.ttf covers the required glyphs and tnum
00:33 +278: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: bundled fonts (09 §3, 10 §2.4) assets/fonts/Geist-Bold.ttf covers the required glyphs and tnum
00:33 +279: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: bundled fonts (09 §3, 10 §2.4) assets/fonts/GeistMono-Medium.ttf covers the required glyphs and tnum
00:33 +280: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: bundled fonts (09 §3, 10 §2.4) even leading centres the cap height (04 §3.2)
00:33 +281: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: tabular figures (09 §3) "1111" and "0000" have identical widths at type.amount.xl
00:33 +282: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: tabular figures (09 §3) digits never shift in keys, captions and balances
00:33 +283: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: text styles style fields follow the tokens
00:33 +284: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: text styles Bold Text raises weights one step (04 §10.2)
00:33 +285: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: text styles of() and at() resolve every token
00:33 +286: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: glyph data is loaded from the declared assets
00:33 +287: /home/claude/giftcard-pro/waiter-app/test/core/theme/typography_test.dart: (tearDownAll)
00:33 +287: loading /home/claude/giftcard-pro/waiter-app/test/core/theme/theme_test.dart
00:33 +287: /home/claude/giftcard-pro/waiter-app/test/core/theme/theme_test.dart: waiterThemeData (09 §2.5) installs the WaiterTheme extension and maps system roles
00:33 +288: /home/claude/giftcard-pro/waiter-app/test/core/theme/theme_test.dart: waiterThemeData (09 §2.5) dark, high contrast and bold text variants
00:33 +289: /home/claude/giftcard-pro/waiter-app/test/core/theme/theme_test.dart: waiterThemeData (09 §2.5) lerp is used for the theme cross-fade
00:33 +290: /home/claude/giftcard-pro/waiter-app/test/core/theme/theme_test.dart: context extensions
00:34 +291: /home/claude/giftcard-pro/waiter-app/test/core/theme/theme_test.dart: layout (04 §4, 08 §1) width classes and margins
00:34 +292: /home/claude/giftcard-pro/waiter-app/test/core/theme/theme_test.dart: layout (04 §4, 08 §1) iPhone SE is compact height; iPhone 15 is regular
00:34 +293: /home/claude/giftcard-pro/waiter-app/test/core/theme/theme_test.dart: layout (04 §4, 08 §1) tablet content is capped at 560, text at 480, keypad at 400
00:34 +294: /home/claude/giftcard-pro/waiter-app/test/core/theme/theme_test.dart: layout (04 §4, 08 §1) ID-1 card height and minimum window
00:34 +295: loading /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart
00:34 +295: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: valid document produces ARBs, InfoPlist.strings and pseudo class
00:34 +296: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: arbKeyOf follows 09 §6.5
00:34 +297: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: normalisation: no-break space before … and in countdowns
00:34 +298: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: fails loudly malformed row (cell count)
00:34 +299: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: fails loudly duplicate key
00:34 +300: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: fails loudly two spec keys mapping to one identifier
00:34 +301: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: fails loudly missing language cell
00:34 +302: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: fails loudly placeholder mismatch across languages
00:34 +303: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: fails loudly wrong plural categories for BHS
00:34 +304: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: fails loudly invalid ICU
00:34 +305: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: fails loudly key count differs from §5.22
00:34 +306: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: fails loudly alias implemented as a key
00:34 +307: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: fails loudly alias kept as its own key is allowed
00:34 +308: /home/claude/giftcard-pro/waiter-app/test/core/l10n/import_strings_test.dart: fails loudly markdown or exclamation mark inside a message
00:34 +309: loading /home/claude/giftcard-pro/waiter-app/test/core/l10n/app_localizations_test.dart
00:35 +309: /home/claude/giftcard-pro/waiter-app/test/core/l10n/app_localizations_test.dart: loads for de, en, bs, hr, sr
00:35 +310: /home/claude/giftcard-pro/waiter-app/test/core/l10n/app_localizations_test.dart: plurals (12 §1.9) DE / EN one · other
00:35 +311: /home/claude/giftcard-pro/waiter-app/test/core/l10n/app_localizations_test.dart: plurals (12 §1.9) BHS one · few · other incl. 11 and 21, in bs, hr and sr
00:35 +312: /home/claude/giftcard-pro/waiter-app/test/core/l10n/app_localizations_test.dart: plurals (12 §1.9) BHS few category is selected by the runtime plural rules
00:35 +313: /home/claude/giftcard-pro/waiter-app/test/core/l10n/app_localizations_test.dart: plurals (12 §1.9) a11y.spokenAmount template agrees with Spoken.amount
00:35 +314: /home/claude/giftcard-pro/waiter-app/test/core/l10n/app_localizations_test.dart: typography rules survive the import (12 §1.4, §1.7)
00:35 +315: /home/claude/giftcard-pro/waiter-app/test/core/l10n/app_localizations_test.dart: delegates resolve through Localizations
00:35 +316: loading /home/claude/giftcard-pro/waiter-app/test/core/l10n/arb_integrity_test.dart
00:36 +316: /home/claude/giftcard-pro/waiter-app/test/core/l10n/arb_integrity_test.dart: outputs are in sync with 12 §5 (import_strings --check)
00:36 +317: /home/claude/giftcard-pro/waiter-app/test/core/l10n/arb_integrity_test.dart: key count: 272 table keys (12 §5.22) = 269 ARB + 3 OS strings
00:36 +318: /home/claude/giftcard-pro/waiter-app/test/core/l10n/arb_integrity_test.dart: all ARBs have identical key sets
00:36 +319: /home/claude/giftcard-pro/waiter-app/test/core/l10n/arb_integrity_test.dart: placeholders identical across languages and declared in @metadata
00:36 +320: /home/claude/giftcard-pro/waiter-app/test/core/l10n/arb_integrity_test.dart: placeholder types follow 12 §4.2
00:36 +321: /home/claude/giftcard-pro/waiter-app/test/core/l10n/arb_integrity_test.dart: every key keeps its spec key in the description (09 §6.5)
00:36 +322: /home/claude/giftcard-pro/waiter-app/test/core/l10n/arb_integrity_test.dart: hr and sr are exact copies of bs (09 §6.5)
00:36 +323: /home/claude/giftcard-pro/waiter-app/test/core/l10n/arb_integrity_test.dart: aliases of 12 §5.22 are not separate keys
00:36 +324: /home/claude/giftcard-pro/waiter-app/test/core/l10n/arb_integrity_test.dart: identical strings across languages are only the intended ones
00:36 +325: /home/claude/giftcard-pro/waiter-app/test/core/l10n/arb_integrity_test.dart: no exclamation marks, ellipsis is " …" (12 §1.7)
00:36 +326: loading /home/claude/giftcard-pro/waiter-app/test/core/l10n/locale_resolution_test.dart
00:37 +326: /home/claude/giftcard-pro/waiter-app/test/core/l10n/locale_resolution_test.dart: resolveAppLocale — 09 §6.5 / brief §7 de* → de
00:37 +327: /home/claude/giftcard-pro/waiter-app/test/core/l10n/locale_resolution_test.dart: resolveAppLocale — 09 §6.5 / brief §7 en* → en
00:37 +328: /home/claude/giftcard-pro/waiter-app/test/core/l10n/locale_resolution_test.dart: resolveAppLocale — 09 §6.5 / brief §7 bs / hr / sr in any script or region → bs (BHS Latin)
00:37 +329: /home/claude/giftcard-pro/waiter-app/test/core/l10n/locale_resolution_test.dart: resolveAppLocale — 09 §6.5 / brief §7 anything else → en
00:37 +330: /home/claude/giftcard-pro/waiter-app/test/core/l10n/locale_resolution_test.dart: callbacks list callback uses the phone language (first entry) only
00:37 +331: /home/claude/giftcard-pro/waiter-app/test/core/l10n/locale_resolution_test.dart: callbacks single-locale callback
00:37 +332: /home/claude/giftcard-pro/waiter-app/test/core/l10n/locale_resolution_test.dart: callbacks resolved locales are always supported
00:37 +333: /home/claude/giftcard-pro/waiter-app/test/core/l10n/locale_resolution_test.dart: callbacks supportedLocales declares de, en, bs, hr, sr (09 §6.5)
00:37 +334: /home/claude/giftcard-pro/waiter-app/test/core/l10n/locale_resolution_test.dart: UiLanguage.fromLanguageCode mapping
00:37 +335: loading /home/claude/giftcard-pro/waiter-app/test/core/l10n/pseudo_localization_test.dart
00:37 +335: /home/claude/giftcard-pro/waiter-app/test/core/l10n/pseudo_localization_test.dart: pseudoLocalize (09 §6.5) accents letters and expands by at least 40 %
00:37 +336: /home/claude/giftcard-pro/waiter-app/test/core/l10n/pseudo_localization_test.dart: pseudoLocalize (09 §6.5) short strings still get a visible marker
00:37 +337: /home/claude/giftcard-pro/waiter-app/test/core/l10n/pseudo_localization_test.dart: pseudoLocalize (09 §6.5) placeholder values are kept intact
00:37 +338: /home/claude/giftcard-pro/waiter-app/test/core/l10n/pseudo_localization_test.dart: PseudoLocalizationsDelegate wraps the real strings of every locale
00:37 +339: /home/claude/giftcard-pro/waiter-app/test/core/l10n/pseudo_localization_test.dart: PseudoLocalizationsDelegate plurals still select by count; placeholders untouched
00:37 +340: /home/claude/giftcard-pro/waiter-app/test/core/l10n/pseudo_localization_test.dart: PseudoLocalizationsDelegate is supported exactly where AppLocalizations is
00:37 +341: loading /home/claude/giftcard-pro/waiter-app/test/core/state/loop_controller_test.dart
00:38 +341: /home/claude/giftcard-pro/waiter-app/test/core/state/loop_controller_test.dart: Android tap → lookup → charge → redeem → success → auto-return (happy path)
00:38 +342: /home/claude/giftcard-pro/waiter-app/test/core/state/loop_controller_test.dart: I1/K4: slow first attempt and uncertain retries reuse one key with new request ids
00:38 +343: /home/claude/giftcard-pro/waiter-app/test/core/state/loop_controller_test.dart: Uncertain final after 20 s; Cancel keeps the attempt, a new amount gets a new key
00:38 +344: /home/claude/giftcard-pro/waiter-app/test/core/state/loop_controller_test.dart: I2: no redeem request while the OS reports no network
00:38 +345: /home/claude/giftcard-pro/waiter-app/test/core/state/loop_controller_test.dart: Definitive 4xx: insufficient balance updates the card from context and closes the key
00:38 +346: /home/claude/giftcard-pro/waiter-app/test/core/state/loop_controller_test.dart: 401 during redeem opens the session sheet and keeps the attempt (K6)
00:39 +347: /home/claude/giftcard-pro/waiter-app/test/core/state/loop_controller_test.dart: Device revoked blocks the app and clears the token
00:39 +348: /home/claude/giftcard-pro/waiter-app/test/core/state/loop_controller_test.dart: Lookup problems: not found (manual keeps digits), SUN card never retried, throttled countdown
00:39 +349: /home/claude/giftcard-pro/waiter-app/test/core/state/loop_controller_test.dart: Android: a second card with an amount typed offers a switch; duplicate reads are ignored
00:39 +350: /home/claude/giftcard-pro/waiter-app/test/core/state/loop_controller_test.dart: Card states: blocked card cannot be redeemed and plays the error sound
00:39 +351: /home/claude/giftcard-pro/waiter-app/test/core/state/loop_controller_test.dart: Partial redemption disabled: the amount is the full balance
00:39 +352: /home/claude/giftcard-pro/waiter-app/test/core/state/loop_controller_test.dart: iPhone: sheet cancel returns silently with the hint; rejected tag keeps the session
00:39 +353: loading /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart
00:39 +353: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: generated file is up to date with tokens/waiter.tokens.json
00:47 +354: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: colour (A.1) backgrounds
00:47 +355: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: colour (A.1) foregrounds and actions
00:47 +356: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: colour (A.1) brand, accent and status
00:47 +357: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: colour (A.1) added tokens (04 §8.4)
00:47 +358: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: colour (A.1) rgba tokens keep their alpha
00:47 +359: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: colour (A.1) high-contrast modifier (04 §10.1)
00:47 +360: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: colour (A.1) lerp reaches both ends
00:47 +361: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: typography (A.2) type scale
00:47 +362: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: typography (A.2) absolute tracking (04 §3.2 "Tracking (pt)")
00:47 +363: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: typography (A.2) scale caps and shrink (04 §3.7)
00:47 +364: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: typography (A.2) tabular figures on every style, uppercase overline
00:47 +365: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: typography (A.2) currency sizing (04 §3.4)
00:47 +366: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: space, radius, border, size (A.3, A.4) spacing scale
00:47 +367: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: space, radius, border, size (A.3, A.4) layout
00:47 +368: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: space, radius, border, size (A.3, A.4) radii
00:47 +369: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: space, radius, border, size (A.3, A.4) borders
00:47 +370: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: space, radius, border, size (A.3, A.4) sizes
00:47 +371: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: space, radius, border, size (A.3, A.4) icon sizes with compensated strokes (04 §11.2)
00:47 +372: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: space, radius, border, size (A.3, A.4) tier-3 component tokens resolve their references
00:47 +373: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: elevation, opacity, z (A.5) light shadows
00:47 +374: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: elevation, opacity, z (A.5) dark: surface steps and hairlines, no shadows
00:47 +375: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: elevation, opacity, z (A.5) opacity and z
00:47 +376: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: motion, time (A.6) durations and curves
00:47 +377: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: motion, time (A.6) springs follow 06 §2.2 conversion
00:47 +378: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: motion, time (A.6) timing tokens
00:47 +379: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: haptic and sound (11 §2) seven haptic tokens with platform mapping
00:47 +380: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: haptic and sound (11 §2) four sound tokens with binding file names
00:47 +381: /home/claude/giftcard-pro/waiter-app/test/core/tokens/tokens_test.dart: haptic and sound (11 §2) platform sound files exist
00:47 +382: loading /home/claude/giftcard-pro/waiter-app/test/screens/charge/problem_page_test.dart
00:48 +382: /home/claude/giftcard-pro/waiter-app/test/screens/charge/problem_page_test.dart: not found: scan again / enter card number, support code (L01)
00:49 +383: /home/claude/giftcard-pro/waiter-app/test/screens/charge/problem_page_test.dart: not found after manual entry: "Edit number" keeps the digits (L02)
00:49 +384: /home/claude/giftcard-pro/waiter-app/test/screens/charge/problem_page_test.dart: another restaurant: Done → Ready (L03)
00:50 +385: /home/claude/giftcard-pro/waiter-app/test/screens/charge/problem_page_test.dart: verification failed: calm, neutral tag, one fresh read, then no second "Scan again" (L04, 13 · R03)
00:50 +386: /home/claude/giftcard-pro/waiter-app/test/screens/charge/problem_page_test.dart: throttled: disabled countdown button enables at 0 (L05, AC-S10-4)
00:50 +387: /home/claude/giftcard-pro/waiter-app/test/screens/charge/problem_page_test.dart: network: "Try again" re-sends the identical lookup and keeps S10 busy until the result (L06, 03b §5.1)
00:51 +388: /home/claude/giftcard-pro/waiter-app/test/screens/charge/problem_page_test.dart: network with a SUN-signed card: "Scan again", never a re-post (AC-S10-5)
00:51 +389: /home/claude/giftcard-pro/waiter-app/test/screens/charge/problem_page_test.dart: server error: "Try again" with support code (L07)
00:51 +390: /home/claude/giftcard-pro/waiter-app/test/screens/charge/problem_page_test.dart: long-press on the support code copies the full request id (AC-S10-6)
00:51 +391: /home/claude/giftcard-pro/waiter-app/test/screens/charge/problem_page_test.dart: ✕ returns to Ready
00:52 +392: /home/claude/giftcard-pro/waiter-app/test/screens/charge/problem_page_test.dart: iPhone: "Scan again" opens the NFC sheet
00:52 +393: /home/claude/giftcard-pro/waiter-app/test/screens/charge/problem_page_test.dart: German and BHS copy
00:52 +394: loading /home/claude/giftcard-pro/waiter-app/test/screens/charge/redeeming_test.dart
00:53 +394: /home/claude/giftcard-pro/waiter-app/test/screens/charge/redeeming_test.dart: S08 Redeeming submitting: label kept for 150 ms, then the spinner; keypad, chip and ✕ locked (AC-S08-1/3)
00:54 +395: /home/claude/giftcard-pro/waiter-app/test/screens/charge/redeeming_test.dart: S08 Redeeming slow after 8 s, then the uncertain panel with the attempt counter; a success still lands on S09 (AC-S08-4/5/7)
00:55 +396: /home/claude/giftcard-pro/waiter-app/test/screens/charge/redeeming_test.dart: S08 Redeeming final: "Try again" reuses the key, "Cancel" keeps card and amount with the unconfirmed banner (AC-S08-8/10/11)
00:56 +397: /home/claude/giftcard-pro/waiter-app/test/screens/charge/redeeming_test.dart: notices balance changed: new balance, 4-s helper, then over balance (R06, AC-S08-14)
00:56 +398: /home/claude/giftcard-pro/waiter-app/test/screens/charge/redeeming_test.dart: notices max single redemption from the server: message, "Use maximum", checked client-side afterwards (R10)
00:57 +399: /home/claude/giftcard-pro/waiter-app/test/screens/charge/redeeming_test.dart: notices full-only rule changed meanwhile: "Nothing was booked." for 4 s, then the full-only layout (R11)
00:57 +400: /home/claude/giftcard-pro/waiter-app/test/screens/charge/redeeming_test.dart: notices card blocked meanwhile: blocked variant with "Nothing was booked." (R07)
00:58 +401: /home/claude/giftcard-pro/waiter-app/test/screens/charge/redeeming_test.dart: notices client defect: generic line with support code (R12)
00:58 +402: /home/claude/giftcard-pro/waiter-app/test/screens/charge/redeeming_test.dart: notices idempotency conflict: "Please tap Redeem again." and no resubmit (R13, AC-S08-13)
00:59 +403: /home/claude/giftcard-pro/waiter-app/test/screens/charge/redeeming_test.dart: notices velocity limit without a time: banner with "Please get a manager" (R14)
00:59 +404: /home/claude/giftcard-pro/waiter-app/test/screens/charge/redeeming_test.dart: notices velocity limit with a time counts in minutes (R14)
00:59 +405: /home/claude/giftcard-pro/waiter-app/test/screens/charge/redeeming_test.dart: notices rate limit counts down, then Redeem is available again (R15, 03b §2.17)
01:00 +406: loading /home/claude/giftcard-pro/waiter-app/test/screens/charge/success_screen_test.dart
01:00 +406: /home/claude/giftcard-pro/waiter-app/test/screens/charge/success_screen_test.dart: Android: result, remaining balance, hint, "Show guest" and "Done"; announced at t = 0; the chime plays once
01:02 +407: /home/claude/giftcard-pro/waiter-app/test/screens/charge/success_screen_test.dart: returns to Ready 4.52 s after the response (AC-S09-3)
01:03 +408: /home/claude/giftcard-pro/waiter-app/test/screens/charge/success_screen_test.dart: with a screen reader the return waits 10.52 s
01:03 +409: /home/claude/giftcard-pro/waiter-app/test/screens/charge/success_screen_test.dart: a tap anywhere returns at once (AC-S09-4); "Done" too
01:04 +410: /home/claude/giftcard-pro/waiter-app/test/screens/charge/success_screen_test.dart: "Show guest" pauses the return, shows no controls and closes after 20 s (AC-S09-9/10/11)
01:05 +411: /home/claude/giftcard-pro/waiter-app/test/screens/charge/success_screen_test.dart: a tap closes the guest view
01:05 +412: /home/claude/giftcard-pro/waiter-app/test/screens/charge/success_screen_test.dart: full balance: "Card is now empty", no 0,00 (AC-S09-8)
01:05 +413: /home/claude/giftcard-pro/waiter-app/test/screens/charge/success_screen_test.dart: iPhone: "Scan next card" opens the NFC sheet (AC-S09-5)
01:06 +414: /home/claude/giftcard-pro/waiter-app/test/screens/charge/success_screen_test.dart: Android: a new card during the countdown opens S07 for it (AC-S09-6)
01:06 +415: /home/claude/giftcard-pro/waiter-app/test/screens/charge/success_screen_test.dart: compact phone, 200 % text, dark theme and German render without overflow
01:07 +416: loading /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart
01:07 +416: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: amount entry typed digits shift in and the button repeats the amount in the same frame (AC-S07-1)
01:09 +417: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: amount entry ⌫ deletes, a long press clears (AC-S07-7)
01:09 +418: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: amount entry the 8th digit is ignored with the limit nudge (AC-S07-6)
01:10 +419: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: limits over balance: red message, chip, button disabled; the chip sets the balance (AC-S07-10/11)
01:10 +420: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: limits a known maximum single redemption is checked client-side with "Use maximum" (03b §2.16)
01:10 +421: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: hold to redeem € 99,99 is a tap, € 100,00 needs the 600 ms hold (AC-S07-13/14/15)
01:11 +422: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: partial redemption disabled no keypad or chip; "Redeem full balance" with the balance (AC-S07-17/18/19)
01:11 +423: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: partial redemption disabled ≥ € 100 uses the HoldButton
01:12 +424: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: card states (03b §2.14) blocked with reason
01:12 +425: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: card states (03b §2.14) expired with the date
01:12 +426: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: card states (03b §2.14) replaced
01:12 +427: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: card states (03b §2.14) inactive
01:12 +428: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: card states (03b §2.14) zero balance
01:12 +429: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: feedback plays once (11 §3.4) chip tap: one haptic.select (E35); 8th digit: one haptic.warning (E33); crossing the balance: key + warning (E30/E34)
01:13 +430: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: feedback plays once (11 §3.4) client-side max crossing: one haptic
01:14 +431: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: connection and card switch offline: banner and Redeem disabled (12 R16)
01:14 +432: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: connection and card switch Android: a different card with an amount typed offers "Switch" and hides Redeem (AC-S07-31/32)
01:14 +433: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: connection and card switch the switch snackbar times out as "Keep" (6 s)
01:15 +434: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: connection and card switch with a screen reader the switch offer is a dialog
01:15 +435: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: connection and card switch Android: a new card with amount 0 replaces the card
01:15 +436: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: connection and card switch a slow new-card lookup stays on S07 with the skeleton (M21)
01:15 +437: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: card link skeleton (03b §2.19) skeleton, "Still looking …" at 3 s, ✕ cancels
01:15 +438: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: card link skeleton (03b §2.19) the skeleton turns into the card
01:16 +439: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: layout reference phone: ID-1 card, button 8 pt above the bottom (AC-S07-3/8)
01:16 +440: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: layout 375 × 667 compact: strip card, 64-pt keys, no overflow
01:16 +441: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: layout text scale 200 %: strip card and nothing overflows
01:16 +442: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: layout dark theme renders
01:17 +443: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: layout tablet landscape: two panes, card left of the keypad
01:17 +444: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: layout German and BHS labels
01:17 +445: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: accessibility (07 §5) card, amount, keys and button carry spoken labels; the card is announced on entry
01:17 +446: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: accessibility (07 §5) Return redeems below € 100 (hardware keyboard)
01:18 +447: /home/claude/giftcard-pro/waiter-app/test/screens/charge/charge_screen_test.dart: ✕ closes without booking (N6)
01:18 +448: loading /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart
01:19 +448: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: (setUpAll)
01:19 +448: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: Android variant: fingerprint glyph and biometrics strings
01:20 +449: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: iPhone Face ID variant
01:20 +450: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: iPhone Touch ID variant
01:21 +451: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: enabling succeeds and continues to the intro on the first run
01:21 +452: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: P11: a cancelled prompt shows the caption and never re-prompts
01:21 +453: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: P10: nothing enrolled shows the snackbar
01:22 +454: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: "Not now" continues without biometrics
01:22 +455: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: both buttons are inert while the OS prompt is up
01:22 +456: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: semantics: title heading, glyph hidden
01:22 +457: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: German, compact frame, 200 % text and dark theme without overflow
01:23 +458: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: BHS strings on the compact frame
01:23 +459: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: compact height: 72-pt plate, 56-pt button
01:23 +460: /home/claude/giftcard-pro/waiter-app/test/screens/access/s03_biometrics_test.dart: (tearDownAll)
01:23 +460: loading /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart
01:24 +460: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: 10.1 session expired sheet a 401 opens the sheet; signing in again closes it
01:25 +461: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: 10.1 session expired sheet wrong password: banner, password cleared, sheet stays
01:26 +462: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: 10.1 session expired sheet 429 on the sheet counts down on the button
01:26 +463: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: 10.1 session expired sheet German, 200 % text, compact, dark: no overflow
01:26 +464: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: full-screen states A04 device revoked: support code, "Sign in" leads to S02
01:26 +465: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: full-screen states A05 suspended: "Check again" returns to Ready when active again
01:26 +466: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: full-screen states A05: "Check again" without a connection shows the offline caption
01:27 +467: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: full-screen states long-press on the support code copies the full request id
01:27 +468: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: full-screen states A05: "Check again" at most once per 3 s; "Sign out" leads to S02
01:27 +469: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: full-screen states A03 forbidden: check again and back to sign in
01:27 +470: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: full-screen states A10 deactivated: back to sign in
01:27 +471: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: full-screen states A06 locked: live countdown, disabled button, back to S02 at 0
01:28 +472: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: full-screen states A06: "Forgot password" opens the reset page
01:28 +473: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: full-screen states BHS and 200 % text on the compact frame
01:28 +474: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: 10.6 update required Android opens the Play listing of the package
01:28 +475: /home/claude/giftcard-pro/waiter-app/test/screens/access/s15_session_test.dart: 10.6 update required iPhone without a configured App Store URL opens nothing
01:28 +476: loading /home/claude/giftcard-pro/waiter-app/test/screens/access/s01_splash_test.dart
01:29 +476: /home/claude/giftcard-pro/waiter-app/test/screens/access/s01_splash_test.dart: shows only the 96-pt mark; the spinner and announcement come after 1 s
01:30 +477: /home/claude/giftcard-pro/waiter-app/test/screens/access/s01_splash_test.dart: a fast start never shows the spinner
01:30 +478: /home/claude/giftcard-pro/waiter-app/test/screens/access/s01_splash_test.dart: dark theme uses the dark canvas and mark colours
01:30 +479: /home/claude/giftcard-pro/waiter-app/test/screens/access/s01_splash_test.dart: the loading label is localised
01:30 +480: loading /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart
01:31 +480: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: renders the form; the button needs both fields
01:32 +481: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: success sends the credentials and leaves S02
01:33 +482: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: first sign-in with enrolled biometrics goes to S03
01:33 +483: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: shows the spinner and the busy label while signing in
01:33 +484: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: A07: wrong credentials clear only the password and shake it
01:33 +485: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: e-mail format is checked on blur and on submit, never while typing
01:34 +486: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: A02: an account without redeem permission gets the danger banner
01:34 +487: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: A08: 429 counts down live and re-enables the button at 0
01:34 +488: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: A09: server error shows the banner and keeps the button
01:34 +489: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: A09: offline disables the button and clears on reconnect
01:35 +490: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: a transport failure during the attempt shows the offline banner
01:35 +491: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: 423 moves to the S15 locked state
01:35 +492: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: prefills the last e-mail and focuses the password
01:35 +493: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: "Forgot password" opens the web reset page in the in-app browser
01:35 +494: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: semantics: heading, field labels and the busy-free button
01:35 +495: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: renders in de
01:36 +496: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: renders in bs
01:36 +497: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: renders in en
01:36 +498: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: 200 % text on the compact frame: no overflow, button above the keyboard
01:36 +499: /home/claude/giftcard-pro/waiter-app/test/screens/access/s02_sign_in_test.dart: brand row on regular height only; compact button is 56; dark theme
01:36 +500: loading /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart
01:37 +500: /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart: Android: three cards, Next → Next → Start
01:38 +501: /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart: Skip exits from any card in one tap
01:39 +502: /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart: swiping pages; swiping past the last card starts
01:39 +503: /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart: Android back: previous card, on card 1 it acts as Skip
01:40 +504: /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart: iPhone card 1
01:40 +505: /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart: no-NFC card 1 uses the QR icon in the 160-pt slot
01:40 +506: /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart: each card is one group "Page n of 3. Title. Body."
01:40 +507: /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart: iPhone SE: 120-pt art, everything fits, button in the thumb zone
01:41 +508: /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart: 150 % text uses the 120-pt art; 200 % on compact hides it
01:41 +509: /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart: Reduce Motion: paging cross-fades without a PageView
01:41 +510: /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart: tablet landscape: illustration left, text right
01:41 +511: /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart: renders in de (dark)
01:42 +512: /home/claude/giftcard-pro/waiter-app/test/screens/access/s17_intro_test.dart: renders in bs (dark)
01:42 +513: loading /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart
01:43 +513: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: (setUpAll)
01:43 +513: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: the prompt opens without a tap; success unlocks
01:44 +514: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: shows who is unlocking; name and restaurant are read together
01:44 +515: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: P11: a cancelled prompt never re-opens by itself; the button re-prompts
01:44 +516: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: returning from the background prompts again
01:44 +517: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: P12: lockout shows the password hint
01:44 +518: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: P13: changed biometrics force the password with the S02 notice
01:45 +519: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: "Use password" goes to S02 with the e-mail prefilled
01:45 +520: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: buttons are inert while the prompt is up
01:45 +521: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: a pending card link shows the info banner
01:45 +522: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: iPhone Face ID and Touch ID button labels
01:45 +523: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: German, compact, 200 % text and dark theme without overflow
01:45 +524: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: BHS strings on the compact frame
01:45 +525: /home/claude/giftcard-pro/waiter-app/test/screens/access/s04_unlock_test.dart: (tearDownAll)
01:45 +525: loading /home/claude/giftcard-pro/waiter-app/test/screens/scan/s13_recent_test.dart
01:46 +525: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s13_recent_test.dart: empty: EmptyState, no HistoryCard
01:47 +526: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s13_recent_test.dart: rows: summary, hour groups in the restaurant zone, newest first, footer
01:47 +527: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s13_recent_test.dart: detail: facts, reversal hint exactly once, no actions; long-press copies the id
01:48 +528: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s13_recent_test.dart: a 04:00 clear while open fades into the empty state
01:48 +529: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s13_recent_test.dart: empty state at 200 % text on a compact phone scrolls instead of overflowing
01:48 +530: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s13_recent_test.dart: German copy, dark theme, 200 % text and tablet width without overflow
01:48 +531: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s13_recent_test.dart: row semantics speak the time, the card ending and both amounts
01:49 +532: loading /home/claude/giftcard-pro/waiter-app/test/screens/scan/s14_menu_test.dart
01:49 +532: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s14_menu_test.dart: account, restaurant, device, settings, sign out, version
01:50 +533: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s14_menu_test.dart: the device row is left out when the name cannot be loaded
01:51 +534: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s14_menu_test.dart: Sounds off/on: select haptic, preview sample only when turned on
01:51 +535: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s14_menu_test.dart: Haptics on plays the preview, off plays nothing; Keep screen on toggles
01:51 +536: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s14_menu_test.dart: Appearance: nested sheet, Dark applies without restart
01:52 +537: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s14_menu_test.dart: Sign out asks first; Cancel keeps the session
01:52 +538: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s14_menu_test.dart: Sign out confirmed: token and Recent cleared, S02 — also offline
01:53 +539: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s14_menu_test.dart: German and BHS copy
01:53 +540: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s14_menu_test.dart: compact phone at 200 % text: no overflow, rows semantics expose state
01:53 +541: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s14_menu_test.dart: tablet landscape at 200 % text: no overflow, rows semantics expose state
01:53 +542: loading /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart
01:54 +542: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart: searching: title, hint, torch, "Enter card number"
01:55 +543: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart: not a gift card: warning line for 2.5 s, same payload ignored for 3 s, no request
01:55 +544: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart: valid card: one request (method qr), preview freezes, looking up → slow → Cancel
01:55 +545: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart: "Enter card number" replaces S12 with S11
01:55 +546: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart: offline pauses detection with the offline caption
01:55 +547: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart: camera unavailable (P05): only "Enter card number"
01:55 +548: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart: camera denied on the real app path (mobile_scanner answers "denied")
01:56 +549: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart: always dark values and light status bar content, also in the light theme
01:56 +550: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart: German copy
01:56 +551: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart: compact lays out without overflow; "Enter card number" in the thumb zone
01:56 +552: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart: compact at 200 % text lays out without overflow; "Enter card number" in the thumb zone
01:56 +553: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart: tablet landscape lays out without overflow; "Enter card number" in the thumb zone
01:56 +554: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s12_qr_scan_test.dart: the camera is released when S12 leaves
01:56 +555: loading /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart
01:57 +555: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: layout: helper, empty field, counter, keypad without 00, disabled button
01:58 +556: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: 16 digits enable the button, 17th is rejected, submit sends method manual
01:59 +557: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: long-press ⌫ clears the field
01:59 +558: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: paste strips non-digits; an invalid paste shows the error for 3 s
02:00 +559: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: 422 VALIDATION_FAILED: inline error, digits kept, cleared by typing
02:00 +560: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: hardware digits and Enter submit
02:00 +561: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: not found → "Edit number" restores the digits
02:01 +562: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: slow lookup: "Still looking …" and Cancel
02:01 +563: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: offline: button disabled with the offline caption
02:02 +564: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: close returns to Ready and discards the digits
02:02 +565: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: German copy and grouped read-out
02:02 +566: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: compact height lays out without overflow
02:02 +567: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: compact height at 200 % text lays out without overflow
02:03 +568: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: tablet landscape (two panes) lays out without overflow
02:03 +569: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: tablet landscape at 200 % text lays out without overflow
02:03 +570: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s11_manual_entry_test.dart: dark theme
02:03 +571: loading /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart
02:04 +571: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 Android · V1 listening TopBar, instruction and the two alternatives (EN)
02:05 +572: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 Android · V1 listening German and BHS copy
02:05 +573: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 Android · V1 listening card read → looking up → skeleton after 150 ms → Charge
02:05 +574: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 Android · V1 listening slow lookup: "Still looking …" at 3 s, Cancel returns to V1
02:06 +575: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 Android · V1 listening three failed reads show the hold-still hint for 2 s
02:06 +576: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 Android · V1 listening a tag that is not a gift card sends no request
02:06 +577: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · V8 first card of the shift Android: tip replaces the hint until the first read today
02:06 +578: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · V8 first card of the shift iPhone: tip in place of the hint
02:06 +579: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · V6 offline enters after 2 s, disables scan entry points, recovers with "Connected again"
02:06 +580: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · V6 offline a card read before offline is confirmed shows the L09 line
02:07 +581: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · V6 offline iPhone offline: Scan card disabled
02:07 +582: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · S16 NFC states V4 NFC off: deep link, then back on with haptic.select
02:07 +583: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · S16 NFC states NFC off + offline shows NFC off with the offline banner (priority V4 > V6)
02:07 +584: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · S16 NFC states V5 no NFC (Android phone): QR first, no NFC animation
02:07 +585: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 iPhone · V2 Scan card opens the system sheet once; timeout hint for 6 s
02:07 +586: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 iPhone · V2 P09: NFC temporarily unavailable → snackbar
02:07 +587: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 iPhone · V2 Scan card sits below the thumb-zone line
02:08 +588: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 iPhone · V2 German copy
02:08 +589: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 iPhone · V2 iPad: QR-first, secondary above primary, no NFC wording
02:08 +590: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · V7 maintenance banner shows the server text, never moves the buttons, dismissible
02:08 +591: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · navigation Card number and QR code open S11 / S12
02:08 +592: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · navigation Recent and Menu open sheets and pause reader mode
02:09 +593: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · responsive, text size, theme, semantics Android compact at 200 % text lays out without overflow
02:09 +594: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · responsive, text size, theme, semantics iPhone compact at 200 % text lays out without overflow
02:09 +595: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · responsive, text size, theme, semantics Android tablet landscape at 200 % text lays out without overflow
02:09 +596: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · responsive, text size, theme, semantics secondary buttons stack at 200 % on a compact phone
02:09 +597: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · responsive, text size, theme, semantics tablet landscape: content column max 480, centred
02:09 +598: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · responsive, text size, theme, semantics dark theme
02:09 +599: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · responsive, text size, theme, semantics semantics: header + live region title, labelled TopBar
02:09 +600: /home/claude/giftcard-pro/waiter-app/test/screens/scan/s05_ready_test.dart: S05 · responsive, text size, theme, semantics Reduce Motion keeps the rings static
02:09 +601: All tests passed!
```
