# /Users/roman/Developer/iosbrowser/docker/backend.Dockerfile
FROM node:22-bookworm-slim AS base
WORKDIR /repo
RUN corepack enable

FROM base AS deps
COPY package.json pnpm-workspace.yaml tsconfig.base.json ./
COPY apps/backend/package.json apps/backend/package.json
COPY packages packages
RUN pnpm install --frozen-lockfile=false

FROM deps AS build
COPY apps/backend apps/backend
RUN pnpm --filter @browser/backend build

FROM node:22-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /repo/apps/backend/dist ./dist
COPY --from=deps /repo/node_modules ./node_modules
EXPOSE 8080
CMD ["node", "dist/server.js"]
