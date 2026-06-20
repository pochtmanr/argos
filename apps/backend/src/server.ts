// /Users/roman/Developer/iosbrowser/apps/backend/src/server.ts
import Fastify from "fastify";
import cors from "@fastify/cors";
import websocket from "@fastify/websocket";
import { createLogger } from "@browser/observability";
import { loadEnv } from "./config/env.js";
import { createRedis } from "./db/redis.js";
import { createSupabaseAdmin } from "./db/supabase.js";
import { registerAuth } from "./security/auth.js";
import { registerAiRoutes } from "./routes/ai.js";
import { registerBillingRoutes } from "./routes/billing.js";
import { registerProfileRoutes } from "./routes/profiles.js";
import { registerSyncRoutes } from "./routes/sync.js";
import { registerWebsocketEvents } from "./ws/events.js";

const env = loadEnv();
const logger = createLogger("backend");
const server = Fastify({ logger: false, requestIdHeader: "x-request-id" });
const supabase = createSupabaseAdmin(env);
const redis = createRedis(env);

await server.register(cors, { origin: true, credentials: true });
await server.register(websocket);

server.get("/health", async () => ({ ok: true, service: "browser-backend" }));
registerAuth(server, supabase);
registerProfileRoutes(server, supabase);
registerSyncRoutes(server, supabase, redis);
registerAiRoutes(server, supabase);
registerBillingRoutes(server, supabase);
registerWebsocketEvents(server, redis);

server.setErrorHandler(async (error, _request, reply) => {
  logger.error("request failed", { message: error.message, stack: error.stack });
  await reply.code(500).send({ code: "INTERNAL_SERVER_ERROR", message: "Request failed" });
});

await server.listen({ host: "0.0.0.0", port: env.PORT });
logger.info("backend listening", { port: env.PORT });
