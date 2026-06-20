// /Users/roman/Developer/iosbrowser/packages/api-contracts/src/index.ts
import { z } from "zod";

export const Uuid = z.string().uuid();
export const UrlString = z.string().url();

export const SubscriptionTier = z.enum(["free", "pro", "team", "enterprise"]);
export type SubscriptionTier = z.infer<typeof SubscriptionTier>;

export const ProxyProtocol = z.enum(["http", "https", "socks5", "ssh"]);
export type ProxyProtocol = z.infer<typeof ProxyProtocol>;

export const ProxyConfig = z.object({
  id: Uuid.optional(),
  protocol: ProxyProtocol,
  host: z.string().min(1).max(255),
  port: z.number().int().min(1).max(65535),
  username: z.string().min(1).max(255).optional(),
  passwordRef: z.string().min(1).max(255).optional(),
  sshKeyRef: z.string().min(1).max(255).optional(),
  bypassRules: z.array(z.string().min(1)).default([])
});
export type ProxyConfig = z.infer<typeof ProxyConfig>;

export const BrowserProfile = z.object({
  id: Uuid,
  workspaceId: Uuid,
  ownerUserId: Uuid,
  displayName: z.string().min(1).max(120),
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/),
  proxyId: Uuid.nullable(),
  vaultNamespace: z.string().min(8).max(128),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime()
});
export type BrowserProfile = z.infer<typeof BrowserProfile>;

export const AiPermission = z.enum([
  "tabs:read",
  "tabs:navigate",
  "page:summarize",
  "forms:fill",
  "forms:submit",
  "clipboard:write",
  "vault:read",
  "downloads:create"
]);
export type AiPermission = z.infer<typeof AiPermission>;

export const AiActionRequest = z.object({
  id: Uuid,
  workspaceId: Uuid,
  profileId: Uuid,
  tabId: z.string().min(1),
  origin: z.string().min(1),
  requestedByUserId: Uuid,
  permissions: z.array(AiPermission).min(1),
  instruction: z.string().min(1).max(8000),
  requiresApproval: z.boolean().default(true)
});
export type AiActionRequest = z.infer<typeof AiActionRequest>;

export const SyncMutationType = z.enum([
  "profile.created",
  "profile.updated",
  "profile.deleted",
  "proxy.updated",
  "workspace.updated",
  "vault.ref.updated",
  "ai.policy.updated"
]);
export type SyncMutationType = z.infer<typeof SyncMutationType>;

export const SyncMutation = z.object({
  id: Uuid,
  workspaceId: Uuid,
  deviceId: Uuid,
  profileId: Uuid.optional(),
  type: SyncMutationType,
  lamportClock: z.number().int().nonnegative(),
  payload: z.record(z.unknown()),
  createdAt: z.string().datetime()
});
export type SyncMutation = z.infer<typeof SyncMutation>;

export const WebsocketEvent = z.discriminatedUnion("type", [
  z.object({ type: z.literal("sync.mutation"), data: SyncMutation }),
  z.object({ type: z.literal("profile.updated"), data: BrowserProfile }),
  z.object({ type: z.literal("ai.action.status"), data: z.object({ actionId: Uuid, status: z.enum(["queued", "approved", "denied", "running", "completed", "failed"]) }) }),
  z.object({ type: z.literal("billing.entitlement.updated"), data: z.object({ workspaceId: Uuid, tier: SubscriptionTier, active: z.boolean() }) })
]);
export type WebsocketEvent = z.infer<typeof WebsocketEvent>;

export const ApiError = z.object({
  code: z.string(),
  message: z.string(),
  requestId: z.string().optional()
});
export type ApiError = z.infer<typeof ApiError>;
