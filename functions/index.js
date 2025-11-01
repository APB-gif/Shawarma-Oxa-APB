const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });
const { DateTime } = require('luxon');

// Inicializa admin con las credenciales del entorno (Cloud Functions lo hace automáticamente).
try {
  admin.initializeApp();
} catch (e) {
  // ignore si ya inicializado
}

// Endpoint POST /getSignedUrls
// Body: { paths: ['path/in/storage/1.jpg', ...], ttlSeconds: 3600 }
exports.getSignedUrls = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
    try {
      const { paths, ttlSeconds = 3600 } = req.body || {};
      if (!Array.isArray(paths)) return res.status(400).send({ error: 'paths array required' });
      const bucket = admin.storage().bucket();
      const results = {};
      await Promise.all(paths.map(async (p) => {
        try {
          const file = bucket.file(p);
          const [url] = await file.getSignedUrl({ action: 'read', expires: Date.now() + ttlSeconds * 1000 });
          results[p] = { url };
        } catch (err) {
          results[p] = { error: err.message };
        }
      }));
      return res.json({ results });
    } catch (err) {
      console.error(err);
      return res.status(500).send({ error: err.message });
    }
  });
});

// Sincroniza roles según horarios (se ejecuta cada minuto).
// Regla:
// - Si ahora está dentro de algún horario activo para un userId -> poner rol 'trabajador' (si no es admin).
// - Si no está dentro de ningún horario activo -> si el usuario tiene rol 'trabajador' y NO tiene caja abierta, poner 'fuera de servicio' (a menos que tenga 'habilitado_fuera_horario').
// - Respeta rol 'administrador' y no lo modifica.
// - Usa timezone configurable (por defecto America/Lima).
exports.syncRolesBySchedule = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone(process.env.TIMEZONE || 'America/Lima')
  .onRun(async (context) => {
    const db = admin.firestore();
    // Zona horaria: preferimos la configuración de functions (firebase functions:config:set schedule.timezone="...")
    let TZ = 'America/Lima';
    try {
      const cfg = functions.config && functions.config();
      if (cfg && cfg.schedule && cfg.schedule.timezone) TZ = cfg.schedule.timezone;
      else if (process.env.TIMEZONE) TZ = process.env.TIMEZONE;
    } catch (e) {
      if (process.env.TIMEZONE) TZ = process.env.TIMEZONE;
    }
    const now = DateTime.now().setZone(TZ);

    try {
      const horariosSnap = await db.collection('horarios').where('active', '==', true).get();

      // Map userId -> whether at least one schedule currently applies
      const userNowMap = new Map();

      for (const doc of horariosSnap.docs) {
        const data = doc.data();
        const userId = (data.userId || '').toString();
        if (!userId) continue;

        const days = Array.isArray(data.days) ? data.days.map(d => Number(d)) : [];
        // If days provided and today not included, skip
        if (days.length > 0) {
          const weekdayIndex = now.weekday - 1; // Luxon: 1=Mon .. 7=Sun
          if (!days.includes(weekdayIndex)) continue;
        }

        const s = (data.startTime || '').toString();
        const e = (data.endTime || '').toString();
        if (!s || !e) continue;

        const sp = s.split(':').map(x => parseInt(x, 10));
        const ep = e.split(':').map(x => parseInt(x, 10));
        if (sp.length !== 2 || ep.length !== 2) continue;

        let start = DateTime.fromObject({ year: now.year, month: now.month, day: now.day, hour: sp[0], minute: sp[1] }, { zone: TZ });
        let end = DateTime.fromObject({ year: now.year, month: now.month, day: now.day, hour: ep[0], minute: ep[1] }, { zone: TZ });

        // Si end <= start significa que el turno cruza medianoche. En ese caso
        // el intervalo es [start, 23:59... ] U [00:00..., end).
        let inWindow = false;
        if (end > start) {
          // turno en el mismo día
          inWindow = now >= start && now < end;
        } else {
          // turno que cruza medianoche: true si ahora >= start (día 1)
          // o ahora < end (día siguiente)
          inWindow = (now >= start) || (now < end);
        }

        if (inWindow) {
          userNowMap.set(userId, true);
        } else if (!userNowMap.has(userId)) {
          userNowMap.set(userId, false);
        }
      }

  // Recolectar updates por usuario
      const batch = db.batch();
      const processed = new Set();

      for (const [userId, inWindow] of userNowMap.entries()) {
        if (!userId) continue;
        if (processed.has(userId)) continue;
        processed.add(userId);

        const userRef = db.collection('users').doc(userId);
        const userSnap = await userRef.get();
        if (!userSnap.exists) continue;
        const udata = userSnap.data() || {};
        const rol = (udata.rol || '').toString().toLowerCase();
        const habilitadoFuera = !!udata.habilitado_fuera_horario;
        // Si existe una expiración explícita del override, respétala; si no, por defecto tratamos el override como no activo.
        let overrideVigente = false;
        try {
          const untilTs = udata.habilitado_fuera_horario_until; // Firestore Timestamp esperado
          if (habilitadoFuera && untilTs && typeof untilTs.toMillis === 'function') {
            overrideVigente = untilTs.toMillis() > Date.now();
          }
        } catch (e) {
          // Ignorar problemas de parsing
          overrideVigente = false;
        }
        // Si el flag quedó en true pero ya expiró, lo limpiamos para evitar estados permanentes indeseados.
        if (habilitadoFuera && !overrideVigente) {
          console.log(`syncRolesBySchedule: clearing expired habilitado_fuera_horario for user ${userId}`);
          batch.update(userRef, { habilitado_fuera_horario: false, habilitado_fuera_horario_until: admin.firestore.FieldValue.delete() });
        }

        // No tocar administradores
        if (rol === 'administrador') continue;

        // Detectar si usuario tiene caja abierta en 'cajas_live'
        const liveQ = await db.collection('cajas_live').where('usuarioId', '==', userId).where('estado', '==', 'abierta').limit(1).get();
        const hasOpenCaja = !liveQ.empty;

        if (inWindow || hasOpenCaja) {
          // Si está en ventana O tiene una caja abierta, mantener/forzar rol 'trabajador'
          if (rol !== 'trabajador') {
            console.log(`syncRolesBySchedule: will set user ${userId} rol -> trabajador (inWindow=${inWindow}, hasOpenCaja=${hasOpenCaja})`);
            batch.update(userRef, { rol: 'trabajador' });
          } else {
            console.log(`syncRolesBySchedule: user ${userId} already trabajador (inWindow=${inWindow}, hasOpenCaja=${hasOpenCaja})`);
          }
        } else {
          // Fuera de ventana y sin caja abierta: si rol es trabajador y no está habilitado por admin, poner fuera de servicio
          if (rol === 'trabajador' && !overrideVigente) {
            console.log(`syncRolesBySchedule: will set user ${userId} rol -> fuera de servicio (inWindow=${inWindow}, hasOpenCaja=${hasOpenCaja})`);
            batch.update(userRef, { rol: 'fuera de servicio' });
          } else {
            console.log(`syncRolesBySchedule: no change for user ${userId} (rol=${rol}, overrideVigente=${overrideVigente}, inWindow=${inWindow}, hasOpenCaja=${hasOpenCaja})`);
          }
        }
      }

      // Ejecutar batch si hay operaciones
      await batch.commit();

      console.log(`syncRolesBySchedule: processed ${userNowMap.size} schedules at ${now.toISO()}`);
    } catch (err) {
      console.error('syncRolesBySchedule error:', err);
    }

    return null;
  });

// HTTP endpoint to create a template evening schedule (17:00 - 23:00)
// This helps admins create a reusable horario that can be assigned to users.
exports.createEveningSchedule = functions.https.onRequest(async (req, res) => {
  cors(req, res, async () => {
    try {
      const db = admin.firestore();
      const now = admin.firestore.FieldValue.serverTimestamp();
      const docRef = await db.collection('horarios').add({
        userId: '',
        userName: 'TEMPLATE - Turno Tarde 17-23',
        startTime: '17:00',
        endTime: '23:00',
        days: [0,1,2,3,4,5,6],
        active: true,
        createdAt: now,
        updatedAt: now,
      });
      return res.json({ ok: true, id: docRef.id });
    } catch (err) {
      console.error('createEveningSchedule error:', err);
      return res.status(500).json({ ok: false, error: err.message });
    }
  });
});

// ======================= IZIPAY INTEGRATION (SKELETON) =======================
// Nota: Este es un esqueleto seguro para integrar Izipay.
// - Guarda las credenciales en funciones (NO en el cliente)
//   firebase functions:config:set izipay.merchant_id="..." izipay.api_key="..." izipay.api_secret="..." izipay.base_url="https://sandbox.api.izipay.pe"
// - Si no hay credenciales configuradas, se activa un modo MOCK que devuelve URLs/QR simulados.

function getIziConfig() {
  try {
    const cfg = functions.config && functions.config();
    const iz = cfg && cfg.izipay ? cfg.izipay : {};
    return {
      merchantId: iz.merchant_id || process.env.IZIPAY_MERCHANT_ID || '',
      apiKey: iz.api_key || process.env.IZIPAY_API_KEY || '',
      apiSecret: iz.api_secret || process.env.IZIPAY_API_SECRET || '',
      baseUrl:
        iz.base_url || process.env.IZIPAY_BASE_URL || 'https://sandbox.api.izipay.pe',
    };
  } catch (e) {
    return {
      merchantId: process.env.IZIPAY_MERCHANT_ID || '',
      apiKey: process.env.IZIPAY_API_KEY || '',
      apiSecret: process.env.IZIPAY_API_SECRET || '',
      baseUrl: process.env.IZIPAY_BASE_URL || 'https://sandbox.api.izipay.pe',
    };
  }
}

const _PAYMENT_INTENTS_COL = 'payment_intents';

// Crea una intención de pago en Izipay (o MOCK) y persiste el intento.
// Body: { amount, currency, reference, method: 'card'|'qr', cajaId, ventaId, returnUrl? }
exports.izipayCreatePayment = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method Not Allowed' });
    try {
      const db = admin.firestore();
      const { amount, currency = 'PEN', reference, method, cajaId, ventaId, returnUrl } = req.body || {};
      if (!amount || !method || !cajaId) {
        return res.status(400).json({ error: 'amount, method y cajaId son requeridos' });
      }

      const cfg = getIziConfig();
      const mockMode = !cfg.apiKey || !cfg.apiSecret || !cfg.merchantId;

      const docRef = db.collection(_PAYMENT_INTENTS_COL).doc();
      const intentId = docRef.id;

      let payload = { intentId };
      let provider = 'izipay';

      if (mockMode) {
        // Simulación: generar URL/QR de prueba
        payload.checkoutUrl = `https://example.com/mock-pay?i=${intentId}`;
        payload.qrPayload = `MOCK-QR-${intentId}`;
        payload.mock = true;
      } else {
        // TODO: Implementar llamada real al API de Izipay con cfg.baseUrl/apiKey/apiSecret.
        // Mantener el skeleton para no exponer credenciales en cliente.
        // Sugerido: crear transacción/checkout para tarjetas y generar QR para Yape en Izipay.
        // Colocar las respuestas esperadas en payload.checkoutUrl / payload.qrPayload según método.
        payload.checkoutUrl = undefined;
        payload.qrPayload = undefined;
      }

      // Persistir el intento
      await docRef.set({
        status: 'created',
        provider,
        method,
        amount,
        currency,
        reference: reference || ventaId || cajaId,
        cajaId: cajaId || null,
        ventaId: ventaId || null,
        returnUrl: returnUrl || null,
        mock: !!mockMode,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
      });

      return res.json({ ok: true, intentId, ...payload });
    } catch (err) {
      console.error('izipayCreatePayment error:', err);
      return res.status(500).json({ ok: false, error: err.message });
    }
  });
});

// Consulta estado de una intención de pago
// GET /izipay/check-status?intentId=...
exports.izipayCheckStatus = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const db = admin.firestore();
      const intentId = req.query.intentId || req.body?.intentId;
      if (!intentId) return res.status(400).json({ error: 'intentId requerido' });
      const snap = await db.collection(_PAYMENT_INTENTS_COL).doc(String(intentId)).get();
      if (!snap.exists) return res.status(404).json({ error: 'Intent no encontrado' });
      const data = snap.data();
      return res.json({ ok: true, status: data.status, intent: { id: snap.id, ...data } });
    } catch (err) {
      console.error('izipayCheckStatus error:', err);
      return res.status(500).json({ ok: false, error: err.message });
    }
  });
});

// Webhook para recibir notificaciones de Izipay y actualizar el estado.
// Debe protegerse validando firma/HMAC del proveedor (pendiente en este skeleton).
exports.izipayWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // TODO: validar firma del header con secreto del proveedor.
    const db = admin.firestore();
    const body = req.body || {};
    // Intentar leer referencia/intentId desde el body genérico
    const intentId = body.intentId || body.reference || body.orderId || body.transactionId;
    const statusRaw = (body.status || body.result || '').toString().toLowerCase();
    let status = 'pending';
    if (['paid', 'success', 'approved', 'ok', 'confirmed'].includes(statusRaw)) status = 'confirmed';
    if (['failed', 'error', 'declined', 'canceled', 'cancelled'].includes(statusRaw)) status = 'failed';

    if (!intentId) {
      console.warn('Webhook sin intentId/reference');
      return res.status(202).json({ ok: true, ignored: true });
    }
    const ref = db.collection(_PAYMENT_INTENTS_COL).doc(String(intentId));
    await ref.set(
      {
        status,
        lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
        lastWebhook: body,
      },
      { merge: true }
    );
    return res.json({ ok: true });
  } catch (err) {
    console.error('izipayWebhook error:', err);
    return res.status(500).json({ ok: false, error: err.message });
  }
});

// MOCK: confirmar un intento manualmente (útil en pruebas locales)
// POST { intentId }
exports.izipayMockConfirm = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { intentId } = req.body || {};
      if (!intentId) return res.status(400).json({ error: 'intentId requerido' });
      const db = admin.firestore();
      await db
        .collection(_PAYMENT_INTENTS_COL)
        .doc(String(intentId))
        .set({ status: 'confirmed', lastUpdate: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      return res.json({ ok: true });
    } catch (err) {
      console.error('izipayMockConfirm error:', err);
      return res.status(500).json({ ok: false, error: err.message });
    }
  });
});
