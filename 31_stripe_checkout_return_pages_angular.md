# 31 - Páginas públicas de retorno Stripe Checkout en Angular

## 1. Objetivo
Agregar páginas públicas en Angular para recibir al usuario cuando Stripe Checkout redirige luego de un pago exitoso o cancelado.

Estas páginas evitan que las URLs configuradas en Stripe caigan en una ruta inexistente del frontend web.

## 2. Rutas creadas
Se agregaron dos rutas públicas:

| Ruta Angular | URL con hash routing | Propósito |
|---|---|---|
| `/payment-success` | `http://localhost:4200/#/payment-success` | Mostrar confirmación visual de pago exitoso |
| `/payment-cancel` | `http://localhost:4200/#/payment-cancel` | Mostrar aviso visual de pago cancelado |

Las rutas se registraron sin `AuthGuard` y antes de las rutas protegidas y del wildcard.

## 3. Relación con STRIPE_SUCCESS_URL y STRIPE_CANCEL_URL
En desarrollo local, las variables esperadas son:

```env
STRIPE_SUCCESS_URL=http://localhost:4200/#/payment-success
STRIPE_CANCEL_URL=http://localhost:4200/#/payment-cancel
```

En producción o despliegue universitario se debe reemplazar `localhost` por el dominio público real del frontend:

```env
STRIPE_SUCCESS_URL=https://tu-dominio.com/#/payment-success
STRIPE_CANCEL_URL=https://tu-dominio.com/#/payment-cancel
```

Si el backend agrega parámetros como `session_id`, la ruta de éxito puede recibirlos así:

```txt
http://localhost:4200/#/payment-success?session_id={CHECKOUT_SESSION_ID}
```

## 4. Componentes creados
Componentes creados:

- `frontend/src/app/components/payment-success/payment-success.component.ts`
- `frontend/src/app/components/payment-success/payment-success.component.html`
- `frontend/src/app/components/payment-success/payment-success.component.css`
- `frontend/src/app/components/payment-cancel/payment-cancel.component.ts`
- `frontend/src/app/components/payment-cancel/payment-cancel.component.html`
- `frontend/src/app/components/payment-cancel/payment-cancel.component.css`

También se actualizaron:

- `frontend/src/app/app-routing.module.ts`
- `frontend/src/app/app.module.ts`

## 5. Por qué no requieren autenticación
Estas páginas son públicas porque Stripe redirige desde un dominio externo y el usuario puede no tener sesión activa en Angular Web.

No deben depender de token, sidebar, dashboard ni layout admin.

La seguridad del pago no depende de estas páginas. La confirmación real debe seguir viniendo desde el backend mediante webhook de Stripe.

## 6. Qué hacen y qué no hacen
La página `/payment-success`:

- Muestra una card centrada con el título `Pago exitoso`.
- Muestra el mensaje `Tu pago fue procesado correctamente.`
- Lee opcionalmente el query param `session_id`.
- No muestra el placeholder `{CHECKOUT_SESSION_ID}` si llega sin reemplazar.
- Ofrece botón `Ir al inicio`.

La página `/payment-cancel`:

- Muestra una card centrada con el título `Pago cancelado`.
- Muestra el mensaje `El proceso de pago fue cancelado o no se completó.`
- Ofrece botón `Ir al inicio`.

Estas páginas no hacen:

- No validan pagos desde frontend.
- No marcan pagos como pagados.
- No llaman endpoints Stripe.
- No reemplazan el webhook.
- No requieren login.
- No usan layout admin.

## 7. Cómo probar
1. Ejecutar Angular:

```powershell
cd frontend
npm start
```

2. Abrir la ruta de éxito:

```txt
http://localhost:4200/#/payment-success
```

Resultado esperado:

- Muestra página `Pago exitoso`.
- No pide login.
- No muestra sidebar admin.
- No redirige a `/login`.

3. Abrir la ruta de éxito con `session_id`:

```txt
http://localhost:4200/#/payment-success?session_id=cs_test_123
```

Resultado esperado:

- Muestra la sesión `cs_test_123`.

4. Abrir la ruta de cancelación:

```txt
http://localhost:4200/#/payment-cancel
```

Resultado esperado:

- Muestra página `Pago cancelado`.
- No pide login.
- No muestra sidebar admin.
- No redirige a `/login`.

5. Verificar build:

```powershell
cd frontend
npm run build -- --configuration production
```
