ALTER TABLE incidents
ADD COLUMN IF NOT EXISTS client_offline_id VARCHAR NULL;

ALTER TABLE incidents
ADD COLUMN IF NOT EXISTS client_email_offline VARCHAR NULL;

ALTER TABLE incidents
ADD COLUMN IF NOT EXISTS created_offline_at TIMESTAMP NULL;

ALTER TABLE incidents
ADD COLUMN IF NOT EXISTS synced_at TIMESTAMP NULL;

ALTER TABLE incidents
ADD COLUMN IF NOT EXISTS sync_source VARCHAR NULL;

CREATE INDEX IF NOT EXISTS idx_incidents_client_offline_id
ON incidents (client_offline_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_incidents_user_offline_unique
ON incidents (user_id, client_offline_id)
WHERE client_offline_id IS NOT NULL;
