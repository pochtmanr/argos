// /Users/roman/Developer/iosbrowser/packages/profile-engine/src/index.ts
import type { BrowserProfile } from "@browser/api-contracts";

export type ProfileRuntimeTarget = "electron" | "wkwebview";

export type ProfileContainer = {
  profile: BrowserProfile;
  target: ProfileRuntimeTarget;
  storagePartition: string;
  cookieNamespace: string;
  cacheNamespace: string;
};

export function createProfileContainer(profile: BrowserProfile, target: ProfileRuntimeTarget): ProfileContainer {
  const storagePartition = target === "electron" ? `persist:profile-${profile.id}` : `wk-profile-${profile.id}`;
  return {
    profile,
    target,
    storagePartition,
    cookieNamespace: `${profile.workspaceId}:${profile.id}:cookies`,
    cacheNamespace: `${profile.workspaceId}:${profile.id}:cache`
  };
}

export function assertProfileOwnership(profile: BrowserProfile, workspaceId: string): void {
  if (profile.workspaceId !== workspaceId) {
    throw new Error("Profile does not belong to the active workspace");
  }
}
