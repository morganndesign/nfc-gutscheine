# Assets

Files for store listings and marketing that are **not** part of an app build.

| Folder | Contents | Made from |
|---|---|---|
| `store/play-store-icon-512.png` | Google Play listing icon (512 × 512) | `waiter-app/ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` |
| `store/app-store-icon-1024.png` | App Store icon (1024 × 1024, opaque) | same |

Not here, on purpose (they are inputs of a build and stay next to the code that uses them):
app icon sources `waiter-app/tool/brand/*.svg` (rendered by `waiter-app/tool/render_brand_assets.py`),
app sounds `waiter-app/tool/sounds_src/`, web app images `dashboard/public/`, README screenshots `docs/screenshots/`.

Still to be made for the stores: Play feature graphic (1024 × 500), phone and tablet screenshots, iPhone 6.9″ and
iPad 13″ screenshots — see [docs/MOBILE_RELEASE.md](../docs/MOBILE_RELEASE.md).
