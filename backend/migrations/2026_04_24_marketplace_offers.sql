-- Marketplace multi-offer migration
-- Adds new IncidentStatus values and creates offers table.

-- 1) Extend existing incident enum values.
-- Note: ALTER TYPE ... ADD VALUE must run as standalone statements in PostgreSQL.
ALTER TYPE incidentstatus ADD VALUE IF NOT EXISTS 'WAITING_OFFERS';
ALTER TYPE incidentstatus ADD VALUE IF NOT EXISTS 'ASSIGNED';

-- 2) Create offer status enum if missing.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'offerstatus') THEN
        CREATE TYPE offerstatus AS ENUM ('PENDING', 'ACCEPTED', 'REJECTED');
    END IF;
END
$$;

-- Ensure uppercase values exist in offerstatus for SQLAlchemy compatibility.
ALTER TYPE offerstatus ADD VALUE IF NOT EXISTS 'PENDING';
ALTER TYPE offerstatus ADD VALUE IF NOT EXISTS 'ACCEPTED';
ALTER TYPE offerstatus ADD VALUE IF NOT EXISTS 'REJECTED';

-- 3) Create offers table.
CREATE TABLE IF NOT EXISTS offers (
    id SERIAL PRIMARY KEY,
    incident_id INTEGER NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    workshop_id INTEGER NOT NULL REFERENCES workshops(id) ON DELETE CASCADE,
    technician_id INTEGER NULL REFERENCES technicians(id) ON DELETE SET NULL,
    amount NUMERIC(10, 2) NOT NULL,
    estimated_arrival_time INTEGER NULL,
    notes TEXT NULL,
    status offerstatus NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_offers_incident_id ON offers (incident_id);
CREATE INDEX IF NOT EXISTS ix_offers_workshop_id ON offers (workshop_id);

ALTER TABLE offers ALTER COLUMN status SET DEFAULT 'PENDING';
