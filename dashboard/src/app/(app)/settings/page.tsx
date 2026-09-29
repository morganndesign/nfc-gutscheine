"use client"

import { PageHeader } from "@/components/common/page-header"
import { RequirePermission } from "@/components/layout/auth-guard"
import { ApiTokens } from "@/components/settings/api-tokens"
import { VoucherSettingsForm } from "@/components/settings/voucher-settings-form"
import { NotificationTemplates } from "@/components/settings/notification-templates"
import { RestaurantProfileForm } from "@/components/settings/restaurant-profile-form"
import { Skeleton } from "@/components/ui/skeleton"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useRestaurantSettings } from "@/lib/api/hooks"
import { useAuth } from "@/lib/auth"

function SettingsContent() {
  const { can } = useAuth()
  const { data } = useRestaurantSettings()

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <PageHeader title="Settings" />
      {!data ? (
        <Skeleton className="h-96 w-full rounded-2xl" />
      ) : (
        <Tabs defaultValue="vouchers" className="space-y-4">
          <TabsList>
            <TabsTrigger value="vouchers">Vouchers</TabsTrigger>
            <TabsTrigger value="restaurant">Restaurant</TabsTrigger>
            <TabsTrigger value="emails">E-mails</TabsTrigger>
            {can("api_tokens.manage") ? <TabsTrigger value="api">API</TabsTrigger> : null}
          </TabsList>
          <TabsContent value="vouchers">{data.settings ? <VoucherSettingsForm settings={data.settings} /> : null}</TabsContent>
          <TabsContent value="restaurant">
            <RestaurantProfileForm restaurant={data} />
          </TabsContent>
          <TabsContent value="emails">
            <NotificationTemplates />
          </TabsContent>
          {can("api_tokens.manage") ? (
            <TabsContent value="api">
              <ApiTokens />
            </TabsContent>
          ) : null}
        </Tabs>
      )}
    </div>
  )
}

export default function SettingsPage() {
  return (
    <RequirePermission permission="settings.manage">
      <SettingsContent />
    </RequirePermission>
  )
}
