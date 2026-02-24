-- ============================================================
--  BizSuite SaaS — Complete Supabase Schema
--  Run this ONCE in your Supabase SQL Editor
-- ============================================================

-- 1. TENANTS (your clients)
CREATE TABLE IF NOT EXISTS tenants (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  phone         TEXT,
  plan          TEXT NOT NULL DEFAULT 'basic',
  status        TEXT NOT NULL DEFAULT 'trial',
  trial_ends    DATE DEFAULT (NOW() + INTERVAL '14 days'),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  billing_cycle TEXT DEFAULT 'monthly',
  monthly_price NUMERIC(10,2) DEFAULT 0,
  admin_notes   TEXT,
  accent_color  TEXT DEFAULT '#3b6cf4'
);

-- 2. FEATURE FLAGS (per tenant)
CREATE TABLE IF NOT EXISTS tenant_features (
  tenant_id         UUID PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE,
  f_sales           BOOLEAN DEFAULT TRUE,
  f_purchases       BOOLEAN DEFAULT TRUE,
  f_expenses        BOOLEAN DEFAULT TRUE,
  f_products        BOOLEAN DEFAULT TRUE,
  f_clients_vendors BOOLEAN DEFAULT TRUE,
  f_reports         BOOLEAN DEFAULT TRUE,
  f_payroll         BOOLEAN DEFAULT FALSE,
  f_delivery        BOOLEAN DEFAULT FALSE,
  f_multi_branch    BOOLEAN DEFAULT FALSE,
  f_barcode         BOOLEAN DEFAULT FALSE,
  f_whatsapp        BOOLEAN DEFAULT FALSE,
  f_pos             BOOLEAN DEFAULT FALSE,
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- 3. TENANT USERS
CREATE TABLE IF NOT EXISTS tenant_users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL DEFAULT 'staff',
  name        TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, user_id)
);

-- 4. TENANT DATA (all business data per tenant)
CREATE TABLE IF NOT EXISTS tenant_data (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  data_type   TEXT NOT NULL,
  data        JSONB NOT NULL DEFAULT '[]',
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, data_type)
);

-- 5. ADMIN USERS (SaaS owner = you)
CREATE TABLE IF NOT EXISTS admin_users (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 6. BRANCHES
CREATE TABLE IF NOT EXISTS branches (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  address     TEXT,
  phone       TEXT,
  is_active   BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 7. STAFF
CREATE TABLE IF NOT EXISTS staff (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  role        TEXT,
  salary      NUMERIC(12,2) DEFAULT 0,
  phone       TEXT,
  cnic        TEXT,
  join_date   DATE,
  is_active   BOOLEAN DEFAULT TRUE,
  branch_id   UUID REFERENCES branches(id),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 8. PAYROLL
CREATE TABLE IF NOT EXISTS payroll_records (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  staff_id    UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  month       TEXT NOT NULL,
  base_salary NUMERIC(12,2) DEFAULT 0,
  bonus       NUMERIC(12,2) DEFAULT 0,
  deductions  NUMERIC(12,2) DEFAULT 0,
  net_salary  NUMERIC(12,2) DEFAULT 0,
  status      TEXT DEFAULT 'pending',
  paid_date   DATE,
  notes       TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 9. DELIVERIES
CREATE TABLE IF NOT EXISTS deliveries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  sale_id     TEXT,
  client_name TEXT,
  address     TEXT,
  driver      TEXT,
  status      TEXT DEFAULT 'pending',
  scheduled   DATE,
  notes       TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── RLS ──────────────────────────────────────────────────
ALTER TABLE tenants          ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_features  ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_users     ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_data      ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users      ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches         ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff            ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_records  ENABLE ROW LEVEL SECURITY;
ALTER TABLE deliveries       ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM admin_users WHERE id = auth.uid());
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION my_tenant_id()
RETURNS UUID AS $$
  SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION my_role()
RETURNS TEXT AS $$
  SELECT role FROM tenant_users WHERE user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- Tenants
CREATE POLICY "admin_tenants"   ON tenants FOR ALL    USING (is_admin());
CREATE POLICY "user_tenant"     ON tenants FOR SELECT USING (id = my_tenant_id());

-- Features
CREATE POLICY "admin_features"  ON tenant_features FOR ALL    USING (is_admin());
CREATE POLICY "user_features"   ON tenant_features FOR SELECT USING (tenant_id = my_tenant_id());

-- Users
CREATE POLICY "admin_tu"        ON tenant_users FOR ALL    USING (is_admin());
CREATE POLICY "owner_tu"        ON tenant_users FOR ALL    USING (tenant_id = my_tenant_id() AND my_role() IN ('owner','manager'));
CREATE POLICY "user_tu_read"    ON tenant_users FOR SELECT USING (tenant_id = my_tenant_id());

-- Data
CREATE POLICY "admin_data"      ON tenant_data FOR ALL USING (is_admin());
CREATE POLICY "user_data"       ON tenant_data FOR ALL USING (tenant_id = my_tenant_id());

-- Admin
CREATE POLICY "admin_only"      ON admin_users FOR ALL USING (is_admin());

-- Branches
CREATE POLICY "admin_br"        ON branches FOR ALL USING (is_admin());
CREATE POLICY "user_br"         ON branches FOR ALL USING (tenant_id = my_tenant_id());

-- Staff
CREATE POLICY "admin_st"        ON staff FOR ALL USING (is_admin());
CREATE POLICY "user_st"         ON staff FOR ALL USING (tenant_id = my_tenant_id());

-- Payroll
CREATE POLICY "admin_pay"       ON payroll_records FOR ALL USING (is_admin());
CREATE POLICY "user_pay"        ON payroll_records FOR ALL USING (tenant_id = my_tenant_id());

-- Deliveries
CREATE POLICY "admin_del"       ON deliveries FOR ALL USING (is_admin());
CREATE POLICY "user_del"        ON deliveries FOR ALL USING (tenant_id = my_tenant_id());

-- ── Trigger: auto-update updated_at ──────────────────────
CREATE OR REPLACE FUNCTION update_ts()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tenants   BEFORE UPDATE ON tenants        FOR EACH ROW EXECUTE FUNCTION update_ts();
CREATE TRIGGER trg_features  BEFORE UPDATE ON tenant_features FOR EACH ROW EXECUTE FUNCTION update_ts();
CREATE TRIGGER trg_data      BEFORE UPDATE ON tenant_data     FOR EACH ROW EXECUTE FUNCTION update_ts();

-- ── Indexes ───────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_tu_user   ON tenant_users(user_id);
CREATE INDEX IF NOT EXISTS idx_tu_tenant ON tenant_users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_td_tenant ON tenant_data(tenant_id);
CREATE INDEX IF NOT EXISTS idx_st_tenant ON staff(tenant_id);

-- ── AFTER running schema: insert yourself as admin ────────
-- Replace with your actual email, run AFTER signing up:
-- INSERT INTO admin_users(id,email) SELECT id,email FROM auth.users WHERE email='you@gmail.com';
