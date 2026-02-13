/*
Script para renombrar la categoría 'Aharhel' -> 'Gasto Aharhel' en:
 - items[].categoriaId dentro de documentos 'gastos'
 - documentos en 'productos' que tengan campo 'categoriaId' == 'Aharhel' o 'nombre' == 'Aharhel'

Comportamiento:
 - Dry-run por defecto: muestra conteos y ejemplos.
 - --apply para ejecutar cambios.
 - --limit <n> limita cuantos documentos 'gastos' se leen.
 - --key <path> o usar GOOGLE_APPLICATION_CREDENTIALS para credenciales.

Uso (PowerShell):
  node migrate_categoria_aharhel.js --limit 100
  node migrate_categoria_aharhel.js --apply --limit 100 --key 'C:\keys\...json'

Precaución: Haz backup antes de --apply (ya tienes backup_aharhel_docs.json creado).
*/

const admin = require('firebase-admin');
const argv = require('minimist')(process.argv.slice(2));

async function main() {
  const apply = !!argv.apply;
  const limit = argv.limit ? parseInt(argv.limit, 10) : 500;
  const keyPath = argv.key || null;

  if (keyPath) process.env.GOOGLE_APPLICATION_CREDENTIALS = keyPath;

  if (!admin.apps.length) {
    try {
      if (keyPath) {
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

  // 1) Productos: buscar docs con categoriaId == 'Aharhel' o nombre == 'Aharhel'
  const productosSnap = await firestore.collection('productos').get();
  const prodChanges = [];
  productosSnap.forEach(doc => {
    const data = doc.data() || {};
    const changed = {};
    if ((data.categoriaId || '').toString().toLowerCase().trim() === 'aharhel') {
      changed.categoriaId = 'Gasto Aharhel';
    }
    if ((data.nombre || '').toString().toLowerCase().trim() === 'aharhel') {
      // si nombre aún es 'Aharhel', opcionalmente lo dejamos o lo actualizamos
      changed.nombre = 'Gasto Aharhel';
    }
    if (Object.keys(changed).length > 0) {
      prodChanges.push({ id: doc.id, before: data, after: { ...data, ...changed } });
    }
  });

  // 2) Gastos: scan limitado por --limit y buscar items con categoriaId == 'Aharhel'
  let gastosQuery = firestore.collection('gastos').orderBy('createdAt', 'desc');
  if (limit) gastosQuery = gastosQuery.limit(limit);
  const gastosSnap = await gastosQuery.get();
  const gastosToUpdate = [];
  gastosSnap.forEach(doc => {
    const data = doc.data() || {};
    const items = Array.isArray(data.items) ? data.items.map(it => ({ ...it })) : [];
    let updated = false;
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      if (!it) continue;
      const cat = (it.categoriaId || '').toString().toLowerCase().trim();
      if (cat === 'aharhel') {
        items[i].categoriaId = 'Gasto Aharhel';
        updated = true;
      }
    }
    if (updated) gastosToUpdate.push({ id: doc.id, before: data, after: { ...data, items } });
  });

  console.log(`Productos a actualizar: ${prodChanges.length}`);
  if (prodChanges.length > 0) prodChanges.slice(0,5).forEach(x => console.log(`- producto id=${x.id} before categoria='${x.before.categoriaId}' after categoria='${x.after.categoriaId}' nombre before='${x.before.nombre}' after='${x.after.nombre}'`));

  console.log(`Gastos a actualizar: ${gastosToUpdate.length}`);
  if (gastosToUpdate.length > 0) gastosToUpdate.slice(0,5).forEach(x => console.log(`- id=${x.id} itemsBefore=${(x.before.items||[]).length} itemsAfter=${(x.after.items||[]).length}`));

  if (!apply) {
    console.log('\nModo dry-run. Para aplicar los cambios ejecuta con --apply');
    return;
  }

  // Aplicar cambios en productos
  for (const pc of prodChanges) {
    const ref = firestore.collection('productos').doc(pc.id);
    const updateObj = {};
    if (pc.after.categoriaId && pc.after.categoriaId !== pc.before.categoriaId) updateObj['categoriaId'] = pc.after.categoriaId;
    if (pc.after.nombre && pc.after.nombre !== pc.before.nombre) updateObj['nombre'] = pc.after.nombre;
    if (Object.keys(updateObj).length > 0) {
      await ref.update(updateObj);
      console.log(`Producto actualizado: ${pc.id}`);
    }
  }

  // Aplicar cambios en gastos por lotes
  const BATCH_SIZE = 400;
  let idx = 0;
  while (idx < gastosToUpdate.length) {
    const batch = firestore.batch();
    const chunk = gastosToUpdate.slice(idx, idx + BATCH_SIZE);
    for (const c of chunk) {
      const ref = firestore.collection('gastos').doc(c.id);
      batch.update(ref, { items: c.after.items });
    }
    await batch.commit();
    console.log(`Batch aplicado: ${idx}..${idx + chunk.length - 1}`);
    idx += chunk.length;
  }

  console.log('Migración de categoría finalizada.');
}

main().catch(err => { console.error('Error:', err); process.exit(1); });
