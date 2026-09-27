"use client"

import { useEffect } from "react"
import { useRouter } from "next/navigation"
import { FullScreenLoader } from "@/components/layout/auth-guard"
import { homeFor, useAuth } from "@/lib/auth"

export default function Home() {
  const { user, isLoading } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (isLoading) return
    router.replace(user ? homeFor(user) : "/login")
  }, [user, isLoading, router])

  return <FullScreenLoader />
}
