"use client"

import { useState, type ReactNode } from "react"
import { MutationCache, QueryCache, QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { ThemeProvider } from "next-themes"
import { Toaster } from "@/components/ui/sonner"
import { TooltipProvider } from "@/components/ui/tooltip"
import { ApiError } from "@/lib/api/client"
import { AuthProvider, SESSION_QUERY_KEY } from "@/lib/auth"
import { ConfirmProvider } from "@/components/common/confirm"
import { I18nProvider } from "@/lib/i18n"

export function Providers({ children, nonce }: { children: ReactNode; nonce?: string }) {
  const [client] = useState(() => {
    const onAuthError = (error: unknown) => {
      // Session expired while the app was open: drop the cached session so guards redirect to /login.
      if (error instanceof ApiError && error.status === 401) {
        client.setQueryData(SESSION_QUERY_KEY, null)
      }
    }
    const client: QueryClient = new QueryClient({
      queryCache: new QueryCache({ onError: onAuthError }),
      mutationCache: new MutationCache({ onError: onAuthError }),
      defaultOptions: {
        queries: {
          staleTime: 30_000,
          refetchOnWindowFocus: true,
          retry: (count, error) => !(error instanceof ApiError && error.status < 500) && count < 2,
        },
        mutations: { retry: false },
      },
    })
    return client
  })

  return (
    <QueryClientProvider client={client}>
      <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange nonce={nonce}>
        <TooltipProvider delayDuration={200}>
          <AuthProvider>
            <I18nProvider>
              <ConfirmProvider>{children}</ConfirmProvider>
            </I18nProvider>
          </AuthProvider>
          <Toaster position="top-center" richColors closeButton />
        </TooltipProvider>
      </ThemeProvider>
    </QueryClientProvider>
  )
}
