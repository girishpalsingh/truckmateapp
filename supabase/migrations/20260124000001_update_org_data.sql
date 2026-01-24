-- Migration to update organization addresses and logo
-- This applies the data that was added to seed.sql to existing records

-- 1. Highway Heroes Trucking
UPDATE public.organizations
SET 
    registered_address = '{"address_line1": "123 Trucker Lane", "city": "Fresno", "state": "CA", "zip": "93706", "country": "USA"}',
    mailing_address = '{"address_line1": "PO Box 99", "city": "Fresno", "state": "CA", "zip": "93706", "country": "USA"}',
    logo_image_link = 'Gemini_Generated_Image_oqnanioqnanioqna.png'
WHERE id = '11111111-1111-1111-1111-111111111111';

-- 2. Pacific Coast Freight
UPDATE public.organizations
SET 
    registered_address = '{"address_line1": "456 Ocean Blvd", "city": "Seattle", "state": "WA", "zip": "98101", "country": "USA"}',
    mailing_address = '{"address_line1": "456 Ocean Blvd", "city": "Seattle", "state": "WA", "zip": "98101", "country": "USA"}'
WHERE id = '11111111-1111-1111-1111-111111111112';
