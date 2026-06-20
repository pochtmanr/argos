// /Users/roman/Developer/iosbrowser/apps/backend/src/routes/ai.ts
import type { FastifyInstance } from "fastify";
import type { SupabaseClient } from "@supabase/supabase-js";
import { AiActionRequest } from "@browser/api-contracts";
import { describeActionForAudit } from "@browser/ai-core";
import { evaluateAiAction, type AiPolicy } from "@browser/security";
import { writeAuditEvent } from "../services/audit.js";

const defaultPolicy: AiPolicy = {
  allowedOrigins: [],
  deniedOrigins: [],
  autoApprovedPermissions: ["tabs:read", "page:summarize"],
  approvalRequiredPermissions: ["tabs:navigate", "forms:fill", "forms:submit", "clipboard:write", "vault:read", "downloads:create"]
};

export function registerAiRoutes(server: FastifyInstance, supabase: SupabaseClient): void {
  server.post("/v1/ai/actions", async (request, reply) => {
    const action = AiActionRequest.parse(request.body);
    const decision = evaluateAiAction(action, defaultPolicy);
    await writeAuditEvent(supabase, {
      workspaceId: action.workspaceId,
      actorUserId: request.user.id,
      action: "ai.action.requested",
      targetType: "browser_tab",
      targetId: action.tabId,
      metadata: { description: describeActionForAudit(action), decision }
    });

    if (!decision.allowed) {
      return reply.code(403).send({ code: "AI_ACTION_DENIED", message: decision.reasons.join("; ") });
    }
    return reply.code(202).send({ actionId: action.id, status: decision.requiresApproval ? "queued_for_approval" : "approved" });
  });
}
