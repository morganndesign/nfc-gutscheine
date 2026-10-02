import type { Metadata, Viewport } from "next"
import { GeistSans } from "geist/font/sans"
import { GeistMono } from "geist/font/mono"
import { Providers } from "@/app/providers"
import "./globals.css"

export const metadata: Metadata = {
  title: { default: "GiftCard Pro", template: "%s · GiftCard Pro" },
  description: "Gutscheine und Geschenkkarten für Restaurants: sicher verkaufen, einlösen und nachverfolgen.",
  applicationName: "GiftCard Pro",
  robots: { index: false, follow: false },
  manifest: "/manifest.webmanifest",
  appleWebApp: { capable: true, title: "GiftCard Pro", statusBarStyle: "default" },
}

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#141417" },
  ],
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="de" suppressHydrationWarning className={`${GeistSans.variable} ${GeistMono.variable}`}>
      <body className="bg-background text-foreground min-h-dvh font-sans antialiased">
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
