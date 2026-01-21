-- Create notifications table
create table public.notifications (
    id uuid not null default gen_random_uuid(),
    organization_id uuid not null references public.organizations(id),
    user_id uuid references auth.users(id), -- Optional: if specific to a user
    
    title text not null,
    body text,
    data jsonb, -- To store context like rate_con_id, document_id, etc.
    is_read boolean not null default false,
    
    created_at timestamp with time zone not null default now(),
    
    constraint notifications_pkey primary key (id)
);

-- Enable RLS
alter table public.notifications enable row level security;

-- Create Policy
create policy "Users can view notifications for their organization"
    on public.notifications
    for select
    using (
        organization_id in (
            select organization_id 
            from public.profiles 
            where id = auth.uid()
        )
    );

-- Policy to update is_read (users can mark their own or org notifications as read)
create policy "Users can update notifications for their organization"
    on public.notifications
    for update
    using (
        organization_id in (
            select organization_id 
            from public.profiles 
            where id = auth.uid()
        )
    );
