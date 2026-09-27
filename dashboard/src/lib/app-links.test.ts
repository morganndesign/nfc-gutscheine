import assert from "node:assert/strict"
import { test } from "node:test"
import { appleAppSiteAssociation, assetLinks } from "./app-links.ts"

const FP = Array.from({ length: 32 }, (_, i) => i.toString(16).padStart(2, "0")).join(":")

test("apple-app-site-association lists valid app IDs for card links only", () => {
  assert.equal(appleAppSiteAssociation({}), null)
  assert.equal(appleAppSiteAssociation({ WAITER_IOS_APP_IDS: "not-an-id" }), null)

  const body = appleAppSiteAssociation({ WAITER_IOS_APP_IDS: "ABCDE12345.eu.tapredeem.waiter, junk" })
  assert.deepEqual(body?.applinks.details[0].appIDs, ["ABCDE12345.eu.tapredeem.waiter"])
  assert.equal(body?.applinks.details[0].components[0]["/"], "/c/*")
})

test("assetlinks.json needs a package name and a SHA-256 fingerprint", () => {
  assert.equal(assetLinks({ WAITER_ANDROID_PACKAGE: "eu.tapredeem.waiter" }), null)
  assert.equal(assetLinks({ WAITER_ANDROID_PACKAGE: "nope", WAITER_ANDROID_CERT_SHA256: FP }), null)

  const body = assetLinks({ WAITER_ANDROID_PACKAGE: "eu.tapredeem.waiter", WAITER_ANDROID_CERT_SHA256: `${FP},bad` })
  assert.equal(body?.[0].target.package_name, "eu.tapredeem.waiter")
  assert.deepEqual(body?.[0].target.sha256_cert_fingerprints, [FP.toUpperCase()])
})
