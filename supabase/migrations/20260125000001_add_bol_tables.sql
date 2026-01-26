-- Migration: Add Bill of Lading tables
-- Adapting user request to match existing schema (UUIDs, RLS, etc.)

-- 1. Bill of Ladings Table
CREATE TABLE bill_of_ladings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    load_id UUID REFERENCES loads(id) ON DELETE SET NULL, 
    -- Added trip_id to easily link to specific trip if needed, though user only asked for load_id. 
    -- Staying strict to user SQL for foreign keys but using UUIDs.
    
    -- Document Identification
    bol_number VARCHAR(100), -- Made nullable as OCR might miss it
    pro_number VARCHAR(100),
    document_date DATE,
    
    -- The Parties
    shipper_name VARCHAR(255),
    shipper_address_raw TEXT,
    shipper_city VARCHAR(100),
    shipper_state VARCHAR(50),
    shipper_zip VARCHAR(20),
    
    consignee_name VARCHAR(255),
    consignee_address_raw TEXT,
    consignee_city VARCHAR(100),
    consignee_state VARCHAR(50),
    consignee_zip VARCHAR(20),
    
    bill_to_name VARCHAR(255),
    bill_to_address_raw TEXT,
    
    carrier_name VARCHAR(255),
    carrier_scac VARCHAR(10),
    
    -- Totals & Flags
    total_handling_units INT,
    total_weight_lbs DECIMAL(10, 2),
    is_hazmat_detected BOOLEAN DEFAULT FALSE,
    declared_value DECIMAL(10, 2),
    
    -- Billing Terms
    payment_terms VARCHAR(20) CHECK (payment_terms IN ('PREPAID', 'COLLECT', 'THIRD_PARTY')),
    
    -- Signatures
    is_shipper_signed BOOLEAN DEFAULT FALSE,
    is_carrier_signed BOOLEAN DEFAULT FALSE,
    is_receiver_signed BOOLEAN DEFAULT FALSE,
    
    special_notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. BOL Line Items
CREATE TABLE bol_line_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bol_id UUID NOT NULL REFERENCES bill_of_ladings(id) ON DELETE CASCADE,
    
    sequence_number INT,
    description TEXT,
    
    -- Quantities
    quantity INT,
    unit_type VARCHAR(50),
    weight_lbs DECIMAL(10, 2),
    
    -- Classification
    nmfc_code VARCHAR(20),
    freight_class VARCHAR(10),
    is_hazmat BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. BOL References
CREATE TABLE bol_references (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bol_id UUID NOT NULL REFERENCES bill_of_ladings(id) ON DELETE CASCADE,
    ref_type VARCHAR(50) CHECK (ref_type IN ('PO', 'SEAL', 'CUSTOMER_REF', 'SID', 'OTHER')),
    ref_value VARCHAR(100) NOT NULL,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. BOL Validations
CREATE TABLE bol_validations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    load_id UUID REFERENCES loads(id) ON DELETE CASCADE, -- If load is deleted, validation is irrelevant? Or Set Null.
    bol_id UUID REFERENCES bill_of_ladings(id) ON DELETE CASCADE,
    
    -- The Scores
    location_match_score INT,
    weight_variance_pct DECIMAL(5,2),
    
    -- The Flags
    has_hazmat_mismatch BOOLEAN,
    has_po_mismatch BOOLEAN,
    
    validation_status VARCHAR(20) CHECK (validation_status IN ('PASSED', 'WARNING', 'FAILED')),
    failure_reasons TEXT[],
    
    validated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_bol_org ON bill_of_ladings(organization_id);
CREATE INDEX idx_bol_load ON bill_of_ladings(load_id);
CREATE INDEX idx_bol_number ON bill_of_ladings(bol_number);
CREATE INDEX idx_bol_items_bol ON bol_line_items(bol_id);
CREATE INDEX idx_bol_refs_bol ON bol_references(bol_id);
CREATE INDEX idx_bol_refs_value ON bol_references(ref_value);
CREATE INDEX idx_bol_val_load ON bol_validations(load_id);
CREATE INDEX idx_bol_val_bol ON bol_validations(bol_id);

-- Trigger for updated_at
CREATE TRIGGER update_bill_of_ladings_updated_at BEFORE UPDATE ON bill_of_ladings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS Policies

-- Enable RLS
ALTER TABLE bill_of_ladings ENABLE ROW LEVEL SECURITY;
ALTER TABLE bol_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE bol_references ENABLE ROW LEVEL SECURITY;
ALTER TABLE bol_validations ENABLE ROW LEVEL SECURITY;

-- Policies for bill_of_ladings
CREATE POLICY "Users can view org bill_of_ladings"
  ON bill_of_ladings FOR SELECT
  TO authenticated
  USING (organization_id = get_user_organization_id());

CREATE POLICY "Users can create bill_of_ladings"
  ON bill_of_ladings FOR INSERT
  TO authenticated
  WITH CHECK (organization_id = get_user_organization_id());

CREATE POLICY "Users can update org bill_of_ladings"
  ON bill_of_ladings FOR UPDATE
  TO authenticated
  USING (organization_id = get_user_organization_id());

-- Policies for items, refs, validations (inherit access via bol_id or organization check if logic requires, but simpler to just allow org access)
-- Since these don't have organization_id directly, we check via join or just trust that if you can access the BOL, you can access these.
-- But standard RLS usually requires a way to check.
-- Adding organization_id to sub-tables is often cleaner for RLS, but user didn't ask for it.
-- We can use a EXISTS clause.

CREATE POLICY "Users can view bol_line_items"
  ON bol_line_items FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM bill_of_ladings b
      WHERE b.id = bol_line_items.bol_id
      AND b.organization_id = get_user_organization_id()
    )
  );
  
CREATE POLICY "Users can insert bol_line_items"
  ON bol_line_items FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM bill_of_ladings b
      WHERE b.id = bol_line_items.bol_id
      AND b.organization_id = get_user_organization_id()
    )
  );

-- Repeat for references
CREATE POLICY "Users can view bol_references"
  ON bol_references FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM bill_of_ladings b
      WHERE b.id = bol_references.bol_id
      AND b.organization_id = get_user_organization_id()
    )
  );
  
CREATE POLICY "Users can insert bol_references"
  ON bol_references FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM bill_of_ladings b
      WHERE b.id = bol_references.bol_id
      AND b.organization_id = get_user_organization_id()
    )
  );

-- bol_validations
CREATE POLICY "Users can view bol_validations"
  ON bol_validations FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM bill_of_ladings b
      WHERE b.id = bol_validations.bol_id
      AND b.organization_id = get_user_organization_id()
    )
  );

-- Service role bypass enables backend processing to insert regardless
