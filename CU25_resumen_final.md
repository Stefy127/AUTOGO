# CU25 - Resumen Final Completo (Estado Actual)

## Alcance CU25
Integrar pago con Stripe sobre el `Payment` existente, sin crear pagos paralelos y manteniendo compatibilidad con efectivo/QR.

## Fase 1 - Preparación backend/BD
Completada.
- Dependencia `stripe` en backend.
- Settings Stripe agregados (`STRIPE_*`).
- Campos Stripe en `payments`:
  - `stripe_session_id`
  - `stripe_payment_intent_id`
  - `stripe_payment_status`
  - `currency`
- Migración SQL idempotente aplicada y registrada.

## Fase 2 - Checkout Stripe
Completada.
- Endpoint: `POST /payments/{payment_id}/stripe/checkout`.
- Reglas:
  - solo cliente dueño del pago
  - incidente `COMPLETED`
  - pago pendiente (`is_paid=false`)
  - monto tomado desde `payment.amount`
- Guarda en `payments`:
  - `stripe_session_id`
  - `stripe_payment_status`
  - `currency`

## Fase 3 - Webhook + estado
Completada.
- Endpoint: `POST /payments/stripe/webhook` (sin JWT).
- Validación firma Stripe con `STRIPE_WEBHOOK_SECRET`.
- Corrección de compatibilidad: firma validada con Stripe SDK y payload parseado con `json.loads`.
- Eventos manejados:
  - `checkout.session.completed`
  - `checkout.session.async_payment_failed`
  - `checkout.session.expired`
- Confirmación de pago al webhook exitoso:
  - `is_paid=true`
  - `paid_at=utcnow`
  - `payment_method=TRANSFER`
  - `stripe_payment_intent_id`, `stripe_payment_status`, `reference_number`, `notes`
  - `incident.payment_method=TRANSFER`
- Idempotencia: si ya pagado, responde 200 sin duplicar cambios.
- Endpoint adicional: `GET /payments/{payment_id}/status`.

## Fase 4 - Flutter cliente
Completada.
- Botón "Pagar con Stripe" en card y detalle de emergencia.
- Visibilidad condicionada a:
  - incidente `completed`
  - payment existe
  - payment pendiente
- Al presionar:
  - llama checkout endpoint
  - redirige a Stripe
- Nueva pantalla: `PaymentSuccessScreen`.
- Navegación robusta con query params (`onGenerateRoute`) para evitar ruta rota en retorno.

## Arquitectura final CU25
1. Cliente inicia checkout desde emergencia pendiente de pago.
2. Stripe procesa pago.
3. Stripe webhook confirma pago en backend (fuente de verdad).
4. Estado reflejado por `is_paid` y endpoint status.
5. Efectivo/QR siguen operativos en paralelo.

## Lo que permanece sin cambios (intencional)
- Sin enum `STRIPE`.
- Sin pagos nuevos paralelos.
- Sin cambios en flujo de aceptación de ofertas.
- Sin cambios en pantallas de técnico.
- Sin cambios en Angular.

## Configuración recomendada local (Flutter Web)
Para retorno correcto de Stripe al frontend Flutter:
```env
STRIPE_SUCCESS_URL=http://localhost:4200/#/payment-success
STRIPE_CANCEL_URL=http://localhost:4200/#/payment-cancel
```
Ejecutar Flutter en puerto fijo:
```bash
flutter run -d chrome --web-port=4200
```

## Verificaciones clave
- Checkout crea `stripe_session_id`.
- Webhook marca `is_paid=true` cuando `payment_status=paid`.
- `GET /payments/{id}/status` refleja estado Stripe y operativo.
- Botón cliente solo aparece en casos válidos.
