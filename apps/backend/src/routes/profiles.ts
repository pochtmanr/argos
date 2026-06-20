// /Users/roman/Developer/iosbrowser/apps/backend/src/routes/profiles.ts
import type { FastifyInstance } from "fastify";
import type { SupabaseClient } from "@supabase/supabase-js";
import { BrowserProfile } from "@browser/api-contracts";

export function registerProfileRoutes(server: FastifyInstance, supabase: SupabaseClient): void {
  server.get("/v1/workspaces/:workspaceId/profiles", async (request) => {
    const { workspaceId } = request.params as { workspaceId: string };
    const { data, error } = await supabase
      .from("browser_profiles")
      .select("*")
      .eq("workspace_id", workspaceId)
      .order("created_at", { ascending: true });
    if (error) throw error;
    return data.map((row) =>
      BrowserProfile.parse({
        id: row.id,
        workspaceId: row.workspace_id,
        ownerUserId: row.owner_user_id,
        displayName: row.display_name,
        color: row.color,
        proxyId: row.proxy_id,
        vaultNamespace: row.vault_namespace,
        createdAt: row.created_at,
        updatedAt: row.updated_at
      })
    );
  });

  server.post("/v1/workspaces/:workspaceId/profiles", async (request, reply) => {
    const { workspaceId } = request.params as { workspaceId: string };
    const body = BrowserProfile.omit({ id: true, createdAt: true, updatedAt: true, workspaceId: true, ownerUserId: true }).parse(request.body);
    const { data, error } = await supabase
      .from("browser_profiles")
      .insert({
        workspace_id: workspaceId,
        owner_user_id: request.user.id,
        display_name: body.displayName,
        color: body.color,
        proxy_id: body.proxyId,
        vault_namespace: body.vaultNamespace
      })
      .select("*")
      .single();
    if (error) throw error;
    return reply.code(201).send(data);
  });
}
