# 05 - CU25 Fase 4: UI Cliente Flutter + Redirección Stripe

## 1. Objetivo
Implementar en Flutter cliente el inicio de pago con Stripe desde Mis Emergencias, mostrando el botón solo cuando corresponde y corrigiendo la navegación de retorno.

## 2. Archivos modificados
1. `movile_front/lib/screens/emergency_list_screen.dart`
2. `movile_front/lib/screens/payment_success_screen.dart` (nuevo)
3. `movile_front/lib/main.dart`

## 3. Cambios implementados
### 3.1 Botón "Pagar con Stripe" en card de emergencia
Se agregó botón en la card de emergencia de `EmergencyListScreen` y también en el modal de detalle.

Se muestra solo cuando:
- `incident.status == 'completed'`
- `incident.payment != null`
- `incident.payment.status != 'paid'`

### 3.2 Llamada al endpoint checkout
Al presionar el botón:
- Se llama `POST /payments/{payment_id}/stripe/checkout`.
- No se envía monto desde frontend.
- Se toma `checkout_url` de la respuesta.

### 3.3 Redirección a Stripe
- Se usa `url_launcher`.
- Se abre checkout con `webOnlyWindowName: '_self'` para redirigir en la misma pestaña en web.

### 3.4 PaymentSuccessScreen
Se creó `PaymentSuccessScreen` con:
- Mensaje de pago recibido.
- Lectura de `payment_id` y `session_id` desde query params.
- Botón: volver a Mis Emergencias.
- Botón adicional: ir a Inicio.

### 3.5 Corrección de ruta de retorno
En `main.dart` se agregó `onGenerateRoute` para resolver rutas con query string, por ejemplo:
- `/payment-success?payment_id=...&session_id=...`

Sin este manejo, el retorno podía caer en ruta no encontrada.

También se agregó ruta de cancelación:
- `/payment-cancel` -> `EmergencyListScreen`

## 4. Configuración recomendada de URLs Stripe para Flutter Web
Para evitar ruta rota, usar URLs de retorno que apunten al frontend Flutter Web (no Angular). Ejemplo:

```env
STRIPE_SUCCESS_URL=http://localhost:4200/#/payment-success
STRIPE_CANCEL_URL=http://localhost:4200/#/payment-cancel
```

Y ejecutar Flutter web en puerto fijo:
```bash
flutter run -d chrome --web-port=4200
```

## 5. Prueba funcional rápida
1. Levantar backend y asegurar webhook/config Stripe.
2. Ejecutar Flutter web en puerto fijo.
3. Entrar a Mis Emergencias.
4. Abrir incidente completado con pago pendiente.
5. Ver botón "Pagar con Stripe".
6. Presionar botón y confirmar redirección a Stripe Checkout.
7. Al volver a success URL, confirmar que abre `PaymentSuccessScreen`.
8. Usar botón para volver a Mis Emergencias o Inicio.

## 6. Qué no se cambió
- No se tocó Angular.
- No se tocó Flutter mecánico.
- No se cambió flujo QR/efectivo/técnico.
- No se agregaron enums nuevos.
- No se crearon pagos nuevos.

## Nota de correccion CU25
- Se corrigio la construccion de `success_url` y `cancel_url` para hash routes, quedando en formato `http://localhost:4200/#/payment-success?payment_id=<id>&session_id={CHECKOUT_SESSION_ID}`.
- En `PaymentSuccessScreen`, ya no se muestra la linea de sesion cuando `session_id` es nulo, vacio o contiene `CHECKOUT_SESSION_ID`.
