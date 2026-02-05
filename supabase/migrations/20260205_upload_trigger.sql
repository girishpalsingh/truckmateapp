-- Trigger function to track rate con uploads
create or replace function public.track_rate_con_upload()
returns trigger
language plpgsql
security definer
as $$
begin
  -- Only track if type is 'rate_con' and we have an uploaded_by user
  if NEW.type = 'rate_con' and NEW.uploaded_by is not null then
    -- Call the increment function
    -- access 'uploaded_by' as the user_id
    perform public.increment_user_metric(
      'rate_con_uploaded',
      NEW.id::text,
      jsonb_build_object('user_id', NEW.uploaded_by, 'source', 'trigger')
    );
  end if;
  return NEW;
end;
$$;

-- Create the trigger
drop trigger if exists on_rate_con_upload on public.documents;
create trigger on_rate_con_upload
after insert on public.documents
for each row
execute function public.track_rate_con_upload();
