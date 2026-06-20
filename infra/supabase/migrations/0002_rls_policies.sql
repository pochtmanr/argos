-- /Users/roman/Developer/iosbrowser/infra/supabase/migrations/0002_rls_policies.sql
alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.proxies enable row level security;
alter table public.browser_profiles enable row level security;
alter table public.ai_policies enable row level security;
alter table public.sync_devices enable row level security;
alter table public.sync_mutations enable row level security;
alter table public.vault_items enable row level security;
alter table public.subscriptions enable row level security;
alter table public.audit_events enable row level security;

create or replace function public.is_workspace_member(target_workspace_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.workspace_members member
    where member.workspace_id = target_workspace_id
      and member.user_id = auth.uid()
  );
$$;

create policy "members can read workspaces"
on public.workspaces for select
using (public.is_workspace_member(id));

create policy "owners can update workspaces"
on public.workspaces for update
using (owner_user_id = auth.uid());

create policy "members can read membership"
on public.workspace_members for select
using (public.is_workspace_member(workspace_id));

create policy "members can read profiles"
on public.browser_profiles for select
using (public.is_workspace_member(workspace_id));

create policy "members can manage owned profiles"
on public.browser_profiles for all
using (public.is_workspace_member(workspace_id))
with check (public.is_workspace_member(workspace_id));

create policy "members can read proxies"
on public.proxies for select
using (public.is_workspace_member(workspace_id));

create policy "members can manage proxies"
on public.proxies for all
using (public.is_workspace_member(workspace_id))
with check (public.is_workspace_member(workspace_id));

create policy "members can read ai policies"
on public.ai_policies for select
using (public.is_workspace_member(workspace_id));

create policy "members can read sync devices"
on public.sync_devices for select
using (public.is_workspace_member(workspace_id));

create policy "members can write sync devices"
on public.sync_devices for insert
with check (public.is_workspace_member(workspace_id) and user_id = auth.uid());

create policy "members can read sync mutations"
on public.sync_mutations for select
using (public.is_workspace_member(workspace_id));

create policy "members can write sync mutations"
on public.sync_mutations for insert
with check (public.is_workspace_member(workspace_id));

create policy "members can read vault metadata"
on public.vault_items for select
using (public.is_workspace_member(workspace_id));

create policy "members can read subscriptions"
on public.subscriptions for select
using (public.is_workspace_member(workspace_id));

create policy "members can read audit events"
on public.audit_events for select
using (public.is_workspace_member(workspace_id));
