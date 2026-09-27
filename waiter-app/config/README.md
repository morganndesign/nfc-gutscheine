# Environments

One file per environment. The app reads these values at build time
(`--dart-define-from-file`); nothing about servers is written in the Dart code.

| File | APP_ENV | Server | App id / name on Android |
|---|---|---|---|
| `development.json` | development | your computer: `http://10.0.2.2:8000/api/v1` (= the computer, seen from the Android emulator) | `eu.tapredeem.waiter.dev` · GiftCard Waiter Dev |
| `staging.json` | staging | **empty until a staging server exists** — fill in `https://<staging-domain>/api/v1` | `eu.tapredeem.waiter.staging` · GiftCard Waiter Staging |
| `production.json` | production | `https://app.giftcardpro.at/api/v1` (**works only once the domain is registered and the server deployed**) | `eu.tapredeem.waiter` · GiftCard Waiter |

Keys: `APP_ENV`, `API_BASE_URL` (must end in `/api/v1`; http only in development), `CARD_DOMAINS` (hosts of the
card links, comma-separated — must match `CARD_BASE_URL` of the backend), `APP_STORE_URL`, `PLAY_STORE_URL`.

**Your own addresses:** copy a file to `<environment>.local.json` (e.g. `development.local.json` with
`http://192.168.1.20:8000/api/v1`). `tool/release.sh` prefers the `.local.json` file; for `flutter run` pass it
with `--dart-define-from-file=config/development.local.json`. `.local.json` files are not committed.

**Switching without rebuilding:** development and staging builds show a corner badge (DEV / STAGING). Long-press
it — or tap *Change server* on the connection problem screen — to enter another server address. Production builds
cannot change their server.

Run: `flutter run --dart-define-from-file=config/development.json`
Build: `tool/release.sh android development` (or `staging`, `production`)
