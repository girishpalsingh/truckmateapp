-- Create rate_cons table
create table public.rate_cons (
    id uuid not null default gen_random_uuid(),
    organization_id uuid not null references public.organizations(id),
    
    broker_name text,
    broker_mc_number text,
    load_id text,
    
    carrier_name text,
    carrier_mc_number text,
    
    pickup_address text,
    pickup_date date,
    pickup_time time,
    
    delivery_address text,
    delivery_date date,
    delivery_time time,
    
    rate_amount numeric,
    commodity text,
    weight numeric,
    
    detention_limit numeric, -- assuming hours
    detention_amount_per_hour numeric,
    
    fine_amount numeric,
    fine_description text,

    contacts jsonb,
    notes text,
    instructions text,
    parsed_text text,
    
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    
    constraint rate_cons_pkey primary key (id)
);

-- Enable RLS
alter table public.rate_cons enable row level security;

-- Create Policy
create policy "Users can only access rate_cons for their organization"
    on public.rate_cons
    for all
    using (
        organization_id in (
            select organization_id 
            from public.profiles 
            where id = auth.uid()
        )
    );
