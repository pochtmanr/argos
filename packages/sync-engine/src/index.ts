// /Users/roman/Developer/iosbrowser/packages/sync-engine/src/index.ts
import type { SyncMutation, SyncMutationType } from "@browser/api-contracts";

export type SyncCursor = {
  workspaceId: string;
  deviceId: string;
  lastLamportClock: number;
  lastMutationId?: string;
};

export function nextLamportClock(cursor: SyncCursor, remoteClock?: number): number {
  return Math.max(cursor.lastLamportClock, remoteClock ?? 0) + 1;
}

export function createMutation(input: {
  id: string;
  workspaceId: string;
  deviceId: string;
  profileId?: string;
  type: SyncMutationType;
  lamportClock: number;
  payload: Record<string, unknown>;
  createdAt?: Date;
}): SyncMutation {
  const mutation: SyncMutation = {
    id: input.id,
    workspaceId: input.workspaceId,
    deviceId: input.deviceId,
    type: input.type,
    lamportClock: input.lamportClock,
    payload: input.payload,
    createdAt: (input.createdAt ?? new Date()).toISOString()
  };
  if (input.profileId) {
    mutation.profileId = input.profileId;
  }
  return mutation;
}
