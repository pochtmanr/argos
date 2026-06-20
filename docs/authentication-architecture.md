# Authentication Architecture

Generated path: `/Users/roman/Developer/iosbrowser/docs/authentication-architecture.md`

Supabase Auth owns email/password, Google login, and Apple login. Clients authenticate with Supabase and send bearer tokens to the backend. The backend verifies tokens with the Supabase admin client, then authorizes requests by workspace membership and RLS-protected data access.

Service-role keys stay server-side. Desktop and iOS never receive them. Billing, audit, and AI approval actions run through backend routes because they require privileged validation.
