// /Users/roman/Developer/iosbrowser/apps/backend/src/ws/events.ts
import type { FastifyInstance } from "fastify";
import type Redis from "ioredis";
import { WebsocketEvent } from "@browser/api-contracts";

export function registerWebsocketEvents(server: FastifyInstance, redis: Redis): void {
  server.get("/ws", { websocket: true }, (socket, request) => {
    const workspaceId = String(request.query && (request.query as { workspaceId?: string }).workspaceId);
    const channel = `workspace:${workspaceId}:events`;
    const subscriber = redis.duplicate();

    subscriber.subscribe(channel).catch((error) => socket.close(1011, error.message));
    subscriber.on("message", (_channel, payload) => {
      const event = WebsocketEvent.parse(JSON.parse(payload));
      socket.send(JSON.stringify(event));
    });

    socket.on("close", () => {
      subscriber.unsubscribe(channel).finally(() => subscriber.disconnect());
    });
  });
}

export async function publishWorkspaceEvent(redis: Redis, workspaceId: string, event: unknown): Promise<void> {
  WebsocketEvent.parse(event);
  await redis.publish(`workspace:${workspaceId}:events`, JSON.stringify(event));
}
