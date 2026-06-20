# API Contracts

Generated path: `/Users/roman/Developer/iosbrowser/docs/api-contracts.md`

## REST

- `GET /health`: service health.
- `GET /v1/workspaces/:workspaceId/profiles`: list profiles visible to the authenticated user.
- `POST /v1/workspaces/:workspaceId/profiles`: create a profile in the workspace.
- `GET /v1/workspaces/:workspaceId/sync/mutations?after=:clock`: fetch sync mutations after a Lamport clock.
- `POST /v1/workspaces/:workspaceId/sync/mutations`: append a mutation and publish websocket event.
- `POST /v1/ai/actions`: request a permissioned AI browser action.
- `GET /v1/workspaces/:workspaceId/entitlement`: read subscription entitlement.

## Websocket

- `GET /ws?workspaceId=:workspaceId`
- Events are validated by `packages/api-contracts/src/index.ts` before publish and before send.
