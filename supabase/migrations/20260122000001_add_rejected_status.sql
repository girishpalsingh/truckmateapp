-- Add 'rejected' status to rate_con_status enum
ALTER TYPE public.rate_con_status ADD VALUE IF NOT EXISTS 'rejected';
