# Integración Izipay (Skeleton)

Este repo incluye un esqueleto funcional para integrar pagos Izipay (tarjeta y QR/Yape) usando Cloud Functions y Flutter.

## Componentes

- Cloud Functions (HTTP onRequest):
  - `izipayCreatePayment` (POST): crea un intento de pago y devuelve `intentId` y `checkoutUrl` (tarjeta) o `qrPayload` (QR).
  - `izipayCheckStatus` (GET): consulta estado de un `intentId`.
  - `izipayWebhook` (POST): punto de notificación del proveedor que actualiza el estado del intento.
  - `izipayMockConfirm` (POST): marca un intento como confirmado (para pruebas locales/sandbox).

- App Flutter:
  - Servicio: `lib/datos/servicios/izipay_service.dart` para consumir los endpoints.
  - UI: `lib/presentacion/ventas/panel_pago.dart` detecta si el pago incluye Tarjeta (Izipay) o IziPay Yape y, antes de registrar la venta, crea el intento, abre el flujo (URL de pago o QR) y espera la confirmación. Al confirmar, registra la venta localmente.

## Modo MOCK

Si no configuras credenciales de Izipay en las funciones, el backend devuelve datos simulados (`checkoutUrl` ficticia y `qrPayload` "MOCK-QR-<id>"). Puedes llamar a `izipayMockConfirm` para marcar el pago como `confirmed` y probar el flujo completo en la app.

## Configuración (sandbox/producción)

1) Configura las credenciales en Cloud Functions (no las pongas en el cliente):

```
firebase functions:config:set \
  izipay.merchant_id="<MERCHANT_ID>" \
  izipay.api_key="<API_KEY>" \
  izipay.api_secret="<API_SECRET>" \
  izipay.base_url="https://sandbox.api.izipay.pe"
```

2) Despliega las funciones:

```
firebase deploy --only functions:izipayCreatePayment,functions:izipayCheckStatus,functions:izipayWebhook,functions:izipayMockConfirm
```

3) Configura el webhook en el panel de Izipay apuntando a:

```
https://us-central1-<PROJECT_ID>.cloudfunctions.net/izipayWebhook
```

> Reemplaza `<PROJECT_ID>` por tu ID de proyecto (aquí: `shawarmaoxa-pos`).

4) (Opcional) Implementa validación de firma/HMAC en `izipayWebhook` antes de ir a producción.

## Consideraciones

- La app no registra la venta hasta que el pago externo se confirme, para mantener consistencia.
- En este skeleton sólo se permite **un** método Izipay por venta (Tarjeta **o** IziPay Yape). Efectivo/Yape Personal pueden combinarse sin problema.
- Para una experiencia más robusta, se puede:
  - Persistir `ventaId` junto con el intent y escuchar (realtime) el cambio de estado en Firestore.
  - Agregar reintentos y mejor manejo de timeouts.
  - Completar la llamada real al API de Izipay en `functions/index.js` usando las credenciales configuradas.
