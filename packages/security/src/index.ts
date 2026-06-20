// /Users/roman/Developer/iosbrowser/packages/security/src/index.ts
import type { AiActionRequest, AiPermission } from "@browser/api-contracts";

export type AiPolicy = {
  allowedOrigins: string[];
  deniedOrigins: string[];
  autoApprovedPermissions: AiPermission[];
  approvalRequiredPermissions: AiPermission[];
};

export type PermissionDecision = {
  allowed: boolean;
  requiresApproval: boolean;
  reasons: string[];
};

export function evaluateAiAction(request: AiActionRequest, policy: AiPolicy): PermissionDecision {
  const reasons: string[] = [];
  const origin = new URL(request.origin).origin;

  if (policy.deniedOrigins.includes(origin)) {
    reasons.push(`origin denied: ${origin}`);
  }

  if (policy.allowedOrigins.length > 0 && !policy.allowedOrigins.includes(origin)) {
    reasons.push(`origin not allowlisted: ${origin}`);
  }

  for (const permission of request.permissions) {
    if (!policy.autoApprovedPermissions.includes(permission) && !policy.approvalRequiredPermissions.includes(permission)) {
      reasons.push(`permission not granted by policy: ${permission}`);
    }
  }

  const requiresApproval = request.requiresApproval || request.permissions.some((permission) => policy.approvalRequiredPermissions.includes(permission));
  return { allowed: reasons.length === 0, requiresApproval, reasons };
}

export function redactSecret(value: string): string {
  if (value.length <= 8) return "********";
  return `${value.slice(0, 4)}…${value.slice(-4)}`;
}
