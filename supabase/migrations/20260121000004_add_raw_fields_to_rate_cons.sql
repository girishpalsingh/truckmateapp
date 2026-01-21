-- Add raw text columns to rate_cons table
alter table public.rate_cons
add column if not exists rate_amount_raw text,
add column if not exists weight_raw text,
add column if not exists detention_limit_raw text,
add column if not exists detention_amount_per_hour_raw text,
add column if not exists fine_amount_raw text;
