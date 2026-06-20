# DevOps And Observability

Generated path: `/Users/roman/Developer/iosbrowser/docs/devops-observability.md`

CI runs TypeScript typechecking, package builds, Swift package build, and CodeQL. Docker Compose runs the backend and Redis for local integration.

Logging uses structured JSON events with service names, levels, timestamps, and contextual metadata. Production deployments should forward logs to an indexed store and attach request IDs, user IDs, workspace IDs, and audit event IDs where safe.
