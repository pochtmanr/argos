// /Users/roman/Developer/iosbrowser/apps/backend/src/routes/billing.ts
import type { FastifyInstance } from "fastify";
import type { SupabaseClient } from "@supabase/supabase-js";

export function registerBillingRoutes(server: FastifyInstance, supabase: SupabaseClient): void {
  server.get("/v1/workspaces/:workspaceId/entitlement", async (request) => {
    const { workspaceId } = request.params as { workspaceId: string };
    const { data, error } = await supabase
      .from("subscriptions")
      .select("tier,status,current_period_end")
      .eq("workspace_id", workspaceId)
      .maybeSingle();
    if (error) throw error;
    return {
      workspaceId,
      tier: data?.tier ?? "free",
      active: data?.status === "active" || data?.status === "trialing",
      currentPeriodEnd: data?.current_period_end ?? null
    };
  });
}
