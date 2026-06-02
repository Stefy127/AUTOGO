ALTER TABLE payments
ADD COLUMN IF NOT EXISTS stripe_session_id VARCHAR,
ADD COLUMN IF NOT EXISTS stripe_payment_intent_id VARCHAR,
ADD COLUMN IF NOT EXISTS stripe_payment_status VARCHAR,
ADD COLUMN IF NOT EXISTS currency VARCHAR(10) DEFAULT 'usd';

CREATE INDEX IF NOT EXISTS ix_payments_stripe_session_id
ON payments (stripe_session_id);

CREATE INDEX IF NOT EXISTS ix_payments_stripe_payment_intent_id
ON payments (stripe_payment_intent_id);
