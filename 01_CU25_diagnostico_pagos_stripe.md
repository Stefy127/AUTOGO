# 01 - Diagnóstico CU25: Pagos con Stripe

## 1. Resumen del flujo real
Flujo real identificado en AUTOGO (backend + app cliente/mecánico):
1. El cliente crea una emergencia con `POST /incidents` (estado inicial `PENDING`).
2. Los talleres envían propuestas con `POST /offers`; el incidente pasa a `WAITING_OFFERS`.
3. El cliente revisa ofertas y acepta una con `POST /offers/{offer_id}/accept`.
4. Al aceptar oferta:
   - `offer.status = ACCEPTED`
   - otras ofertas pendientes del incidente pasan a `REJECTED`
   - `incident.workshop_id` y `incident.technician_id` se asignan
   - `incident.status = ASSIGNED`
   - se crea `Payment` pendiente (`is_paid = false`) si no existe.
5. El mecánico inicia trabajo con `PATCH /technician/incidents/{incident_id}/status` a `IN_PROGRESS`.
6. El mecánico finaliza con el mismo endpoint a `COMPLETED`.
7. El pago puede confirmarse hoy por:
   - cliente vía QR (`POST /payments/incident/{incident_id}/pay-qr`)
   - técnico vía efectivo/QR (`POST /technician/payments/confirm`)
   - taller/admin manualmente (`PATCH /payments/{payment_id}`).

Conclusión de flujo: hoy el sistema ya tiene un pago único por incidente y el objetivo CU25 debe extender ese pago existente con Stripe, no crear un flujo paralelo.

## 2. Estado actual del backend
### Modelo `Payment`
- Archivo: `backend/app/models.py`
- Tabla: `payments`
- Campos:
  - `id` (PK)
  - `incident_id` (FK a `incidents.id`, `UNIQUE`)
  - `amount` (`numeric(10,2)`)
  - `payment_method` (`paymentmethod` enum)
  - `commission_percentage` (`double precision`)
  - `commission_amount` (`numeric(10,2)`)
  - `workshop_earnings` (`numeric(10,2)`)
  - `paid_at` (`timestamp` nullable)
  - `is_paid` (`boolean`, no nullable)
  - `reference_number` (`varchar` nullable)
  - `notes` (`text` nullable)
  - `created_at`, `updated_at`
- Relación ORM: `incident = relationship("Incident", back_populates="payment")`.

### Estados y métodos de pago actuales
- No existe `payment_status` explícito en BD.
- Estado de pago real: `is_paid` (`false = pendiente`, `true = pagado`).
- Métodos de pago (`PaymentMethod` enum): `CASH`, `TRANSFER`, `QR`.
- En API/schemas se serializa como `cash`, `transfer`, `qr`.

### Relaciones de pago
- Sí existe relación directa con incidente (`incident_id` único).
- No existe `offer_id` en `payments`.
- No existe `workshop_id` directo en `payments` (se deduce desde `incident.workshop_id`).
- No existe `client_id`/`user_id` directo en `payments` (se deduce desde `incident.user_id`).

### Comisión y neto de taller
- Sí existe comisión (por defecto 10%, configurable por taller).
- Sí existe monto neto para taller (`workshop_earnings`).
- Se calcula al crear pago (en `offers.accept_offer` y también en `/payments` creación manual).

### Referencia externa / transacción
- No existe `transaction_id` dedicado.
- Solo existe `reference_number` genérico (hoy usado por QR/manual).

### QR de taller
- Existe tabla/modelo `workshop_payment_qr` con:
  - `workshop_id` único
  - `qr_image_url`
  - `updated_at`
- Se usa en flujo cliente QR y técnico QR.

### Cuándo se crea el pago pendiente
- En flujo principal marketplace: al aceptar oferta (`POST /offers/{offer_id}/accept`), no al finalizar atención.
- El pago se crea con `is_paid = false` y método inicial `CASH`.

### Quién marca pago como pagado hoy
- Cliente QR: `POST /payments/incident/{incident_id}/pay-qr`.
- Técnico (cash/qr): `POST /technician/payments/confirm`.
- Taller/Admin: `PATCH /payments/{payment_id}` con `is_paid=true`.

## 3. Estado actual de la base de datos
Estructura validada en PostgreSQL Docker (`autogo_db`):
- `payments`:
  - FK: `payments.incident_id -> incidents.id`
  - `UNIQUE (incident_id)`
- `incidents`:
  - contiene `status`, `payment_method`, `workshop_id`, `technician_id`, timestamps de ciclo.
- `offers`:
  - contiene `status`, `amount`, `workshop_id`, `technician_id`, `incident_id`.
- `workshop_payment_qr`:
  - `UNIQUE (workshop_id)`.

Dato de muestra encontrado:
- Hay al menos 1 pago registrado y pagado (`is_paid = true`) con método `CASH`.
- No se encontró pago pendiente en la muestra actual consultada.

## 4. Estado actual de endpoints de pago
### 4.1 `POST /payments`
- JWT: sí (`get_current_user`).
- Rol: `WORKSHOP` o `ADMIN`.
- Body (`PaymentCreate`):
  - `incident_id` (int)
  - `amount` (float > 0)
  - `payment_method` (`cash|transfer|qr`)
  - `reference_number?`, `notes?`
- Valida:
  - incidente existe
  - incidente `COMPLETED`
  - no exista ya pago para ese incidente
  - si rol workshop, que incidente sea de su taller
- Modifica: tabla `payments` (insert).
- Respuesta: `PaymentResponse` (201).
- Riesgo: no es el flujo principal marketplace; puede superponerse con pagos creados previamente por aceptación de oferta.

### 4.2 `GET /payments/{payment_id}`
- JWT: sí.
- Rol: `CLIENT`, `WORKSHOP`, `ADMIN`.
- Valida ownership:
  - cliente: solo si `incident.user_id == current_user.id`
  - taller: solo si incidente pertenece a su taller
  - admin: total
- Modifica: no.
- Respuesta: `PaymentResponse`.

### 4.3 `PATCH /payments/{payment_id}`
- JWT: sí.
- Rol: `WORKSHOP` o `ADMIN`.
- Body (`PaymentUpdate`): `is_paid?`, `paid_at?`, `reference_number?`, `notes?`.
- Valida ownership para workshop.
- Lógica:
  - si `is_paid` pasa a true y antes era false, setea `paid_at = utcnow`.
- Modifica: `payments` (update).
- Respuesta: `PaymentResponse`.
- Riesgo: potencial doble confirmación/colisión con otros flujos si no se endurece idempotencia para CU25.

### 4.4 `POST /payments/incident/{incident_id}/pay-qr`
- JWT: sí.
- Rol: solo `CLIENT`.
- Params: `incident_id` path.
- Body: `PaymentQRConfirm` (`reference_number?`).
- Valida:
  - incidente existe y pertenece al cliente
  - incidente `COMPLETED`
  - pago existe
  - pago no esté pagado
  - taller tenga QR configurado
- Modifica:
  - `payments.payment_method = QR`
  - `payments.reference_number`
  - `payments.is_paid = true`
  - `payments.paid_at = now`
  - `payments.notes = "Pago QR confirmado por cliente"`
- Respuesta: `PaymentResponse`.

### 4.5 `GET /payments/incident/{incident_id}`
- JWT: sí.
- Rol: `CLIENT`, `WORKSHOP`, `ADMIN`.
- Valida ownership similar a `GET /payments/{id}`.
- Modifica: no.
- Respuesta: `PaymentResponse`.

### 4.6 `GET /payments`
- JWT: sí.
- Rol:
  - admin: todos
  - workshop: pagos de incidentes de su taller
  - client: pagos de sus incidentes
- Query: `skip`, `limit`.
- Modifica: no.
- Respuesta: `List[PaymentResponse]`.

### 4.7 `POST /technician/payments/confirm`
- JWT técnico (token de `TechnicianAccessSession`, no JWT estándar de usuario).
- Rol: técnico autenticado por portal técnico.
- Body (`TechnicianPaymentConfirm`):
  - `incident_id`
  - `payment_method` (solo `cash|qr`)
- Valida:
  - incidente pertenece al técnico
  - incidente `COMPLETED`
  - pago existente
- Modifica:
  - `payments.payment_method`
  - `payments.is_paid = true`
  - `payments.paid_at = now`
  - `payments.notes`
  - `incidents.payment_method`
- Respuesta: `PaymentResponse`.
- Riesgo: no tiene guard explícito contra re-confirmar un pago ya pagado.

## 5. Estado actual del flujo incidentes/ofertas/técnico
### Creación de emergencia
- Endpoint: `POST /incidents`.
- Resultado: incidente `PENDING`, con datos de vehículo/ubicación/descripción.

### Creación de propuestas por talleres
- Endpoint: `POST /offers` (solo workshop).
- Cambios:
  - inserta oferta `PENDING`
  - incidente pasa a `WAITING_OFFERS` (si estaba `PENDING`)
  - genera notificación al cliente.

### Aceptación de propuesta por cliente
- Endpoint: `POST /offers/{offer_id}/accept` (solo cliente dueño del incidente).
- Cambios:
  - oferta aceptada = `ACCEPTED`
  - otras ofertas pendientes = `REJECTED`
  - incidente asignado a workshop/técnico, `ASSIGNED`
  - `accepted_at`, `estimated_arrival_time`
  - crea `Payment` pendiente si no existe.

### Inicio y fin de atención por mecánico
- Endpoint: `PATCH /technician/incidents/{incident_id}/status`.
- Transiciones válidas:
  - `ASSIGNED|ACCEPTED -> IN_PROGRESS`
  - `IN_PROGRESS -> COMPLETED`
- Al completar:
  - setea `completed_at`
  - técnico vuelve `is_available = true`
  - notifica al taller.

### Impacto en pagos al finalizar
- Finalizar atención no crea pago nuevo.
- El pago ya viene del paso de aceptación de oferta.

## 6. Estado actual del frontend Angular
- Angular sí consume pagos (`frontend/src/app/services/payment.service.ts`) con:
  - `POST /payments`
  - `GET /payments/{id}`
  - `GET /payments/incident/{incident_id}`
  - `PATCH /payments/{id}`
  - `GET /payments`
- También consume QR de taller desde `workshop.service.ts` (`/workshops/me/payment-qr`).
- Por estructura actual, Angular parece orientado a panel web (admin/taller/operación), no como flujo principal del cliente móvil para CU25.
- No se encontró integración Stripe en Angular.

## 7. Estado actual de Flutter cliente/móvil
### Cliente
- API base por defecto: `http://localhost:8000` (`movile_front/lib/services/api_service.dart`).
- Flujo cliente:
  - crea emergencia (`/incidents`)
  - ve ofertas (`/incidents/{id}/offers`)
  - acepta oferta (`/offers/{offer_id}/accept`)
  - ve detalle de incidente en `EmergencyListScreen` modal.
- El bloque de pago ya se muestra en detalle cuando `incident.payment != null`.
- Estado de pago en app se deriva de `is_paid` mapeado a `status = paid|pending` en `Payment.fromJson`.

### QR en cliente
- Existe `PaymentQrScreen` que usa:
  - `GET /workshops/{workshop_id}/payment-qr`
  - `POST /payments/incident/{incident_id}/pay-qr`
- Hallazgo: `PaymentQrScreen` existe, pero no está registrado en rutas de `main.dart`.

### Mecánico
- Pantalla `TechnicianDashboardScreen`:
  - actualiza estado (`/technician/incidents/{id}/status`)
  - confirma pago (`/technician/payments/confirm`) con `cash` o `qr`.
- Requisito respetado: no tocar pantallas mecánico en CU25 por ahora.

### Dónde agregar botón "Pagar con Stripe"
- Lugar recomendado: modal de detalle en `EmergencyListScreen`, sección "Pago".
- Condición sugerida:
  - `incident.payment != null`
  - `incident.payment.status == 'pending'`
  - `incident.status == 'completed'`.

## 8. Hallazgos importantes
1. Ya existe pago único por incidente (`payments.incident_id` único): base ideal para integrar Stripe sin duplicar pagos.
2. El pago pendiente se crea temprano (al aceptar oferta), no al finalizar; esto permite mostrar CTA de pago al cliente cuando el servicio termine.
3. Existen múltiples vías para marcar pagado (cliente QR, técnico, taller/admin), por lo que CU25 necesita reglas de consistencia/idempotencia.
4. No existe almacenamiento Stripe en BD (session/payment_intent/status/currency).
5. No existe endpoint webhook Stripe.
6. `PaymentQrScreen` cliente está implementada pero no claramente integrada por rutas declarativas.
7. En backend hoy `payment_method` existe también en `incidents`; debe mantenerse coherente con `payments` al confirmar Stripe.

## 9. Dudas antes de implementar
1. ¿El monto final a cobrar será siempre el de la oferta aceptada o puede ajustarse al finalizar atención?
2. Si puede ajustarse, ¿quién y en qué momento lo autoriza (taller/mecánico/cliente)?
3. ¿La comisión se congela al crear payment o puede recalcularse al confirmar cobro?
4. ¿Se habilitará Stripe solo para incidentes `COMPLETED` (recomendado) o antes?
5. ¿Qué prioridad de fuente de verdad será oficial para estado de pago: `payments` (recomendado), `incidents.payment_method`, u otra?
6. Si un pago ya fue confirmado por QR/cash, ¿Stripe debe bloquearse siempre con `409`?
7. ¿Se requiere evidencia visual de transacción al taller/admin además de webhook?
8. ¿Cómo se manejarán diferencias de centavos/redondeo si cambia moneda o impuestos?

## 10. Propuesta de integración con Stripe Checkout
Objetivo: integrar Stripe Checkout test usando el `Payment` existente.

Diseño mínimo:
1. Cliente solicita checkout de un `payment_id` pendiente.
2. Backend valida ownership y estado (`is_paid=false`, incidente del cliente, idealmente `incident.status=COMPLETED`).
3. Backend crea `checkout.session` Stripe con metadata (`payment_id`, `incident_id`, `client_id`).
4. Backend guarda `stripe_session_id` y estado inicial en `payments`.
5. Frontend Flutter abre `checkout_url`.
6. Stripe llama webhook backend.
7. Backend verifica firma del webhook y marca `payments.is_paid=true`, `payment_method='transfer'` o nuevo método acordado (`stripe` si se decide ampliar enum), guarda `paid_at`, `stripe_payment_intent_id`, `stripe_payment_status`.
8. Cliente al volver a app consulta estado y refresca incidente/pago.

Principios:
- No crear pago paralelo.
- No permitir doble pago.
- Webhook como confirmación oficial (no depender de return URL).
- Mantener QR/efectivo funcionando.

## 11. Endpoints propuestos
### 11.1 `POST /payments/{payment_id}/stripe/checkout`
- Auth: JWT cliente.
- Recibe (body sugerido):
  - `success_url?` (opcional, backend puede usar env)
  - `cancel_url?` (opcional, backend puede usar env)
- Valida:
  - pago existe
  - pago pertenece al cliente por `incident.user_id`
  - pago no esté pagado
  - incidente en estado pagable (recomendado: `COMPLETED`)
  - no haya sesión Stripe activa incompatible
- Actualiza:
  - `payments.stripe_session_id`
  - `payments.stripe_payment_status='checkout_created'`
  - `currency` si aplica
- Devuelve:
  - `payment_id`
  - `checkout_url`
  - `stripe_session_id`
- Errores:
  - `403` no pertenece
  - `404` no existe
  - `409` ya pagado / sesión conflictiva
  - `422` monto inválido

### 11.2 `POST /payments/stripe/webhook`
- Auth: firma Stripe (`STRIPE_WEBHOOK_SECRET`), sin JWT de usuario.
- Recibe: payload webhook Stripe.
- Valida:
  - firma válida
  - evento relevante
  - metadata con `payment_id`
  - pago exista
- Actualiza (idempotente):
  - `stripe_payment_status`
  - `stripe_payment_intent_id`
  - si éxito final y `is_paid=false`: `is_paid=true`, `paid_at=now`, `payment_method` según política, `reference_number` opcional
- Devuelve: `200 {received: true}`.
- Errores:
  - `400` firma/payload inválido
  - `404` payment no encontrado
  - `409` inconsistencia de estado

### 11.3 `GET /payments/{payment_id}/status`
- Auth: cliente dueño / taller dueño / admin.
- Devuelve:
  - estado interno (`is_paid`, `paid_at`)
  - estado Stripe (`stripe_payment_status`)
  - método y montos.
- Uso principal: refresco post `success_url/cancel_url` y polling corto.

## 12. Cambios de base de datos propuestos
Estado actual vs propuesto:
- Ya existen: `payment_method`, `commission_amount`, `workshop_earnings`, `paid_at`.
- Faltan para Stripe:
  - `stripe_session_id` (varchar, nullable)
  - `stripe_payment_intent_id` (varchar, nullable)
  - `stripe_payment_status` (varchar, nullable)
  - `currency` (varchar(10), nullable, default desde env)

`status` explícito:
- Opcional. Hoy ya existe `is_paid` y funciona.
- Recomendación mínima: mantener `is_paid` como verdad operativa y agregar `stripe_payment_status` para detalle externo.
- Si se agrega `status`, definir claramente precedencia para no duplicar semántica con `is_paid`.

Migración sugerida (no ejecutar en esta fase):
- `ALTER TABLE payments ADD COLUMN ...` para campos Stripe/currency.
- Índices sugeridos:
  - índice único parcial para `stripe_session_id` no nulo.
  - índice para `stripe_payment_intent_id`.

## 13. Cambios de backend propuestos
1. `config.py`
- Agregar settings opcionales:
  - `STRIPE_SECRET_KEY`
  - `STRIPE_WEBHOOK_SECRET`
  - `STRIPE_SUCCESS_URL`
  - `STRIPE_CANCEL_URL`
  - `STRIPE_CURRENCY`

2. `payments` router
- Añadir endpoints Stripe (`checkout`, `webhook`, `status`).
- Reglas de ownership y anti-doble-pago.
- Idempotencia webhook.

3. Modelo/schemas
- Extender `Payment` y `PaymentResponse` para campos Stripe nuevos.

4. Coherencia de método de pago
- Definir política: si Stripe exitoso, qué valor final se escribe en `payment_method`.
  - Opción mínima sin tocar enum: usar `TRANSFER` como representación de pasarela.
  - Opción más explícita (más invasiva): agregar enum `STRIPE`.

## 14. Cambios de Flutter cliente propuestos
1. Pantalla objetivo
- `EmergencyListScreen` (detalle incidente, bloque "Pago").

2. Condición de visibilidad botón
- Mostrar "Pagar con Stripe" cuando:
  - `incident.payment != null`
  - `incident.payment.status == 'pending'`
  - `incident.status == 'completed'`.

3. Llamada backend
- Consumir `POST /payments/{payment_id}/stripe/checkout`.

4. Apertura de Checkout
- Flutter Web: abrir `checkout_url` en nueva pestaña o redirección en misma pestaña según UX.

5. Retorno success/cancel
- En `success_url`/`cancel_url`, volver a pantalla de detalle/lista y refrescar:
  - `GET /payments/{payment_id}/status`
  - o recargar `GET /incidents`.

6. No tocar mecánico
- Mantener `TechnicianDashboardScreen` sin cambios en CU25.

## 15. Variables de entorno necesarias
Variables propuestas:
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `STRIPE_SUCCESS_URL`
- `STRIPE_CANCEL_URL`
- `STRIPE_CURRENCY`

Ubicación propuesta:
- `docker-compose.yml` (servicio backend, entorno local dev)
- `.env.example` (si existe, para documentación)
- `backend/app/config.py` (Settings BaseSettings)

Valores de ejemplo (test):
- `STRIPE_SECRET_KEY=sk_test_xxx`
- `STRIPE_WEBHOOK_SECRET=whsec_xxx`
- `STRIPE_SUCCESS_URL=http://localhost:3000/#/payment-success`
- `STRIPE_CANCEL_URL=http://localhost:3000/#/payment-cancel`
- `STRIPE_CURRENCY=usd`

## 16. Comandos útiles de verificación
PowerShell (Docker PostgreSQL local):

```powershell
# Estructura tabla payments
docker exec autogo_postgres psql -U autogo -d autogo_db -c "\d payments"

# Estructura tabla incidents
docker exec autogo_postgres psql -U autogo -d autogo_db -c "\d incidents"

# Estructura tabla offers
docker exec autogo_postgres psql -U autogo -d autogo_db -c "\d offers"

# Estructura tabla workshop_payment_qr
docker exec autogo_postgres psql -U autogo -d autogo_db -c "\d workshop_payment_qr"

# Enumeraciones actuales
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT unnest(enum_range(NULL::paymentmethod)) AS payment_method;"
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT unnest(enum_range(NULL::incidentstatus)) AS incident_status;"
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT unnest(enum_range(NULL::offerstatus)) AS offer_status;"

# Listado de pagos recientes
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, incident_id, amount, payment_method, is_paid, paid_at, reference_number, commission_percentage, commission_amount, workshop_earnings, created_at FROM payments ORDER BY id DESC LIMIT 20;"

# Pagos pendientes + contexto incidente
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT p.id, p.incident_id, p.amount, p.payment_method, p.is_paid, i.user_id, i.workshop_id, i.status AS incident_status FROM payments p JOIN incidents i ON i.id = p.incident_id WHERE p.is_paid = false ORDER BY p.id DESC LIMIT 20;"

# Cruce incidentes-ofertas-pagos
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT i.id AS incident_id, i.status, i.user_id, i.workshop_id, o.id AS offer_id, o.status AS offer_status, o.amount AS offer_amount, p.id AS payment_id, p.is_paid FROM incidents i LEFT JOIN offers o ON o.incident_id = i.id LEFT JOIN payments p ON p.incident_id = i.id ORDER BY i.id DESC LIMIT 50;"
```

## 17. Riesgos técnicos
1. Doble confirmación de pago por carreras entre webhook y acciones manuales (técnico/taller).
2. Inconsistencia si frontend asume éxito por `success_url` antes de webhook.
3. Ambigüedad de `payment_method` para Stripe si enum no incluye valor explícito.
4. Montos desalineados si se permite editar tarifa después de crear payment.
5. Riesgo de pago no reconocido si metadata Stripe no incluye `payment_id` robusto.
6. Falta de idempotencia fuerte en webhook podría duplicar actualizaciones.
7. Posibles conflictos entre `incidents.payment_method` y `payments.payment_method`.

## 18. Criterios de aceptación del CU25
1. Cliente ve botón "Pagar con Stripe" solo cuando hay pago pendiente y servicio completado.
2. `POST /payments/{payment_id}/stripe/checkout` solo permite dueño del pago y bloquea pagos ya pagados.
3. Stripe webhook válido actualiza el mismo `payments` existente a pagado (`is_paid=true`) con `paid_at`.
4. Se guardan `stripe_session_id`, `stripe_payment_intent_id` y `stripe_payment_status`.
5. No se crean pagos duplicados ni paralelos al pago original del incidente.
6. Flujos actuales `cash` y `qr` continúan operativos sin regresión.
7. Intentos de pagar un pago ya pagado retornan error controlado (`409` o `400` definido).
8. Estado final de pago puede consultarse por endpoint de status y refleja webhook.
9. Auditoría mínima: `notes` o referencia incluye trazabilidad suficiente del cobro Stripe.

## 19. Plan de implementación sugerido por fases
Fase 1 - Backend y datos (sin UI)
1. Añadir campos Stripe a `payments` (migración).
2. Añadir variables de entorno y settings.
3. Implementar endpoint checkout con ownership + anti-doble-pago.
4. Implementar webhook firmado e idempotente.
5. Implementar endpoint status.
6. Pruebas API locales con Stripe test + Stripe CLI webhook forwarding.

Fase 2 - Flutter cliente
1. Agregar botón "Pagar con Stripe" en detalle de incidente.
2. Consumir checkout endpoint y abrir URL.
3. Manejar success/cancel y refrescar estado de pago.
4. Mostrar feedback claro de pendiente/pagado.

Fase 3 - End-to-end y hardening
1. Verificar convivencia con QR/efectivo.
2. Probar escenarios de error (webhook tardío, pago ya pagado, cancelación).
3. Validar no-regresiones en técnico/taller/admin.
4. Cerrar checklist CU25 con criterios de aceptación.
