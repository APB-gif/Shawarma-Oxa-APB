Get signed URLs for Firebase Storage

Deploy:
1. Install Firebase CLI and login: `npm i -g firebase-tools` then `firebase login`.
2. From this `functions/` folder run `npm install`.
3. Deploy only the function: `firebase deploy --only functions:getSignedUrls`.

Usage (POST):
POST https://<REGION>-<PROJECT>.cloudfunctions.net/getSignedUrls
Body JSON: { "paths": ["categoria/123.jpg"], "ttlSeconds": 3600 }
Response: { results: { "categoria/123.jpg": { url: "https://..." } } }

Notes:
- The function uses the default Storage bucket of the project.
- Secure it by validating Firebase ID tokens in Authorization header if needed.

---

# Izipay Integration (Skeleton)

Endpoints (HTTP onRequest):

- izipayCreatePayment (POST)
	- Body: { amount:number, currency?:"PEN", reference?:string, method:"card"|"qr", cajaId:string, ventaId?:string, returnUrl?:string }
	- Response: { ok:true, intentId, checkoutUrl?, qrPayload?, mock:boolean }
	- Nota: Si no hay credenciales configuradas en Functions, se activa modo MOCK y devuelve datos simulados.

- izipayCheckStatus (GET)
	- Query: intentId
	- Response: { ok:true, status:"created|pending|confirmed|failed", intent:{...} }

- izipayWebhook (POST)
	- Recibe notificaciones del proveedor. Debe validarse la firma/HMAC (pendiente en skeleton).
	- Actualiza /payment_intents/{intentId} con { status }.

- izipayMockConfirm (POST)
	- Body: { intentId }
	- Marca el intento como "confirmed" (útil en pruebas locales).

Configurar credenciales (sandbox/producción):

```
firebase functions:config:set \
	izipay.merchant_id="<MERCHANT_ID>" \
	izipay.api_key="<API_KEY>" \
	izipay.api_secret="<API_SECRET>" \
	izipay.base_url="https://sandbox.api.izipay.pe"
```

Luego desplegar:

```
firebase deploy --only functions:izipayCreatePayment,functions:izipayCheckStatus,functions:izipayWebhook,functions:izipayMockConfirm
```

Colección Firestore usada:

- payment_intents: persiste intentos con campos { status, method, amount, currency, cajaId, ventaId, reference, mock, createdAt, lastUpdate, lastWebhook? }

Seguridad y notas:

- No expongas claves en el cliente. Mantén izipay.* solo en Functions config.
- Implementa validación de firma en izipayWebhook antes de ir a producción.
- En producción, considera mover los intents relacionados a una subcolección por caja en `cajas_live/{cajaId}` para señales realtime.
