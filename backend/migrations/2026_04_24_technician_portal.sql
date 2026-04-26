-- Technician portal migration
-- Adds technician access fields, access sessions and incident payment_method.

ALTER TABLE technicians ADD COLUMN IF NOT EXISTS access_code VARCHAR;
ALTER TABLE technicians ADD COLUMN IF NOT EXISTS access_code_expires_at TIMESTAMP;
ALTER TABLE technicians ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS ix_technicians_access_code ON technicians (access_code);

CREATE TABLE IF NOT EXISTS technician_access_sessions (
    id SERIAL PRIMARY KEY,
    technician_id INTEGER NOT NULL REFERENCES technicians(id) ON DELETE CASCADE,
    access_token VARCHAR NOT NULL UNIQUE,
    expires_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_technician_access_sessions_technician_id ON technician_access_sessions (technician_id);
CREATE INDEX IF NOT EXISTS ix_technician_access_sessions_access_token ON technician_access_sessions (access_token);

-- SQLAlchemy stores enum labels in uppercase in this codebase.
ALTER TABLE incidents ADD COLUMN IF NOT EXISTS payment_method paymentmethod;

-- Seed existing technicians with a valid access code and expiry.
UPDATE technicians
SET
    access_code = SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6),
    access_code_expires_at = NOW() + INTERVAL '24 hours'
WHERE access_code IS NULL;
