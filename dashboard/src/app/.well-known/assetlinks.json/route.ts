import { assetLinks, jsonOrNotFound } from "@/lib/app-links"

// Read at request time so the same image serves every environment.
export const dynamic = "force-dynamic"

export function GET() {
  return jsonOrNotFound(assetLinks(process.env))
}
