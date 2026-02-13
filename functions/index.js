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

// -------------------- Propagación de renombres en background --------------------
// Al actualizar un producto (productos/{productId}) si cambia el campo `nombre`,
// escribimos un job en `jobs/propagateProductRename/{jobId}`. Un worker (onCreate)
// procesa el job y actualiza `gastos.items` en batches.

exports.enqueueProductRename = functions.firestore
  .document('productos/{productId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      const productId = context.params.productId;
      const oldName = (before.nombre || '').toString();
      const newName = (after.nombre || '').toString();
      if (!oldName || !newName || oldName === newName) {
        // nothing to do
        return null;
      }
      const db = admin.firestore();
      const jobRef = db.collection('jobs').doc();
      const job = {
        type: 'propagateProductRename',
        productId,
        oldName,
        newName,
        days: 30,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending'
      };
      await jobRef.set(job);
      console.log('enqueueProductRename: created job', jobRef.path, 'for', productId, oldName, '=>', newName);
      return null;
    } catch (err) {
      console.error('enqueueProductRename error:', err);
      return null;
    }
  });

// Worker: procesa jobs de propagación de nombre de producto
exports.processPropagationJob = functions.firestore
  .document('jobs/propagateProductRename/{jobId}')
  .onCreate(async (snap, context) => {
    const job = snap.data() || {};
    const jobRef = snap.ref;
    const db = admin.firestore();
    console.log('processPropagationJob: starting job', snap.id, job);
    try {
      await jobRef.update({ status: 'running', startedAt: admin.firestore.FieldValue.serverTimestamp() });

      const days = Number(job.days) || 30;
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() - days);
      const cutoffTs = admin.firestore.Timestamp.fromDate(cutoff);

      const pageSize = 200;
      let lastDoc = null;
      let totalScanned = 0;
      let totalUpdated = 0;

      while (true) {
        let q = db.collection('gastos')
          .where('createdAt', '>=', cutoffTs)
          .orderBy('createdAt', 'desc')
          .limit(pageSize);
        if (lastDoc) q = q.startAfter(lastDoc);
        const snapG = await q.get();
        if (snapG.empty) break;
        lastDoc = snapG.docs[snapG.docs.length - 1];

        const updates = [];
        for (const doc of snapG.docs) {
          totalScanned++;
          const data = doc.data() || {};
          const items = Array.isArray(data.items) ? data.items : [];
          let changed = false;
          const newItems = items.map(it => {
            try {
              const copy = JSON.parse(JSON.stringify(it));
              const prodNombre = (copy.producto && copy.producto.nombre) ? copy.producto.nombre.toString() : '';
              const prodId = (copy.productoId || '').toString();
              const itemNombre = (copy.nombre || '').toString();
              if (prodId === job.productId || prodNombre === job.oldName || itemNombre === job.oldName) {
                if (!copy.producto) copy.producto = {};
                copy.producto.nombre = job.newName;
                copy.nombre = job.newName;
                changed = true;
              }
              return copy;
            } catch (e) {
              console.warn('processPropagationJob: item parse error', doc.id, e);
              return it;
            }
          });
          if (changed) updates.push({ ref: doc.ref, items: newItems });
        }

        // apply updates in batches of 400
        let batch = db.batch();
        let ops = 0;
        for (const u of updates) {
          batch.update(u.ref, { items: u.items });
          ops++;
          if (ops >= 400) { await batch.commit(); batch = db.batch(); ops = 0; }
          totalUpdated++;
        }
        if (ops > 0) await batch.commit();

        // write progress to job doc
        await jobRef.update({ lastProgressAt: admin.firestore.FieldValue.serverTimestamp(), totalScanned, totalUpdated });

        // If fewer than pageSize docs fetched, exit
        if (snapG.docs.length < pageSize) break;
      }

      await jobRef.update({ status: 'done', finishedAt: admin.firestore.FieldValue.serverTimestamp(), totalScanned, totalUpdated });
      console.log('processPropagationJob: finished', snap.id, 'scanned', totalScanned, 'updated', totalUpdated);
      return null;
    } catch (err) {
      console.error('processPropagationJob error:', err);
      try { await jobRef.update({ status: 'failed', error: (err && err.stack) ? err.stack : String(err), failedAt: admin.firestore.FieldValue.serverTimestamp() }); } catch (e) { console.error('Could not update job status:', e); }
      return null;
    }
  });
