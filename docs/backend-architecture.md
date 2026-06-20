# Backend Architecture

Generated path: `/Users/roman/Developer/iosbrowser/docs/backend-architecture.md`

The backend is a Fastify service with small route modules and shared Zod contracts. Supabase/PostgreSQL is the source of truth. Redis handles websocket fan-out and short-lived coordination.

Routes validate request bodies at the boundary, write durable database state first, publish websocket events second, and record audit events for sensitive AI, vault, billing, and profile operations.
