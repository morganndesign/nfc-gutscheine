import type { ReactNode } from "react"
import { CreditCard } from "lucide-react"

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <div className="bg-surface flex min-h-dvh flex-col">
      <main className="flex flex-1 items-center justify-center px-4 py-12">
        <div className="w-full max-w-sm">
          <div className="mb-8 flex flex-col items-center gap-3 text-center">
            <div className="bg-primary text-primary-foreground flex size-12 items-center justify-center rounded-2xl shadow-sm">
              <CreditCard className="size-6" aria-hidden />
            </div>
            <span className="text-muted-foreground text-sm font-medium">GiftCard Pro</span>
          </div>
          {children}
        </div>
      </main>
      <footer className="text-muted-foreground pb-6 text-center text-xs">© {new Date().getFullYear()} GiftCard Pro</footer>
    </div>
  )
}
