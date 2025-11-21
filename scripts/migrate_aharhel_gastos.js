/*
Script de migración para Firestore:

Objetivos:
 - Renombrar el método de pago histórico "Aharhel" a "Aharhel YS" por defecto.
 - Para gastos que contienen items con nombre 'Aharhel', cambiar esos items.nombre a 'Gastos Aharhel' y mover/renombrar el pago asociado a 'Aharhel Gastos'.
 - Actualizar documento de producto con id 'Aharhel' (si existe) a nombre 'Gastos Aharhel'.

Comportamiento:
 - Dry-run por defecto: muestra cuántos documentos se verían afectados y ejemplos.
 - --apply para ejecutar los cambios.
 - --limit <n> limita cuántos documentos 'gastos' se leen.
 - --key <path> para indicar credenciales (o usar GOOGLE_APPLICATION_CREDENTIALS).

Uso (PowerShell):
  node migrate_aharhel_gastos.js --limit 500
  node migrate_aharhel_gastos.js --apply --limit 1000 --key 'C:\keys\service-account.json'

Precaución: Haz backup antes de usar --apply.
*/

const { Firestore } = require('@google-cloud/firestore');
const argv = require('minimist')(process.argv.slice(2));
const fs = require('fs');
const path = require('path');

async function main() {
  const apply = !!argv.apply;
  const limit = argv.limit ? parseInt(argv.limit, 10) : 1000;
  const keyPath = argv.key || null;

  if (keyPath) process.env.GOOGLE_APPLICATION_CREDENTIALS = keyPath;

  const firestore = new Firestore();
  console.log('Conectando a Firestore...');

  // 1) Revisar producto con id 'Aharhel' y proponer renombrarlo
  const prodRef = firestore.collection('productos').doc('Aharhel');
  const prodSnap = await prodRef.get();
  const prodChange = prodSnap.exists && ((prodSnap.data().nombre || '').toString().toLowerCase().trim() === 'aharhel')
    ? { id: prodSnap.id, before: prodSnap.data(), after: { ...prodSnap.data(), nombre: 'Gastos Aharhel' } }
    : null;

  // 2) Scan de documentos 'gastos'
  let q = firestore.collection('gastos').orderBy('createdAt', 'desc');
  if (limit) q = q.limit(limit);
  const snap = await q.get();
  console.log(`Documentos 'gastos' leídos: ${snap.size}`);

  const toUpdate = [];

  snap.forEach(doc => {
    const data = doc.data() || {};
    const items = Array.isArray(data.items) ? data.items.map(it => ({ ...it })) : [];
    const pagos = data.pagos || data.payments || null;

    let itemsChanged = false;
    let hasItemAharhel = false;
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      if (!it || !it.nombre) continue;
      if ((it.nombre || '').toString().toLowerCase().trim() === 'aharhel') {
        items[i].nombre = 'Gastos Aharhel';
        itemsChanged = true;
        hasItemAharhel = true;
      }
    }

    let pagosChanged = false;
    let newPagos = null;
    if (pagos && typeof pagos === 'object') {
      newPagos = {};
      for (const k of Object.keys(pagos)) {
        const lower = (k || '').toString().toLowerCase().trim();
        let newKey = k;
        if (lower === 'gasto aharhel' || lower === 'gasto_aharhel') {
          newKey = 'Aharhel Gastos';
        } else if (lower === 'aharhel') {
          // Si el gasto contiene un item 'Aharhel' se asume que debe ser 'Aharhel Gastos',
          // en otro caso renombramos a 'Aharhel YS' (cambio global solicitado).
          newKey = hasItemAharhel ? 'Aharhel Gastos' : 'Aharhel YS';
        }

        if (newPagos[newKey]) newPagos[newKey] += pagos[k]; else newPagos[newKey] = pagos[k];
        if (newKey !== k) pagosChanged = true;
      }
    }

    if (itemsChanged || pagosChanged) {
      const after = { ...data };
      if (itemsChanged) after.items = items;
      if (pagosChanged) after.pagos = newPagos;
      toUpdate.push({ id: doc.id, before: data, after });
    }
  });

  console.log(`Gastos a actualizar: ${toUpdate.length}`);
  if (toUpdate.length > 0) {
    console.log('Ejemplos:');
    toUpdate.slice(0, 5).forEach(x => {
      console.log(`- id=${x.id}`);
      if (x.before.items) console.log('  itemsBefore:', (x.before.items||[]).map(i=>i.nombre).slice(0,5));
      if (x.after.items) console.log('  itemsAfter :', (x.after.items||[]).map(i=>i.nombre).slice(0,5));
      if (x.before.pagos) console.log('  pagosBefore:', Object.keys(x.before.pagos));
      if (x.after.pagos) console.log('  pagosAfter :', Object.keys(x.after.pagos));
    });
  }

  if (prodChange) {
    console.log('\nProducto con id "Aharhel" detectado. Propuesta de cambio:');
    console.log('  before nombre =', prodChange.before.nombre);
    console.log('  after  nombre =', prodChange.after.nombre);
  }

  if (!apply) {
    console.log('\nDry-run completo. Para aplicar los cambios ejecuta con --apply');
    return;
  }

  // Backup local antes de aplicar
  const ts = new Date().toISOString().replace(/[:.]/g, '-');
  const backupPath = path.resolve(process.cwd(), `backup_migrate_aharhel_gastos_${ts}.json`);
  const backupData = { productChange: prodChange, gastos: toUpdate, createdAt: new Date().toISOString() };
  fs.writeFileSync(backupPath, JSON.stringify(backupData, null, 2), 'utf8');
  console.log('Backup escrito en:', backupPath);

  // Aplicar cambios: producto y gastos (por lotes)
  if (prodChange) {
    await prodRef.update({ nombre: prodChange.after.nombre });
    console.log('Producto actualizado: productos/Aharhel -> nombre="Gastos Aharhel"');
  }

  const BATCH_SIZE = 400;
  let idx = 0;
  while (idx < toUpdate.length) {
    const batch = firestore.batch();
    const chunk = toUpdate.slice(idx, idx + BATCH_SIZE);
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

  console.log('Migración completada. Revisa la consola de Firebase o exporta resultados para verificar.');
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
