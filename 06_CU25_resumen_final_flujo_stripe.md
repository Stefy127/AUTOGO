# 06 - CU25: Gestión de pago mediante pasarela Stripe

## 1. Objetivo del caso de uso
El CU25 tiene como objetivo integrar una pasarela de pago (Stripe en modo test) al flujo real de AUTOGO para que el cliente pueda pagar una atención completada de forma digital, manteniendo trazabilidad, seguridad y coherencia con el modelo de negocio existente.

Problema que resuelve:
- Antes del CU25, el pago se resolvía por efectivo o QR y no existía confirmación automática desde una pasarela.
- Era necesario incorporar una opción de cobro online sin romper flujos actuales y sin crear pagos duplicados.

Resultado esperado del CU25:
- Reutilizar el `Payment` ya existente del incidente.
- Cobrar con Stripe Checkout (test).
- Confirmar oficialmente el pago mediante webhook firmado.

## 2. Alcance funcional
Incluye:
- Integración Stripe Checkout en backend.
- Confirmación de pago por webhook Stripe.
- Exposición de endpoint de estado del pago.
- Integración de botón de pago en Flutter cliente (`Mis Emergencias`).
- Pantalla de éxito de pago en Flutter.

No incluye:
- No integra cobros reales de producción (solo Stripe test).
- No modifica Angular.
- No modifica flujo de técnico, QR o efectivo.
- No agrega enum nuevo para Stripe.

## 3. Flujo funcional completo
1. El cliente crea una emergencia.
2. Los talleres reciben la emergencia.
3. Los talleres envían propuestas con precio y técnico.
4. El cliente acepta una oferta.
5. Al aceptar oferta se crea un `Payment` pendiente asociado al incidente.
6. El mecánico inicia atención.
7. El mecánico finaliza atención.
8. Si el incidente está `COMPLETED` y el pago sigue pendiente, el cliente ve “Pagar con Stripe” en `Mis Emergencias`.
9. El cliente abre Stripe Checkout y realiza el pago (test).
10. Stripe envía webhook al backend.
11. El backend valida firma del webhook.
12. El backend actualiza el `Payment` existente:
   - `is_paid = true`
   - `paid_at = utcnow`
   - `payment_method = transfer`
   - `stripe_payment_intent_id = pi_...`
   - `stripe_payment_status = paid`
   - `reference_number = pi_...`
13. El cliente vuelve a `PaymentSuccessScreen`.
14. Al volver a `Mis Emergencias`, el botón de pago ya no aparece para ese incidente.

## 4. Flujo técnico completo
### 4.1 Inicio de checkout
Flutter cliente (`EmergencyListScreen`) llama:
- `POST /payments/{payment_id}/stripe/checkout`

Backend valida ownership, estado del incidente y estado de pago, crea sesión Stripe y devuelve `checkout_url`.

### 4.2 Ejecución en Stripe
Cliente es redirigido a `https://checkout.stripe.com/...` en modo test.

### 4.3 Confirmación oficial
Stripe llama:
- `POST /payments/stripe/webhook`

El backend:
- valida firma con `STRIPE_WEBHOOK_SECRET`
- procesa `checkout.session.completed`
- marca pagado el `Payment` si `payment_status == paid`

### 4.4 Consulta de estado
Cualquier actor autorizado consulta:
- `GET /payments/{payment_id}/status`

## 5. Estado previo del sistema
Antes de Stripe, AUTOGO ya tenía:
- Tabla `payments` funcional.
- Métodos de pago operativos: `cash`, `qr`, `transfer`.
- Flujo QR y flujo efectivo activos.
- Comisión y neto de taller calculados:
  - `commission_amount`
  - `workshop_earnings`
- Modelo de un solo pago por incidente (`payments.incident_id` único).

## 6. Cambios en base de datos
Tabla principal: `payments`.

Campos relevantes existentes:
- `id`
- `incident_id` (FK único)
- `amount`
- `payment_method`
- `commission_percentage`
- `commission_amount`
- `workshop_earnings`
- `is_paid`
- `paid_at`
- `reference_number`
- `notes`

Campos nuevos para Stripe:
- `stripe_session_id`
- `stripe_payment_intent_id`
- `stripe_payment_status`
- `currency`

Relación clave:
- `payments.incident_id -> incidents.id`

Motivo de diseño:
- No se creó otro `Payment` para Stripe.
- Se reutiliza el pago único existente del incidente para evitar duplicación y desalineación de estado.

## 7. Cambios en backend
### 7.1 Configuración Stripe
En `backend/app/config.py` se agregaron:
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `STRIPE_SUCCESS_URL`
- `STRIPE_CANCEL_URL`
- `STRIPE_CURRENCY`

### 7.2 Endpoint checkout
- `POST /payments/{payment_id}/stripe/checkout`

Validaciones:
- solo cliente autenticado
- pago existente
- pago del cliente dueño del incidente
- pago pendiente (`is_paid=false`)
- incidente `COMPLETED`
- monto tomado desde `payment.amount`

Acciones:
- crea Stripe Checkout Session
- metadata enviada a Stripe:
  - `payment_id`
  - `incident_id`
  - `client_id`
- guarda en BD:
  - `stripe_session_id`
  - `stripe_payment_status`
  - `currency`

### 7.3 Endpoint webhook
- `POST /payments/stripe/webhook` (sin JWT)

Validaciones:
- firma Stripe obligatoria
- payload válido

Eventos manejados:
- `checkout.session.completed`
- `checkout.session.async_payment_failed`
- `checkout.session.expired`

Lógica principal en `checkout.session.completed`:
- busca `payment_id` en metadata
- valida consistencia de `stripe_session_id`
- idempotencia: si `is_paid=true`, responde 200 sin duplicar cambios
- si `payment_status == paid`, confirma pago:
  - `is_paid=true`
  - `paid_at=utcnow`
  - `payment_method=transfer`
  - `stripe_payment_intent_id`
  - `stripe_payment_status`
  - `reference_number=payment_intent`
  - `notes="Pago confirmado por Stripe Checkout"`
  - `incident.payment_method=transfer`

Corrección de compatibilidad aplicada:
- se valida firma con `stripe.Webhook.construct_event(...)`
- luego se parsea payload con `json.loads(...)`
- no se usa `to_dict_recursive()`

### 7.4 Endpoint status
- `GET /payments/{payment_id}/status`

Permisos:
- cliente dueño
- taller dueño
- admin

Devuelve:
- estado operativo (`is_paid`, `paid_at`, `payment_method`)
- trazabilidad Stripe (`stripe_session_id`, `stripe_payment_intent_id`, `stripe_payment_status`, `currency`)
- montos (`amount`, `commission_amount`, `workshop_earnings`)

### 7.5 Reglas de seguridad y validación
- pago solo por cliente dueño
- no pago sobre incidente no completado
- no pago duplicado
- webhook firmado obligatorio
- webhook idempotente
- sin creación de nuevos pagos

### 7.6 Endpoints implementados para Stripe

| Endpoint | Método | Propósito |
|---|---|---|
| `/payments/{payment_id}/stripe/checkout` | POST | Crear una sesión Stripe Checkout para un pago pendiente existente |
| `/payments/stripe/webhook` | POST | Recibir la confirmación oficial de Stripe mediante webhook firmado |
| `/payments/{payment_id}/status` | GET | Consultar el estado actualizado del pago y la trazabilidad Stripe |

## 8. Cambios en Flutter cliente
Pantalla principal afectada:
- `EmergencyListScreen`

Implementado:
- botón “Pagar con Stripe” en card y detalle de emergencia
- condición de visibilidad:
  - incidente completado
  - payment existente
  - payment pendiente
- acción del botón:
  - llama checkout endpoint
  - redirige a `checkout_url`

Nueva pantalla:
- `PaymentSuccessScreen`
  - confirma al usuario que el flujo fue procesado
  - botones para volver a `Mis Emergencias` o `Inicio`

Rutas:
- `/payment-success`
- `/payment-cancel`
- manejo robusto con `onGenerateRoute` para query params

Corrección UX aplicada:
- no mostrar sesión si viene `null`, vacía o placeholder `{CHECKOUT_SESSION_ID}`

## 9. Reglas de negocio implementadas
1. Solo cliente dueño puede pagar.
2. Solo pago pendiente (`is_paid=false`).
3. Solo incidente completado (`COMPLETED`).
4. No doble pago.
5. Monto definido por backend (`payment.amount`).
6. Confirmación oficial por webhook (no por success_url).
7. `payment_method=transfer` representa pago Stripe confirmado. (Se decidió no agregar un nuevo enum `STRIPE` para reducir impacto en la base de datos y mantener compatibilidad con los flujos existentes. Por esa razón, cuando Stripe confirma el pago, el método se registra como `transfer`, mientras que la trazabilidad específica de Stripe queda almacenada en `stripe_session_id`, `stripe_payment_intent_id` y `stripe_payment_status`.)
8. Flujos `cash` y `qr` permanecen intactos.

## 10. Variables de entorno
| Variable | Ejemplo local | Descripción | Dónde configurarla |
|---|---|---|---|
| `STRIPE_SECRET_KEY` | `sk_test_xxx` | Clave secreta Stripe test para crear Checkout Session | `.env` local, entorno backend |
| `STRIPE_WEBHOOK_SECRET` | `whsec_xxx` | Secreto para validar firma de webhook | `.env` local, entorno backend |
| `STRIPE_SUCCESS_URL` | `http://localhost:4200/#/payment-success` | URL de retorno exitoso para frontend Flutter web | `.env` local / despliegue |
| `STRIPE_CANCEL_URL` | `http://localhost:4200/#/payment-cancel` | URL de cancelación de checkout | `.env` local / despliegue |
| `STRIPE_CURRENCY` | `usd` | Moneda usada al crear checkout | `.env` local / despliegue |

## 11. Prueba local paso a paso
### 11.1 Levantar backend
```bash
docker compose down
docker compose build --no-cache backend
docker compose up -d
```

### 11.2 Escuchar webhook con Stripe CLI
```bash
stripe listen --forward-to localhost:8000/payments/stripe/webhook
```
Copiar `whsec_...` y setearlo en `.env`.

### 11.3 Ejecutar Flutter web
```bash
flutter run -d chrome --web-port=4200 --dart-define=API_BASE_URL=http://localhost:8000
```

### 11.4 Flujo funcional
1. Iniciar sesión como cliente.
2. Abrir incidente completado con pago pendiente.
3. Presionar “Pagar con Stripe”.
4. Completar pago test en Stripe.
5. Confirmar webhook 200.
6. Volver al frontend y validar estado.

Tarjeta de prueba Stripe utilizada:

- Número: `4242 4242 4242 4242`
- Fecha: cualquier fecha futura
- CVC: cualquier valor de 3 dígitos
- ZIP/código postal: cualquier valor válido

Estos datos corresponden al entorno de prueba de Stripe y no generan cobros reales.

### 11.5 Verificación BD
```bash
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, incident_id, is_paid, paid_at, payment_method, stripe_payment_intent_id, stripe_payment_status FROM payments ORDER BY id DESC LIMIT 10;"
```

## 12. Resultado esperado en BD
Antes de pagar:
- `is_paid=false`
- `payment_method=cash` (o valor previo del flujo)
- `stripe_payment_status=unpaid` (u otro estado inicial)

Después de webhook exitoso (`paid`):
- `is_paid=true`
- `paid_at` con timestamp
- `payment_method=transfer`
- `stripe_payment_status=paid`
- `stripe_payment_intent_id=pi_...`
- `reference_number=pi_...`

## 13. Consideraciones para despliegue universitario
El despliegue seguirá en Stripe test.

Recomendaciones:
1. Usar `STRIPE_SECRET_KEY=sk_test_...`.
2. Crear webhook en Stripe Dashboard (modo test) apuntando a:
   - `https://BACKEND_PUBLICO/payments/stripe/webhook`
3. Configurar `STRIPE_WEBHOOK_SECRET=whsec_...` del endpoint público.
4. Ajustar `STRIPE_SUCCESS_URL` y `STRIPE_CANCEL_URL` al frontend público Flutter.
5. Compilar Flutter con `API_BASE_URL` del backend público.
6. Configurar CORS backend para dominio frontend público.
7. No subir `.env` ni exponer claves en repositorio.

## 14. Pruebas de aceptación
1. El botón aparece solo cuando corresponde.
2. Checkout abre correctamente.
3. Webhook responde 200 con firma válida.
4. `Payment` pasa a pagado cuando Stripe confirma `paid`.
5. El botón desaparece tras pago confirmado.
6. QR/efectivo siguen funcionando.
7. Intento de doble pago se bloquea.

## 15. Riesgos y mitigaciones
- Webhook tardío:
  - Mitigación: la confirmación oficial depende de webhook e idempotencia.
- Usuario vuelve antes de confirmación:
  - Mitigación: endpoint status refleja estado real y UI refresca.
- `session_id` inválido/placeholder:
  - Mitigación: no se muestra en `PaymentSuccessScreen`.
- Doble intento de pago:
  - Mitigación: validación `is_paid` y control de consistencia sesión.
- Claves no configuradas:
  - Mitigación: errores controlados en backend.
- CORS en despliegue:
  - Mitigación: configurar orígenes permitidos correctamente.
- URLs con hash routing:
  - Mitigación: construir query dentro del fragmento `#/...?...`.

## 16. Conclusión
El CU25 quedó implementado como integración Stripe test sobre el flujo real de AUTOGO, sin romper pagos existentes y sin introducir pagos paralelos. La solución conserva la arquitectura actual (un pago por incidente), delega la confirmación oficial al webhook firmado de Stripe y mantiene compatibilidad plena con QR, efectivo y operación del técnico. Desde perspectiva académica y técnica, el caso de uso cumple trazabilidad, seguridad e idempotencia, y está listo para validación y despliegue universitario en modo test.
