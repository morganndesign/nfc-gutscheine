import { appleAppSiteAssociation, jsonOrNotFound } from "@/lib/app-links"

// Read at request time so the same image serves every environment.
export const dynamic = "force-dynamic"

export function GET() {
  return jsonOrNotFound(appleAppSiteAssociation(process.env))
}
