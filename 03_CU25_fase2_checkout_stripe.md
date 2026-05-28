# 03 - CU25 Fase 2: Stripe Checkout (Solo creación de sesión)

## 1. Archivos modificados
1. `backend/app/routers/payments.py`
2. `backend/app/schemas.py`
3. `03_CU25_fase2_checkout_stripe.md`

## 2. Endpoint agregado
- **POST** `/payments/{payment_id}/stripe/checkout`
- **Response model**: `StripeCheckoutResponse`
  - `payment_id: int`
  - `checkout_url: str`
  - `stripe_session_id: str`
  - `stripe_payment_status: str | None`
  - `currency: str`

## 3. Validaciones implementadas
1. Solo `CLIENT` puede usarlo (`403`).
2. Debe existir `STRIPE_SECRET_KEY` (`500` si falta configuración).
3. `Payment` debe existir (`404`).
4. El `Payment` debe pertenecer al cliente autenticado (`incident.user_id == current_user.id`) (`403`).
5. `payment.is_paid` debe ser `false` (`409` si ya pagado).
6. El incidente asociado debe estar `COMPLETED` (`400` si no).
7. Monto válido (`payment.amount > 0`) (`422` si inválido).

## 4. Comportamiento de negocio implementado
- Usa monto desde BD (`payment.amount`), no recibe monto del frontend.
- Convierte monto a unidad menor de moneda con conversión segura:
  - `unit_amount = int(Decimal(amount) * 100)` con redondeo seguro.
- Moneda desde `settings.STRIPE_CURRENCY` (default `usd`).
- Crea sesión de Stripe Checkout con metadata:
  - `payment_id`
  - `incident_id`
  - `client_id`
- Agrega metadata también en `payment_intent_data`.
- Usa `STRIPE_SUCCESS_URL` y `STRIPE_CANCEL_URL` con query params:
  - `payment_id`
  - `session_id={CHECKOUT_SESSION_ID}`
- Guarda en `payments`:
  - `stripe_session_id`
  - `stripe_payment_status`
  - `currency`

## 5. Qué NO se implementó todavía
- No se implementó webhook Stripe (`/payments/stripe/webhook`).
- No se marca `is_paid=true` en esta fase.
- No se actualiza `paid_at`.
- No se modifica `payment_method`.
- No se toca `reference_number`.
- No se cambió QR/efectivo/técnico.
- No se tocó Flutter ni Angular.

## 6. Cómo probar (Swagger / curl)

### Rebuild backend
```powershell
docker compose down
docker compose build --no-cache backend
docker compose up -d
```

### Swagger
1. Ir a `http://localhost:8000/docs`.
2. Autenticarse como cliente (obtener token en `/auth/login/json` o `/auth/login`).
3. Usar `POST /payments/{payment_id}/stripe/checkout` con un `payment_id` pendiente y de un incidente `COMPLETED` del cliente.
4. Verificar respuesta con `checkout_url` y `stripe_session_id`.

### curl (ejemplo)
```bash
curl -X POST "http://localhost:8000/payments/1/stripe/checkout" \
  -H "Authorization: Bearer TU_TOKEN_CLIENTE" \
  -H "Content-Type: application/json"
```

## 7. Verificación en PostgreSQL
```powershell
# Ver pagos y columnas stripe
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT p.id, p.incident_id, p.amount, p.is_paid, p.stripe_session_id, p.stripe_payment_status, p.currency, i.status FROM payments p JOIN incidents i ON i.id = p.incident_id ORDER BY p.id DESC LIMIT 20;"

# Ver un pago puntual
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, stripe_session_id, stripe_payment_status, currency, is_paid, paid_at, payment_method FROM payments WHERE id = 1;"
```
