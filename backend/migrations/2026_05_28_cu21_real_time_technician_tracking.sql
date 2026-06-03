-- CU21 - Real-time technician tracking and ETA updates

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'incidentstatus') THEN
        IF NOT EXISTS (
            SELECT 1
            FROM pg_enum e
            JOIN pg_type t ON t.oid = e.enumtypid
            WHERE t.typname = 'incidentstatus' AND e.enumlabel = 'ON_ROUTE'
        ) THEN
            ALTER TYPE incidentstatus ADD VALUE IF NOT EXISTS 'ON_ROUTE';
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM pg_enum e
            JOIN pg_type t ON t.oid = e.enumtypid
            WHERE t.typname = 'incidentstatus' AND e.enumlabel = 'IN_SERVICE'
        ) THEN
            ALTER TYPE incidentstatus ADD VALUE IF NOT EXISTS 'IN_SERVICE';
        END IF;
    END IF;
END
$$;

ALTER TABLE incidents ADD COLUMN IF NOT EXISTS remaining_distance_meters INTEGER;
ALTER TABLE incidents ADD COLUMN IF NOT EXISTS route_polyline TEXT;
ALTER TABLE incidents ADD COLUMN IF NOT EXISTS last_eta_update_at TIMESTAMP;

CREATE TABLE IF NOT EXISTS incident_tracking (
    id SERIAL PRIMARY KEY,
    incident_id INTEGER NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    technician_id INTEGER NOT NULL REFERENCES technicians(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    remaining_distance_meters INTEGER NULL,
    estimated_arrival_time INTEGER NULL,
    status incidentstatus NOT NULL,
    recorded_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_incident_tracking_incident_id ON incident_tracking (incident_id);
CREATE INDEX IF NOT EXISTS ix_incident_tracking_technician_id ON incident_tracking (technician_id);
CREATE INDEX IF NOT EXISTS ix_incident_tracking_recorded_at ON incident_tracking (recorded_at);