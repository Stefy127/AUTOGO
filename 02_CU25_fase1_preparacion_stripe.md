# 02 - CU25 Fase 1: Preparación Stripe (Backend + BD)

## Objetivo de la fase
Preparar AUTOGO para integrar Stripe en fases siguientes, sin cambiar la lógica funcional actual de pagos.

## Archivos modificados
1. `backend/requirements.txt`
2. `backend/app/config.py`
3. `backend/app/models.py`
4. `backend/app/schemas.py`
5. `backend/migrations/2026_05_28_stripe_payments.sql`
6. `backend/main.py`
7. `docker-compose.yml`

## Cambios aplicados
### 1) Dependencia Stripe
- Se agregó `stripe` en `backend/requirements.txt`.

### 2) Configuración (`backend/app/config.py`)
Se agregaron settings opcionales para Stripe:
- `STRIPE_SECRET_KEY: str = ""`
- `STRIPE_WEBHOOK_SECRET: str = ""`
- `STRIPE_SUCCESS_URL: str = "http://localhost:4200/#/payment-success"`
- `STRIPE_CANCEL_URL: str = "http://localhost:4200/#/payment-cancel"`
- `STRIPE_CURRENCY: str = "usd"`

### 3) Modelo `Payment` (`backend/app/models.py`)
Campos nuevos para trazabilidad Stripe:
- `stripe_session_id` (nullable)
- `stripe_payment_intent_id` (nullable)
- `stripe_payment_status` (nullable)
- `currency` (`String(10)`, default `"usd"`, no nullable)

No se cambió:
- `payment_method`
- `is_paid`
- enums actuales
- flujo actual de pagos

### 4) Schemas (`backend/app/schemas.py`)
`PaymentResponse` ahora incluye campos opcionales:
- `stripe_session_id`
- `stripe_payment_intent_id`
- `stripe_payment_status`
- `currency`

No se cambió `PaymentCreate` (no requiere campos Stripe).

### 5) Migración SQL (`backend/migrations/2026_05_28_stripe_payments.sql`)
Migración idempotente con:
- `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` para:
  - `stripe_session_id varchar`
  - `stripe_payment_intent_id varchar`
  - `stripe_payment_status varchar`
  - `currency varchar(10) default 'usd'`
- Índices idempotentes:
  - `ix_payments_stripe_session_id`
  - `ix_payments_stripe_payment_intent_id`

### 6) Registro de migración (`backend/main.py`)
Se agregó la nueva migración al final de `migration_files` en `_run_startup_migrations()`.

### 7) Variables en Docker (`docker-compose.yml`)
En servicio `backend` se agregaron:
- `STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY:-}`
- `STRIPE_WEBHOOK_SECRET=${STRIPE_WEBHOOK_SECRET:-}`
- `STRIPE_SUCCESS_URL=http://localhost:4200/#/payment-success`
- `STRIPE_CANCEL_URL=http://localhost:4200/#/payment-cancel`
- `STRIPE_CURRENCY=usd`

## Comandos para rebuild
```powershell
docker compose down
docker compose build --no-cache backend
docker compose up -d
```

## Comandos de verificación
```powershell
# Ver estructura actualizada de payments
docker exec autogo_postgres psql -U autogo -d autogo_db -c "\d payments"

# Ver que backend recibió variable de moneda
docker exec autogo_backend /bin/sh -c "printenv STRIPE_CURRENCY"

# Verificar columnas Stripe explícitamente
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_name = 'payments' AND column_name IN ('stripe_session_id', 'stripe_payment_intent_id', 'stripe_payment_status', 'currency') ORDER BY column_name;"

# Verificar índices creados
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'payments' AND indexname IN ('ix_payments_stripe_session_id', 'ix_payments_stripe_payment_intent_id');"
```

## Qué NO se implementó todavía
- No se implementó `POST /payments/{payment_id}/stripe/checkout`.
- No se implementó `POST /payments/stripe/webhook`.
- No se implementó `GET /payments/{payment_id}/status` específico Stripe.
- No se modificó Flutter.
- No se modificó Angular.
- No se modificó flujo QR, efectivo ni técnico.
- No se agregó enum `STRIPE`.
- No se cambió la lógica de aceptación de ofertas.
