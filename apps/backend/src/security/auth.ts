// /Users/roman/Developer/iosbrowser/apps/backend/src/security/auth.ts
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { SupabaseClient, User } from "@supabase/supabase-js";

declare module "fastify" {
  interface FastifyRequest {
    user: User;
  }
}

export function registerAuth(server: FastifyInstance, supabase: SupabaseClient): void {
  server.decorateRequest("user", null);

  server.addHook("preHandler", async (request: FastifyRequest, reply: FastifyReply) => {
    if (request.routeOptions.url === "/health") return;
    const authorization = request.headers.authorization;
    if (!authorization?.startsWith("Bearer ")) {
      await reply.code(401).send({ code: "UNAUTHENTICATED", message: "Missing bearer token" });
      return;
    }

    const token = authorization.slice("Bearer ".length);
    const { data, error } = await supabase.auth.getUser(token);
    if (error || !data.user) {
      await reply.code(401).send({ code: "UNAUTHENTICATED", message: "Invalid bearer token" });
      return;
    }

    request.user = data.user;
  });
}
