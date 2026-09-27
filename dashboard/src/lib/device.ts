const KEY = "gcp.device-id"

/**
 * A random, persistent identifier for this browser/device. It is not a fingerprint:
 * it carries no hardware information and can be reset by clearing site data.
 */
export function getDeviceId(): string | null {
  if (typeof window === "undefined") return null
  try {
    let id = localStorage.getItem(KEY)
    if (!id) {
      id = crypto.randomUUID()
      localStorage.setItem(KEY, id)
    }
    return id
  } catch {
    return null
  }
}
