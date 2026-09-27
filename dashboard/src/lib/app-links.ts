/**
 * Universal Links (iOS) and App Links (Android) for the native waiter app: a card link /c/{token}
 * opens GiftCard Waiter directly on a phone where it is installed. Everyone else gets the normal
 * balance page. Configured with environment variables; without them both files answer 404.
 */

/** Reads WAITER_IOS_APP_IDS, WAITER_ANDROID_PACKAGE and WAITER_ANDROID_CERT_SHA256 (comma-separated lists). */
export type AppLinkEnv = Record<string, string | undefined>

const CARD_PATH = "/c/*"

function list(value: string | undefined): string[] {
  return (value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean)
}

/** apple-app-site-association: app IDs are "TEAMID.bundle.identifier". */
export function appleAppSiteAssociation(env: AppLinkEnv) {
  const appIDs = list(env.WAITER_IOS_APP_IDS).filter((id) => /^[A-Z0-9]{10}\.[A-Za-z0-9.\-]+$/.test(id))
  if (appIDs.length === 0) return null

  return {
    applinks: {
      details: [{ appIDs, components: [{ "/": CARD_PATH, comment: "Gift card links open GiftCard Waiter" }] }],
    },
  }
}

/** assetlinks.json: SHA-256 fingerprints as printed by keytool / Play Console ("AB:CD:…"). */
export function assetLinks(env: AppLinkEnv) {
  const packageName = env.WAITER_ANDROID_PACKAGE?.trim() ?? ""
  const fingerprints = list(env.WAITER_ANDROID_CERT_SHA256)
    .map((fp) => fp.toUpperCase())
    .filter((fp) => /^([0-9A-F]{2}:){31}[0-9A-F]{2}$/.test(fp))
  if (!/^[a-zA-Z][\w]*(\.[a-zA-Z][\w]*)+$/.test(packageName) || fingerprints.length === 0) return null

  return [
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: { namespace: "android_app", package_name: packageName, sha256_cert_fingerprints: fingerprints },
    },
  ]
}

export function jsonOrNotFound(body: unknown): Response {
  if (body === null) return new Response("Not found", { status: 404 })

  return Response.json(body, { headers: { "Cache-Control": "public, max-age=3600" } })
}
