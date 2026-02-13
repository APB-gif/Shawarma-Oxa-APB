/*
Backup local de documentos afectados por la migración 'Aharhel' -> 'Gasto Aharhel'.

Uso:
  node backup_affected_docs.js --key 'C:\keys\service-account.json' --limit 500 --out 'backup_aharhel_docs.json'

Opciones:
  --key  Ruta al JSON de la cuenta de servicio (si no se pasa, usa GOOGLE_APPLICATION_CREDENTIALS)
  --limit Número máximo de documentos 'gastos' a leer (por defecto 1000)
  --out  Archivo de salida (por defecto backup_affected_docs.json)

Este script sólo requiere permisos de lectura en Firestore y no necesita permisos sobre Cloud Storage.
*/

const admin = require('firebase-admin');
const argv = require('minimist')(process.argv.slice(2));
const fs = require('fs');

const key = argv.key || null;
const limit = argv.limit ? parseInt(argv.limit, 10) : 1000;
const outFile = argv.out || 'backup_affected_docs.json';

if (key) process.env.GOOGLE_APPLICATION_CREDENTIALS = key;

if (!admin.apps.length) {
  try {
    if (key) {
      const cred = require(key);
      admin.initializeApp({ credential: admin.credential.cert(cred) });
    } else {
      admin.initializeApp();
    }
  } catch (e) {
    console.error('Error inicializando firebase-admin:', e.message || e);
    process.exit(1);
  }
}

(async () => {
  const db = admin.firestore();
  const result = { productos: {}, gastos: {} };

  try {
    // 1) Producto con id 'Aharhel' (si existe)
    const prodRef = db.collection('productos').doc('Aharhel');
    const prodSnap = await prodRef.get();
    if (prodSnap.exists) result.productos['Aharhel'] = prodSnap.data();

    // 2) Scan de gastos hasta 'limit' y seleccionar aquellos que contienen items.nombre == 'Aharhel'
    let gastosQuery = db.collection('gastos').orderBy('createdAt', 'desc').limit(limit);
    const gastosSnap = await gastosQuery.get();
    console.log(`Documentos 'gastos' leídos: ${gastosSnap.size}`);

    gastosSnap.forEach(doc => {
      const data = doc.data() || {};
      const items = Array.isArray(data.items) ? data.items : [];
      let match = false;
      for (const it of items) {
        if (!it || !it.nombre) continue;
        if ((it.nombre || '').toString().toLowerCase().trim() === 'aharhel') {
          match = true;
          break;
        }
      }

      // también revisar claves de pagos que contengan 'gasto aharhel'
      if (!match && data.pagos && typeof data.pagos === 'object') {
        for (const k of Object.keys(data.pagos)) {
          const lower = (k || '').toString().toLowerCase().trim();
          if (lower === 'gasto aharhel' || lower === 'gasto_aharhel') {
            match = true;
            break;
          }
        }
      }

      if (match) result.gastos[doc.id] = data;
    });

    fs.writeFileSync(outFile, JSON.stringify(result, null, 2), 'utf8');
    console.log('Backup escrito en', outFile, Object.keys(result.gastos).length, 'gastos y', Object.keys(result.productos).length, 'productos.');
    process.exit(0);
  } catch (err) {
    console.error('Error durante el backup:', err);
    process.exit(1);
  }
})();
