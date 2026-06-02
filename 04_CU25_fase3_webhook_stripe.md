# 04 - CU25 Fase 3: Webhook Stripe + Endpoint de Estado

## 1. Archivos modificados
1. `backend/app/routers/payments.py`
2. `backend/app/schemas.py`
3. `04_CU25_fase3_webhook_stripe.md`

## 2. Endpoint webhook agregado
- **POST** `/payments/stripe/webhook`
- No requiere JWT.
- Lee `raw body` (`Request.body()`) y header `stripe-signature`.
- Valida firma con `stripe.Webhook.construct_event(..., settings.STRIPE_WEBHOOK_SECRET)`.

### Respuesta
```json
{
  "received": true
}
```

## 3. Endpoint status agregado
- **GET** `/payments/{payment_id}/status`
- Requiere JWT.
- Permisos:
  - cliente dueño del pago
  - taller dueño del incidente asociado
  - admin
- Devuelve:
  - `payment_id`
  - `incident_id`
  - `amount`
  - `is_paid`
  - `paid_at`
  - `payment_method`
  - `stripe_session_id`
  - `stripe_payment_intent_id`
  - `stripe_payment_status`
  - `currency`
  - `commission_amount`
  - `workshop_earnings`

## 4. Eventos Stripe manejados
1. `checkout.session.completed`
2. `checkout.session.async_payment_failed` (opcional, implementado)
3. `checkout.session.expired` (opcional, implementado)

## 5. Campos actualizados al confirmar pago
Para `checkout.session.completed`:
- Se obtiene:
  - `session.id`
  - `session.payment_intent`
  - `session.payment_status`
  - `metadata.payment_id`
- Se valida coherencia de sesión (`payment.stripe_session_id` vs `session.id`).
- Idempotencia:
  - si `payment.is_paid == true`, responde `200` sin duplicar cambios.
- Si `payment_status == "paid"`:
  - `payment.is_paid = true`
  - `payment.paid_at = datetime.utcnow()`
  - `payment.payment_method = PaymentMethod.TRANSFER`
  - `payment.stripe_payment_intent_id = session.payment_intent`
  - `payment.stripe_payment_status = session.payment_status`
  - `payment.reference_number = session.payment_intent`
  - `payment.notes = "Pago confirmado por Stripe Checkout"`
  - `payment.updated_at = datetime.utcnow()`
  - `incident.payment_method = PaymentMethod.TRANSFER` (si incidente existe)
- Si `payment_status != "paid"`:
  - actualiza `stripe_payment_status`
  - no marca pagado.

Para eventos fallidos/expirados:
- Actualiza `stripe_payment_status`.
- No modifica `is_paid`, `paid_at`, `payment_method`.

## 6. Cómo probar con Stripe CLI

### Levantar backend
```powershell
docker compose down
docker compose build --no-cache backend
docker compose up -d
```

### Escuchar webhooks
```bash
stripe listen --forward-to localhost:8000/payments/stripe/webhook
```

Stripe CLI mostrará un `whsec_...`.

### Configurar secreto local
Coloca ese valor en `.env` (raíz) como:
```env
STRIPE_WEBHOOK_SECRET=whsec_xxx
```
Luego recrea backend:
```powershell
docker compose down
docker compose build --no-cache backend
docker compose up -d
```

### Flujo de prueba
1. Crear checkout con `POST /payments/{payment_id}/stripe/checkout`.
2. Completar pago en la URL de Stripe Checkout (test).
3. Verificar que Stripe CLI reenvía `checkout.session.completed`.
4. Consultar `GET /payments/{payment_id}/status`.

## 7. Cómo obtener STRIPE_WEBHOOK_SECRET
1. Ejecutar:
```bash
stripe listen --forward-to localhost:8000/payments/stripe/webhook
```
2. Copiar el `whsec_...` que imprime Stripe CLI.
3. Guardarlo en `.env` como `STRIPE_WEBHOOK_SECRET`.

## 8. Comandos para verificar BD
```powershell
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, incident_id, is_paid, paid_at, payment_method, reference_number, stripe_session_id, stripe_payment_intent_id, stripe_payment_status FROM payments ORDER BY id DESC LIMIT 10;"
```

Opcional para un pago específico:
```powershell
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, incident_id, is_paid, paid_at, payment_method, reference_number, stripe_session_id, stripe_payment_intent_id, stripe_payment_status, currency, commission_amount, workshop_earnings FROM payments WHERE id = 1;"
```

## 9. Qué NO se implementó todavía
- No se tocó Flutter.
- No se tocó Angular.
- No se tocó flujo mecánico/QR/efectivo.
- No se agregó enum `STRIPE`.
- No se crean nuevos pagos.
- No se marca pago desde `success_url` (solo webhook).
- No se hicieron cambios al flujo de aceptación de ofertas.

## Corrección aplicada
- Se corrigió el webhook Stripe convirtiendo el `Event` de Stripe a diccionario con `event = event.to_dict_recursive()` inmediatamente después de `construct_event(...)`.
- Esto evita el error `AttributeError: get` al leer `event.get("type")` y los campos de `data.object` con acceso tipo dict.
- Corrección aplicada: se valida la firma con `stripe.Webhook.construct_event`, pero se parsea el payload crudo con `json.loads` para evitar incompatibilidad con `to_dict_recursive()`. También se ignoran con 200 los eventos Stripe no manejados.
