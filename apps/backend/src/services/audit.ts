// /Users/roman/Developer/iosbrowser/apps/backend/src/services/audit.ts
import type { SupabaseClient } from "@supabase/supabase-js";

export type AuditEventInput = {
  workspaceId: string;
  actorUserId: string;
  action: string;
  targetType: string;
  targetId?: string;
  metadata?: Record<string, unknown>;
};

export async function writeAuditEvent(supabase: SupabaseClient, event: AuditEventInput): Promise<void> {
  const { error } = await supabase.from("audit_events").insert({
    workspace_id: event.workspaceId,
    actor_user_id: event.actorUserId,
    action: event.action,
    target_type: event.targetType,
    target_id: event.targetId ?? null,
    metadata: event.metadata ?? {}
  });
  if (error) throw error;
}
