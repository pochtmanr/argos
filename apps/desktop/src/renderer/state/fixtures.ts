// /Users/roman/Developer/iosbrowser/apps/desktop/src/renderer/state/fixtures.ts
import type { BrowserProfile } from "@browser/api-contracts";

export const demoProfile: BrowserProfile = {
  id: "11111111-1111-4111-8111-111111111111",
  workspaceId: "22222222-2222-4222-8222-222222222222",
  ownerUserId: "33333333-3333-4333-8333-333333333333",
  displayName: "Research",
  color: "#2563eb",
  proxyId: null,
  vaultNamespace: "workspace-demo-research",
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString()
};
