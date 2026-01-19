-- TruckMate Database Schema
-- Migration: 001_initial_schema.sql

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================
-- ENUMS
-- ============================================

CREATE TYPE user_role AS ENUM (
  'systemadmin',
  'orgadmin', 
  'owner',
  'manager',
  'dispatcher',
  'driver'
);

CREATE TYPE load_status AS ENUM (
  'assigned',
  'picked_up',
  'delivered',
  'invoiced',
  'paid'
);

CREATE TYPE trip_status AS ENUM (
  'deadhead',
  'active',
  'completed'
);

CREATE TYPE expense_category AS ENUM (
  'fuel',
  'tolls',
  'scale',
  'lumper',
  'repair',
  'maintenance',
  'food',
  'lodging',
  'fee',
  'detention_payout',
  'other'
);

CREATE TYPE document_type AS ENUM (
  'rate_con',
  'bol',
  'lumper_receipt',
  'fuel_receipt',
  'scale_ticket',
  'detention_evidence',
  'other'
);

CREATE TYPE document_status AS ENUM (
  'pending_review',
  'approved',
  'rejected'
);

-- ============================================
-- TABLES
-- ============================================

-- A. Organizations (Tenants)
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  legal_entity_name TEXT,
  admin_id UUID, -- will be FK to profiles after profiles is created
  registered_address JSONB,
  mailing_address JSONB,
  logo_image_link TEXT, -- Supabase Storage path
  tax_id TEXT,
  mc_dot_number TEXT,
  website TEXT,
  llm_provider TEXT DEFAULT 'gemini', -- gemini, openai, claude
  approval_email_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- B. Trucks
CREATE TABLE trucks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  truck_number TEXT NOT NULL,
  make TEXT,
  model TEXT,
  year INTEGER,
  vin TEXT,
  license_plate TEXT,
  current_odometer INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(organization_id, truck_number)
);

-- C. Profiles (Users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
  role user_role NOT NULL DEFAULT 'driver',
  full_name TEXT NOT NULL,
  phone_number TEXT UNIQUE,
  email_address TEXT,
  address JSONB,
  identity_document_id TEXT, -- Supabase Storage path
  preferred_language TEXT DEFAULT 'en',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add FK for organization admin
ALTER TABLE organizations 
  ADD CONSTRAINT fk_admin FOREIGN KEY (admin_id) REFERENCES profiles(id) ON DELETE SET NULL;

-- D. Loads (Revenue Contracts)
CREATE TABLE loads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  broker_name TEXT,
  broker_mc_number TEXT,
  broker_load_id TEXT, -- External reference number
  primary_rate NUMERIC(10, 2),
  fuel_surcharge NUMERIC(10, 2) DEFAULT 0,
  payment_terms TEXT DEFAULT 'Net 30',
  detention_policy_hours INTEGER DEFAULT 2,
  detention_rate_per_hour NUMERIC(10, 2) DEFAULT 50,
  commodity_type TEXT,
  weight_lbs NUMERIC(10, 2),
  pickup_address JSONB,
  delivery_address JSONB,
  notes TEXT,
  status load_status DEFAULT 'assigned',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- E. Trips (Physical Movement)
CREATE TABLE trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  load_id UUID REFERENCES loads(id) ON DELETE SET NULL, -- Nullable for deadhead trips
  truck_id UUID REFERENCES trucks(id) ON DELETE SET NULL,
  driver_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  origin_address TEXT,
  destination_address TEXT,
  origin_coordinates JSONB, -- {lat, lng}
  destination_coordinates JSONB,
  appointment_pickup TIMESTAMPTZ,
  arrival_pickup TIMESTAMPTZ,
  departure_pickup TIMESTAMPTZ,
  appointment_delivery TIMESTAMPTZ,
  arrival_delivery TIMESTAMPTZ,
  departure_delivery TIMESTAMPTZ,
  odometer_start INTEGER,
  odometer_end INTEGER,
  total_miles INTEGER GENERATED ALWAYS AS (
    CASE WHEN odometer_end IS NOT NULL AND odometer_start IS NOT NULL 
    THEN odometer_end - odometer_start 
    ELSE NULL END
  ) STORED,
  fuel_gallons_total NUMERIC(10, 2) DEFAULT 0,
  detention_hours NUMERIC(5, 2) DEFAULT 0,
  notes TEXT,
  status trip_status DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- F. Expenses (IFTA & Cost Ledger)
CREATE TABLE expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
  category expense_category NOT NULL,
  amount NUMERIC(10, 2) NOT NULL,
  currency TEXT DEFAULT 'USD',
  vendor_name TEXT,
  jurisdiction TEXT, -- State/Province code (TX, CA, ON)
  gallons NUMERIC(10, 3), -- For fuel purchases
  price_per_gallon NUMERIC(10, 3),
  date DATE DEFAULT CURRENT_DATE,
  is_reimbursable BOOLEAN DEFAULT FALSE,
  receipt_image_path TEXT, -- Supabase Storage path
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- G. Documents (Evidence)
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
  load_id UUID REFERENCES loads(id) ON DELETE SET NULL,
  expense_id UUID REFERENCES expenses(id) ON DELETE SET NULL,
  type document_type NOT NULL,
  image_url TEXT NOT NULL, -- Supabase Storage path
  thumbnail_url TEXT,
  page_count INTEGER DEFAULT 1,
  file_size_bytes INTEGER,
  ai_data JSONB, -- Extracted fields from LLM
  ai_confidence NUMERIC(3, 2), -- 0.00 to 1.00
  dangerous_clauses JSONB, -- Array of {clause, severity, explanation}
  local_text_extraction TEXT, -- On-device ML Kit extraction
  status document_status DEFAULT 'pending_review',
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- H. Document Embeddings (for semantic search)
CREATE TABLE document_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  content TEXT NOT NULL, -- The text content that was embedded
  embedding vector(1536), -- OpenAI embedding dimension
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for vector similarity search
CREATE INDEX ON document_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- I. Invoices
CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
  load_id UUID REFERENCES loads(id) ON DELETE SET NULL,
  invoice_number TEXT NOT NULL,
  issued_date DATE DEFAULT CURRENT_DATE,
  due_date DATE,
  subtotal NUMERIC(10, 2),
  detention_charges NUMERIC(10, 2) DEFAULT 0,
  reimbursable_expenses NUMERIC(10, 2) DEFAULT 0,
  total_amount NUMERIC(10, 2),
  recipient_email TEXT,
  recipient_name TEXT,
  pdf_path TEXT, -- Supabase Storage path
  status TEXT DEFAULT 'draft', -- draft, sent, paid
  sent_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- J. IFTA Reports
CREATE TABLE ifta_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  quarter TEXT NOT NULL, -- e.g., "2026-Q1"
  year INTEGER NOT NULL,
  quarter_number INTEGER NOT NULL, -- 1, 2, 3, 4
  jurisdiction_data JSONB, -- Array of {state, miles, gallons, tax_due}
  total_miles INTEGER,
  total_gallons NUMERIC(10, 2),
  total_tax_due NUMERIC(10, 2),
  status TEXT DEFAULT 'draft', -- draft, pending_review, submitted
  pdf_path TEXT,
  generated_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES profiles(id),
  submitted_at TIMESTAMPTZ
);

-- K. Audit Log
CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  table_name TEXT,
  record_id UUID,
  old_data JSONB,
  new_data JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_profiles_org ON profiles(organization_id);
CREATE INDEX idx_profiles_phone ON profiles(phone_number);
CREATE INDEX idx_trucks_org ON trucks(organization_id);
CREATE INDEX idx_loads_org ON loads(organization_id);
CREATE INDEX idx_loads_status ON loads(status);
CREATE INDEX idx_trips_org ON trips(organization_id);
CREATE INDEX idx_trips_driver ON trips(driver_id);
CREATE INDEX idx_trips_truck ON trips(truck_id);
CREATE INDEX idx_trips_status ON trips(status);
CREATE INDEX idx_expenses_org ON expenses(organization_id);
CREATE INDEX idx_expenses_trip ON expenses(trip_id);
CREATE INDEX idx_expenses_jurisdiction ON expenses(jurisdiction);
CREATE INDEX idx_documents_org ON documents(organization_id);
CREATE INDEX idx_documents_trip ON documents(trip_id);
CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_invoices_org ON invoices(organization_id);
CREATE INDEX idx_ifta_org_quarter ON ifta_reports(organization_id, year, quarter_number);
CREATE INDEX idx_audit_org ON audit_log(organization_id);
CREATE INDEX idx_audit_user ON audit_log(user_id);

-- Full text search on documents
CREATE INDEX idx_documents_ai_data ON documents USING GIN (ai_data);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply to all tables with updated_at
CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_trucks_updated_at BEFORE UPDATE ON trucks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_loads_updated_at BEFORE UPDATE ON loads FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_trips_updated_at BEFORE UPDATE ON trips FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_expenses_updated_at BEFORE UPDATE ON expenses FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_documents_updated_at BEFORE UPDATE ON documents FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate trip profitability
CREATE OR REPLACE FUNCTION calculate_trip_profit(trip_uuid UUID)
RETURNS TABLE (
  revenue NUMERIC,
  expenses NUMERIC,
  detention_revenue NUMERIC,
  net_profit NUMERIC,
  profit_margin NUMERIC
) AS $$
DECLARE
  load_rate NUMERIC;
  load_fuel_surcharge NUMERIC;
  detention_rate NUMERIC;
  trip_detention_hours NUMERIC;
  total_expenses NUMERIC;
BEGIN
  -- Get load revenue
  SELECT l.primary_rate, l.fuel_surcharge, l.detention_rate_per_hour
  INTO load_rate, load_fuel_surcharge, detention_rate
  FROM trips t
  JOIN loads l ON t.load_id = l.id
  WHERE t.id = trip_uuid;
  
  -- Get detention hours
  SELECT t.detention_hours INTO trip_detention_hours
  FROM trips t WHERE t.id = trip_uuid;
  
  -- Calculate total expenses
  SELECT COALESCE(SUM(e.amount), 0) INTO total_expenses
  FROM expenses e WHERE e.trip_id = trip_uuid;
  
  RETURN QUERY SELECT
    COALESCE(load_rate, 0) + COALESCE(load_fuel_surcharge, 0) AS revenue,
    total_expenses AS expenses,
    COALESCE(detention_rate * trip_detention_hours, 0) AS detention_revenue,
    (COALESCE(load_rate, 0) + COALESCE(load_fuel_surcharge, 0) + 
     COALESCE(detention_rate * trip_detention_hours, 0) - total_expenses) AS net_profit,
    CASE WHEN COALESCE(load_rate, 0) + COALESCE(load_fuel_surcharge, 0) > 0
      THEN ((COALESCE(load_rate, 0) + COALESCE(load_fuel_surcharge, 0) + 
             COALESCE(detention_rate * trip_detention_hours, 0) - total_expenses) /
            (COALESCE(load_rate, 0) + COALESCE(load_fuel_surcharge, 0))) * 100
      ELSE 0
    END AS profit_margin;
END;
$$ LANGUAGE plpgsql;

-- Function for semantic search
CREATE OR REPLACE FUNCTION search_documents(
  org_id UUID,
  query_embedding vector(1536),
  match_threshold FLOAT DEFAULT 0.78,
  match_count INT DEFAULT 10
)
RETURNS TABLE (
  document_id UUID,
  content TEXT,
  similarity FLOAT,
  metadata JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    de.document_id,
    de.content,
    1 - (de.embedding <=> query_embedding) AS similarity,
    de.metadata
  FROM document_embeddings de
  JOIN documents d ON de.document_id = d.id
  WHERE d.organization_id = org_id
    AND 1 - (de.embedding <=> query_embedding) > match_threshold
  ORDER BY de.embedding <=> query_embedding
  LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- Enable RLS on all tables
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE trucks ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE loads ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE ifta_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Helper function to get user's organization
CREATE OR REPLACE FUNCTION get_user_organization_id()
RETURNS UUID AS $$
  SELECT organization_id FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- Helper function to get user's role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- Helper function to check if user is system admin
CREATE OR REPLACE FUNCTION is_system_admin()
RETURNS BOOLEAN AS $$
  SELECT role = 'systemadmin' FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================
-- ORGANIZATIONS POLICIES
-- ============================================

-- System admins can do everything
CREATE POLICY "System admins full access to organizations"
  ON organizations FOR ALL
  TO authenticated
  USING (is_system_admin())
  WITH CHECK (is_system_admin());

-- Users can view their own organization
CREATE POLICY "Users can view own organization"
  ON organizations FOR SELECT
  TO authenticated
  USING (id = get_user_organization_id());

-- Org admins can update their organization
CREATE POLICY "Org admins can update own organization"
  ON organizations FOR UPDATE
  TO authenticated
  USING (id = get_user_organization_id() AND get_user_role() IN ('orgadmin', 'owner'))
  WITH CHECK (id = get_user_organization_id() AND get_user_role() IN ('orgadmin', 'owner'));

-- ============================================
-- PROFILES POLICIES
-- ============================================

-- System admins can do everything
CREATE POLICY "System admins full access to profiles"
  ON profiles FOR ALL
  TO authenticated
  USING (is_system_admin())
  WITH CHECK (is_system_admin());

--  Users can view profiles in their organization
CREATE POLICY "Users can view org profiles"
  ON profiles FOR SELECT
  TO authenticated
  USING (organization_id = get_user_organization_id());

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Owners/managers/dispatchers can manage profiles in their org
CREATE POLICY "Managers can insert profiles"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id = get_user_organization_id() 
    AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin')
  );

CREATE POLICY "Managers can update org profiles"
  ON profiles FOR UPDATE
  TO authenticated
  USING (
    organization_id = get_user_organization_id() 
    AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin')
  )
  WITH CHECK (
    organization_id = get_user_organization_id() 
    AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin')
  );

CREATE POLICY "Managers can delete org profiles"
  ON profiles FOR DELETE
  TO authenticated
  USING (
    organization_id = get_user_organization_id() 
    AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin')
    AND id != auth.uid() -- Can't delete yourself
  );

-- ============================================
-- TRUCKS POLICIES
-- ============================================

CREATE POLICY "Users can view org trucks"
  ON trucks FOR SELECT
  TO authenticated
  USING (organization_id = get_user_organization_id());

CREATE POLICY "Managers can manage trucks"
  ON trucks FOR ALL
  TO authenticated
  USING (
    organization_id = get_user_organization_id()
    AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin')
  )
  WITH CHECK (
    organization_id = get_user_organization_id()
    AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin')
  );

-- ============================================
-- LOADS POLICIES
-- ============================================

CREATE POLICY "Users can view org loads"
  ON loads FOR SELECT
  TO authenticated
  USING (organization_id = get_user_organization_id());

CREATE POLICY "Managers can manage loads"
  ON loads FOR ALL
  TO authenticated
  USING (
    organization_id = get_user_organization_id()
    AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin')
  )
  WITH CHECK (
    organization_id = get_user_organization_id()
    AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin')
  );

-- Drivers can update load status
CREATE POLICY "Drivers can update load status"
  ON loads FOR UPDATE
  TO authenticated
  USING (
    organization_id = get_user_organization_id()
    AND get_user_role() = 'driver'
  )
  WITH CHECK (
    organization_id = get_user_organization_id()
    AND get_user_role() = 'driver'
  );

-- ============================================
-- TRIPS POLICIES
-- ============================================

CREATE POLICY "Users can view org trips"
  ON trips FOR SELECT
  TO authenticated
  USING (organization_id = get_user_organization_id());

-- Drivers can manage their own trips
CREATE POLICY "Drivers can manage own trips"
  ON trips FOR ALL
  TO authenticated
  USING (
    organization_id = get_user_organization_id()
    AND (driver_id = auth.uid() OR get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin'))
  )
  WITH CHECK (
    organization_id = get_user_organization_id()
    AND (driver_id = auth.uid() OR get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin'))
  );

-- ============================================
-- EXPENSES POLICIES
-- ============================================

CREATE POLICY "Users can view org expenses"
  ON expenses FOR SELECT
  TO authenticated
  USING (organization_id = get_user_organization_id());

CREATE POLICY "Users can create expenses"
  ON expenses FOR INSERT
  TO authenticated
  WITH CHECK (organization_id = get_user_organization_id());

CREATE POLICY "Users can update own expenses"
  ON expenses FOR UPDATE
  TO authenticated
  USING (
    organization_id = get_user_organization_id()
    AND (
      trip_id IN (SELECT id FROM trips WHERE driver_id = auth.uid())
      OR get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin')
    )
  );

-- ============================================
-- DOCUMENTS POLICIES
-- ============================================

CREATE POLICY "Users can view org documents"
  ON documents FOR SELECT
  TO authenticated
  USING (organization_id = get_user_organization_id());

CREATE POLICY "Users can create documents"
  ON documents FOR INSERT
  TO authenticated
  WITH CHECK (organization_id = get_user_organization_id());

CREATE POLICY "Users can update own documents"
  ON documents FOR UPDATE
  TO authenticated
  USING (
    organization_id = get_user_organization_id()
    AND (
      trip_id IN (SELECT id FROM trips WHERE driver_id = auth.uid())
      OR get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin')
    )
  );

-- ============================================
-- DOCUMENT EMBEDDINGS POLICIES
-- ============================================

CREATE POLICY "Users can view org document embeddings"
  ON document_embeddings FOR SELECT
  TO authenticated
  USING (
    document_id IN (
      SELECT id FROM documents WHERE organization_id = get_user_organization_id()
    )
  );

-- ============================================
-- INVOICES POLICIES
-- ============================================

CREATE POLICY "Users can view org invoices"
  ON invoices FOR SELECT
  TO authenticated
  USING (organization_id = get_user_organization_id());

CREATE POLICY "Managers can manage invoices"
  ON invoices FOR ALL
  TO authenticated
  USING (
    organization_id = get_user_organization_id()
    AND get_user_role() IN ('owner', 'manager', 'orgadmin')
  )
  WITH CHECK (
    organization_id = get_user_organization_id()
    AND get_user_role() IN ('owner', 'manager', 'orgadmin')
  );

-- ============================================
-- IFTA REPORTS POLICIES
-- ============================================

CREATE POLICY "Users can view org IFTA reports"
  ON ifta_reports FOR SELECT
  TO authenticated
  USING (organization_id = get_user_organization_id());

CREATE POLICY "Managers can manage IFTA reports"
  ON ifta_reports FOR ALL
  TO authenticated
  USING (
    organization_id = get_user_organization_id()
    AND get_user_role() IN ('owner', 'manager', 'orgadmin')
  )
  WITH CHECK (
    organization_id = get_user_organization_id()
    AND get_user_role() IN ('owner', 'manager', 'orgadmin')
  );

-- ============================================
-- AUDIT LOG POLICIES
-- ============================================

CREATE POLICY "Users can view org audit logs"
  ON audit_log FOR SELECT
  TO authenticated
  USING (
    organization_id = get_user_organization_id()
    AND get_user_role() IN ('owner', 'orgadmin')
  );

-- Service role can insert audit logs
CREATE POLICY "Service can insert audit logs"
  ON audit_log FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- ============================================
-- STORAGE BUCKETS
-- ============================================
-- Note: These are created via Supabase Dashboard or API
-- Bucket naming: truckmate-{organization_id}
-- Each org gets their own bucket for isolation

-- Storage policies are configured separately in Supabase Dashboard
