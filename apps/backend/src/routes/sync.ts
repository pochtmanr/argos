// /Users/roman/Developer/iosbrowser/apps/backend/src/routes/sync.ts
import type { FastifyInstance } from "fastify";
import type { SupabaseClient } from "@supabase/supabase-js";
import type Redis from "ioredis";
import { SyncMutation } from "@browser/api-contracts";
import { publishWorkspaceEvent } from "../ws/events.js";

export function registerSyncRoutes(server: FastifyInstance, supabase: SupabaseClient, redis: Redis): void {
  server.get("/v1/workspaces/:workspaceId/sync/mutations", async (request) => {
    const { workspaceId } = request.params as { workspaceId: string };
    const after = Number((request.query as { after?: string }).after ?? 0);
    const { data, error } = await supabase
      .from("sync_mutations")
      .select("*")
      .eq("workspace_id", workspaceId)
      .gt("lamport_clock", after)
      .order("lamport_clock", { ascending: true })
      .limit(500);
    if (error) throw error;
    return data;
  });

  server.post("/v1/workspaces/:workspaceId/sync/mutations", async (request, reply) => {
    const { workspaceId } = request.params as { workspaceId: string };
    const mutation = SyncMutation.parse({ ...(request.body as object), workspaceId });
    const { error } = await supabase.from("sync_mutations").insert({
      id: mutation.id,
      workspace_id: mutation.workspaceId,
      device_id: mutation.deviceId,
      profile_id: mutation.profileId ?? null,
      type: mutation.type,
      lamport_clock: mutation.lamportClock,
      payload: mutation.payload,
      created_at: mutation.createdAt
    });
    if (error) throw error;
    await publishWorkspaceEvent(redis, workspaceId, { type: "sync.mutation", data: mutation });
    return reply.code(202).send({ accepted: true });
  });
}
