-- Adds notification table and ensures paymentmethod enum supports QR/TRANSFER.

CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    incident_id INTEGER NULL REFERENCES incidents(id) ON DELETE SET NULL,
    title VARCHAR NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_notifications_user_id ON notifications (user_id);
CREATE INDEX IF NOT EXISTS ix_notifications_incident_id ON notifications (incident_id);
CREATE INDEX IF NOT EXISTS ix_notifications_type ON notifications (notification_type);
CREATE INDEX IF NOT EXISTS ix_notifications_created_at ON notifications (created_at);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'paymentmethod') THEN
        IF NOT EXISTS (
            SELECT 1
            FROM pg_enum e
            JOIN pg_type t ON t.oid = e.enumtypid
            WHERE t.typname = 'paymentmethod' AND e.enumlabel = 'QR'
        ) THEN
            ALTER TYPE paymentmethod ADD VALUE 'QR';
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM pg_enum e
            JOIN pg_type t ON t.oid = e.enumtypid
            WHERE t.typname = 'paymentmethod' AND e.enumlabel = 'TRANSFER'
        ) THEN
            ALTER TYPE paymentmethod ADD VALUE 'TRANSFER';
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM pg_enum e
            JOIN pg_type t ON t.oid = e.enumtypid
            WHERE t.typname = 'paymentmethod' AND e.enumlabel = 'CASH'
        ) THEN
            ALTER TYPE paymentmethod ADD VALUE 'CASH';
        END IF;
    END IF;
END
$$;
