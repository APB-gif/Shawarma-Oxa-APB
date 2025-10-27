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
    const TZ = process.env.TIMEZONE || 'America/Lima';
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
        if (end <= start) {
          // Cruza medianoche
          end = end.plus({ days: 1 });
        }

        // Normalizar ahora para comparaciones (también permitir comparaciones cuando now < start but falls into overnight window)
        let nowForCheck = now;
        if (now < start && end.day !== start.day) {
          // si ahora está antes de start y el end fue ajustado al día siguiente, sumar un día para comparar
          nowForCheck = now.plus({ days: 1 });
        }

        if (nowForCheck >= start && nowForCheck < end) {
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

        // No tocar administradores
        if (rol === 'administrador') continue;

        // Detectar si usuario tiene caja abierta en 'cajas_live'
        const liveQ = await db.collection('cajas_live').where('usuarioId', '==', userId).where('estado', '==', 'abierta').limit(1).get();
        const hasOpenCaja = !liveQ.empty;

        if (inWindow) {
          // Si está en ventana y no es administrador, poner trabajador (si no lo es ya)
          if (rol !== 'trabajador') {
            batch.update(userRef, { rol: 'trabajador' });
          }
        } else {
          // Fuera de ventana: si rol es trabajador y no tiene caja abierta y no está habilitado por admin, poner fuera de servicio
          if (rol === 'trabajador' && !hasOpenCaja && !habilitadoFuera) {
            batch.update(userRef, { rol: 'fuera de servicio' });
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
