/*
Script de migración para Firestore: renombra productos y items 'Aharhel' a 'Gasto Aharhel',
y corrige claves de pagos 'Gasto Aharhel' -> 'Aharhel' en documentos de la colección 'gastos'.

Comportamiento:
 - Dry-run por defecto: lista cantidad de documentos afectados y muestra ejemplos.
 - --apply para ejecutar los cambios.
 - --limit <n> para limitar documentos procesados (útil para pruebas).
 - Requiere GOOGLE_APPLICATION_CREDENTIALS apuntando a JSON de service account o --key <path>.

Uso (PowerShell):
 $env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\path\to\service-account.json'; node migrate_producto_aharhel.js --dry-run
 node migrate_producto_aharhel.js --apply --limit 100

Nota: Haz backup de tus datos antes de ejecutar --apply.
*/

const admin = require('firebase-admin');
const argv = require('minimist')(process.argv.slice(2));

async function main() {
  const apply = !!argv.apply;
  const limit = argv.limit ? parseInt(argv.limit, 10) : null;
  const keyPath = argv.key || null;

  if (keyPath) process.env.GOOGLE_APPLICATION_CREDENTIALS = keyPath;

  // Inicializar firebase-admin. Si la variable de entorno GOOGLE_APPLICATION_CREDENTIALS
  // está definida, admin SDK la usará automáticamente. Si se pasó --key, la usamos directamente.
  if (!admin.apps.length) {
    try {
      if (keyPath) {
        // require() acepta rutas absolutas a JSON
        const cred = require(keyPath);
        admin.initializeApp({ credential: admin.credential.cert(cred) });
      } else {
        admin.initializeApp();
      }
    } catch (e) {
      console.log('Inicializando admin SDK usando GOOGLE_APPLICATION_CREDENTIALS...');
      admin.initializeApp();
    }
  }

  const firestore = admin.firestore();
  console.log('Conectando a Firestore... (firebase-admin)');

  // 1) Productos: renombrar documentos en 'productos' cuyo nombre sea 'Aharhel' (case-insensitive)
  let prodQuery = firestore.collection('productos').where('nombre', '==', 'Aharhel');
  // Nota: Firestore no tiene case-insensitive queries; si tus datos usan variantes, considera usar un índice auxiliar o listar todos y filtrar localmente.

  const prodSnap = await prodQuery.get();
  console.log(`Productos encontrados con nombre exacto 'Aharhel': ${prodSnap.size}`);

  const prodChanges = [];
  prodSnap.forEach(doc => {
    prodChanges.push({ id: doc.id, before: doc.data(), after: { ...doc.data(), nombre: 'Gasto Aharhel' } });
  });

  // 2) Gastos: actualizar items.nombre y pagos keys
  let gastosQuery = firestore.collection('gastos').orderBy('createdAt', 'desc');
  if (limit) gastosQuery = gastosQuery.limit(limit);

  const gastosSnap = await gastosQuery.get();
  console.log(`Documentos 'gastos' leídos: ${gastosSnap.size}`);

  const gastosToUpdate = [];

  gastosSnap.forEach(doc => {
    const data = doc.data() || {};
    let updated = false;
    const newData = {};

    // items
    const items = Array.isArray(data.items) ? data.items.map(it => ({ ...it })) : [];
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      if (!it || !it.nombre) continue;
      const lower = (it.nombre || '').toString().toLowerCase().trim();
      if (lower === 'aharhel') {
        items[i].nombre = 'Gasto Aharhel';
        updated = true;
      }
    }
    if (updated) newData.items = items;

    // pagos keys: si existe 'Gasto Aharhel' (o 'gasto aharhel'), renombrar a 'Aharhel'
    const pagos = (data.pagos && typeof data.pagos === 'object') ? { ...data.pagos } : null;
    if (pagos) {
      const keys = Object.keys(pagos);
      const newPagos = {};
      let pagosChanged = false;
      for (const k of keys) {
        const lower = (k || '').toString().toLowerCase().trim();
        if (lower === 'gasto aharhel' || lower === 'gasto_aharhel') {
          newPagos['Aharhel'] = (newPagos['Aharhel'] || 0) + pagos[k];
          pagosChanged = true;
        } else {
          newPagos[k] = (newPagos[k] || 0) + pagos[k];
        }
      }
      if (pagosChanged) {
        newData.pagos = newPagos;
        updated = true;
      }
    }

    if (updated) {
      gastosToUpdate.push({ id: doc.id, before: data, after: { ...data, ...newData } });
    }
  });

  console.log(`Gastos a actualizar: ${gastosToUpdate.length}`);
  if (gastosToUpdate.length > 0) {
    console.log('Ejemplos (hasta 5):');
    gastosToUpdate.slice(0, 5).forEach(x => {
      console.log(`- id=${x.id}`);
      console.log('  before items:', x.before.items);
      console.log('  after items: ', x.after.items);
      if (x.before.pagos) console.log('  before pagos:', x.before.pagos);
      if (x.after.pagos) console.log('  after pagos: ', x.after.pagos);
    });
  }

  console.log(`Productos a actualizar: ${prodChanges.length}`);
  if (prodChanges.length > 0) {
    prodChanges.slice(0, 5).forEach(x => {
      console.log(`- producto id=${x.id} before nombre='${x.before.nombre}' after nombre='${x.after.nombre}'`);
    });
  }

  if (!apply) {
    console.log('\nModo dry-run. Para aplicar los cambios ejecuta con --apply');
    return;
  }

  // Aplicar cambios en productos
  for (const pc of prodChanges) {
    const ref = firestore.collection('productos').doc(pc.id);
    await ref.update({ nombre: pc.after.nombre });
    console.log(`Producto actualizado: ${pc.id}`);
  }

  // Aplicar cambios en gastos por lotes de 400
  const BATCH_SIZE = 400;
  let idx = 0;
  while (idx < gastosToUpdate.length) {
    const batch = firestore.batch();
    const chunk = gastosToUpdate.slice(idx, idx + BATCH_SIZE);
    for (const c of chunk) {
      const ref = firestore.collection('gastos').doc(c.id);
      const updateObj = {};
      if (c.after.items) updateObj.items = c.after.items;
      if (c.after.pagos) updateObj.pagos = c.after.pagos;
      batch.update(ref, updateObj);
    }
    await batch.commit();
    console.log(`Batch aplicado: ${idx}..${idx + chunk.length - 1}`);
    idx += chunk.length;
  }

  console.log('Migración finalizada.');
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
