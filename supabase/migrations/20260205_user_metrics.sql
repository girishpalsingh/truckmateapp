-- Create user_metrics table
create table if not exists public.user_metrics (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade not null,
  organization_id uuid references public.organizations(id) on delete cascade,
  rate_cons_uploaded int8 default 0,
  rate_cons_processed int8 default 0,
  dispatch_sheets_generated int8 default 0,
  dispatch_sheets_downloaded int8 default 0,
  emails_sent int8 default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id)
);

-- Create user_activity_log table
create table if not exists public.user_activity_log (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade not null,
  organization_id uuid references public.organizations(id) on delete set null,
  action_type text not null, -- 'rate_con_uploaded', 'rate_con_processed', etc.
  resource_id text, -- ID of the related resource (rate_con_id, document_id, etc.)
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

-- Enable RLS
alter table public.user_metrics enable row level security;
alter table public.user_activity_log enable row level security;

-- Policies for user_metrics
create policy "Users can view own metrics"
  on public.user_metrics for select
  to authenticated
  using (user_id = auth.uid());

-- Policies for user_activity_log
create policy "Users can view own activity log"
  on public.user_activity_log for select
  to authenticated
  using (user_id = auth.uid());

-- RPC to increment metrics (Server-side tracking)
create or replace function public.increment_user_metric(
  action_name text,
  resource_id_param text default null,
  metadata_param jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer -- Runs with elevated privileges to update metrics
as $$
declare
  curr_user_id uuid;
  curr_org_id uuid;
  column_name text;
begin
  -- Get current user
  curr_user_id := auth.uid();
  if curr_user_id is null then
    -- Allow passing user_id in metadata for system triggers (like database triggers where auth.uid() might be null or different)
    if metadata_param ? 'user_id' then
       curr_user_id := (metadata_param->>'user_id')::uuid;
    else
       raise exception 'User not authenticated';
    end if;
  end if;

  -- Get user's organization (optional, best effort)
  select organization_id into curr_org_id
  from public.profiles
  where id = curr_user_id;

  -- Map action to column
  case action_name
    when 'rate_con_uploaded' then column_name := 'rate_cons_uploaded';
    when 'rate_con_processed' then column_name := 'rate_cons_processed';
    when 'dispatch_sheet_generated' then column_name := 'dispatch_sheets_generated';
    when 'dispatch_sheet_downloaded' then column_name := 'dispatch_sheets_downloaded';
    when 'email_sent' then column_name := 'emails_sent';
    else raise exception 'Invalid action name: %', action_name;
  end case;

  -- Upsert into user_metrics
  execute format('
    insert into public.user_metrics (user_id, organization_id, %I)
    values ($1, $2, 1)
    on conflict (user_id) do update
    set %I = user_metrics.%I + 1,
        updated_at = now();
  ', column_name, column_name, column_name)
  using curr_user_id, curr_org_id;

  -- Insert into log
  insert into public.user_activity_log (user_id, organization_id, action_type, resource_id, metadata)
  values (curr_user_id, curr_org_id, action_name, resource_id_param, metadata_param);

end;
$$;
