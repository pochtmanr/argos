-- /Users/roman/Developer/iosbrowser/infra/supabase/migrations/0001_core_schema.sql
create extension if not exists pgcrypto;

create type subscription_tier as enum ('free', 'pro', 'team', 'enterprise');
create type subscription_status as enum ('incomplete', 'trialing', 'active', 'past_due', 'canceled');
create type proxy_protocol as enum ('http', 'https', 'socks5', 'ssh');
create type sync_mutation_type as enum ('profile.created', 'profile.updated', 'profile.deleted', 'proxy.updated', 'workspace.updated', 'vault.ref.updated', 'ai.policy.updated');

create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'member', 'viewer')),
  created_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create table public.proxies (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  protocol proxy_protocol not null,
  host text not null,
  port integer not null check (port between 1 and 65535),
  username text,
  password_ref text,
  ssh_key_ref text,
  bypass_rules text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.browser_profiles (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 120),
  color text not null check (color ~ '^#[0-9a-fA-F]{6}$'),
  proxy_id uuid references public.proxies(id) on delete set null,
  vault_namespace text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workspace_id, vault_namespace)
);

create table public.ai_policies (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  profile_id uuid references public.browser_profiles(id) on delete cascade,
  allowed_origins text[] not null default '{}',
  denied_origins text[] not null default '{}',
  auto_approved_permissions text[] not null default '{tabs:read,page:summarize}',
  approval_required_permissions text[] not null default '{tabs:navigate,forms:fill,forms:submit,clipboard:write,vault:read,downloads:create}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.sync_devices (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  platform text not null check (platform in ('macos', 'ios', 'backend')),
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.sync_mutations (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  device_id uuid not null references public.sync_devices(id) on delete cascade,
  profile_id uuid references public.browser_profiles(id) on delete cascade,
  type sync_mutation_type not null,
  lamport_clock bigint not null,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  unique (workspace_id, device_id, lamport_clock)
);

create table public.vault_items (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  profile_id uuid references public.browser_profiles(id) on delete cascade,
  item_type text not null check (item_type in ('credential', 'cookie_key', 'proxy_secret', 'ssh_key', 'ai_token')),
  encrypted_payload jsonb not null,
  key_id text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null unique references public.workspaces(id) on delete cascade,
  tier subscription_tier not null default 'free',
  status subscription_status not null default 'active',
  provider_customer_id text,
  provider_subscription_id text,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index browser_profiles_workspace_idx on public.browser_profiles(workspace_id);
create index sync_mutations_workspace_clock_idx on public.sync_mutations(workspace_id, lamport_clock);
create index audit_events_workspace_created_idx on public.audit_events(workspace_id, created_at desc);
