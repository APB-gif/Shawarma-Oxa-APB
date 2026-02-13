#!/usr/bin/env node
/**
 * rename_category_product.js
 *
 * Renombra categorías y/o productos en Firestore y propaga los cambios
 * a documentos relacionados (productos, gastos). Dry-run por defecto.
 *
 * Usage:
 *  node rename_category_product.js --mapFile mappings.json --key "C:\path\to\sa.json" [--apply] [--limit 200]
 *
 * mappings.json example:
 * {
 *   "categorias": { "Aharhel": "Gasto Aharhel" },
 *   "productos": { "Aharhel": "Gastos Aharhel" }
 * }
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function parseArgs() {
  const args = process.argv.slice(2);
  const out = { apply: false, limit: 500, days: 30, verbose: false };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--mapFile' && args[i+1]) { out.mapFile = args[++i]; }
    else if (a === '--map' && args[i+1]) { out.map = args[++i]; }
    else if (a === '--key' && args[i+1]) { out.key = args[++i]; }
    else if (a === '--apply') { out.apply = true; }
    else if (a === '--limit' && args[i+1]) { out.limit = parseInt(args[++i], 10) || out.limit; }
    else if (a === '--days' && args[i+1]) { out.days = parseInt(args[++i], 10) || out.days; }
    else if (a === '--verbose' || a === '-v') { out.verbose = true; }
    else if (a === '--help' || a === '-h') { out.help = true; }
  }
  return out;
}

function loadMappings(opts) {
  if (opts.mapFile) {
    const p = path.resolve(process.cwd(), opts.mapFile);
    if (!fs.existsSync(p)) throw new Error('Mappings file not found: ' + p);
    return JSON.parse(fs.readFileSync(p, 'utf8'));
  }
  if (opts.map) {
    return JSON.parse(opts.map);
  }
  throw new Error('No mappings provided. Use --mapFile or --map.');
}

async function main() {
  const opts = parseArgs();
  if (opts.help || (!opts.map && !opts.mapFile)) {
    console.log('Usage: node rename_category_product.js --mapFile mappings.json --key <serviceAccount.json> [--apply] [--limit N]');
    process.exit(0);
  }

  const mappings = loadMappings(opts);
  if (opts.verbose) {
    console.log('Opts:', JSON.stringify(opts));
    console.log('Mappings loaded:', JSON.stringify(mappings, null, 2));
  }

  // Init admin (use cert when key provided to get clearer errors)
  try {
    if (opts.key) {
      const kp = path.resolve(process.cwd(), opts.key);
      if (!fs.existsSync(kp)) throw new Error('Service account key not found: ' + kp);
      const cred = require(kp);
      admin.initializeApp({ credential: admin.credential.cert(cred) });
      if (opts.verbose) console.log('Initialized admin with cert', kp);
    } else {
      admin.initializeApp();
      if (opts.verbose) console.log('Initialized admin with default credentials');
    }
  } catch (e) {
    console.error('Error inicializando firebase-admin:', e && e.stack ? e.stack : e);
    process.exit(1);
  }

  const db = admin.firestore();
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backup = { categories: [], products: [], gastos: [], mappings, createdAt: new Date().toISOString() };

  // Helpers
  function caseEq(a, b) { return (a||'').toString().toLowerCase() === (b||'').toString().toLowerCase(); }

  try {
  // Process categories mappings
  if (mappings.categorias) {
    for (const [oldName, newName] of Object.entries(mappings.categorias)) {
      console.log(`\nProcesando categoría: '${oldName}' => '${newName}'`);
      // Buscar docs en 'categorias' por id == oldName o nombre == oldName
      const found = [];
      const catById = await db.collection('categorias').doc(oldName).get();
      if (catById.exists) found.push({ id: catById.id, data: catById.data() });

      const snapByName = await db.collection('categorias').where('nombre', '==', oldName).get();
      snapByName.forEach(d => { if (!found.find(f=>f.id===d.id)) found.push({ id: d.id, data: d.data() }); });

      console.log('  Categorías encontradas:', found.length);
      for (const c of found) {
        backup.categories.push({ id: c.id, data: c.data });
      }

      // Productos que referencian esta categoriaId
      const prodSnap = await db.collection('productos').where('categoriaId', '==', oldName).limit(opts.limit).get();
      const prodsByNombreSnap = await db.collection('productos').where('categoriaNombre', '==', oldName).limit(opts.limit).get();

      const productos = [];
      prodSnap.forEach(d => productos.push({ id: d.id, data: d.data() }));
      prodsByNombreSnap.forEach(d => { if (!productos.find(p=>p.id===d.id)) productos.push({ id: d.id, data: d.data() }); });

      console.log(`  Productos a actualizar (categoriaId/categoriaNombre): ${productos.length}`);
      for (const p of productos) backup.products.push({ id: p.id, data: p.data });

      // Gastos: buscar documentos recientes (últimos N días) que tengan items con categoriaNombre == oldName or categoriaId == oldName
      const gastosToUpdate = [];
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - (opts.days || 30));
      const cutoffTs = admin.firestore.Timestamp.fromDate(cutoffDate);
      if (opts.verbose) console.log('    usando cutoff (createdAt) >=', cutoffDate.toISOString());
      const gastosQuery = db.collection('gastos')
        .where('createdAt', '>=', cutoffTs)
        .orderBy('createdAt', 'desc')
        .limit(opts.limit);
      let gastosSnap;
      try {
        gastosSnap = await gastosQuery.get();
        if (opts.verbose) console.log('    gastos leídos por consulta:', gastosSnap.size);
      } catch (e) {
        console.error('Error ejecutando consulta de gastos (categorias):', e && e.stack ? e.stack : e);
        throw e;
      }

      gastosSnap.forEach(d => {
        const data = d.data() || {};
        const items = data.items || [];
        let changed = false;
        const newItems = items.map(it => {
          try {
            const copy = Object.assign({}, it);
            if (caseEq(copy.categoriaNombre, oldName) || caseEq(copy.categoriaId, oldName)) {
              copy.categoriaNombre = newName;
              changed = true;
            }
            return copy;
          } catch (e) {
            if (opts.verbose) console.warn('    item parse warning in gasto', d.id, e && e.stack ? e.stack : e);
            return it;
          }
        });
        if (changed) gastosToUpdate.push({ id: d.id, before: data, afterItems: newItems });
      });

      console.log('  Gastos afectados (muestra limitada por --limit):', gastosToUpdate.length);
      for (const g of gastosToUpdate) backup.gastos.push({ id: g.id, before: g.before });

      // Summarize planned writes
      if (!opts.apply) {
        console.log('  Dry-run: se mostrarán los cambios planeados (no aplicados).');
        if (found.length) console.log(`    - Actualizar nombre de ${found.length} categorias -> '${newName}'`);
        if (productos.length) console.log(`    - Actualizar ${productos.length} productos.categoriaNombre -> '${newName}'`);
        if (gastosToUpdate.length) console.log(`    - Actualizar items en ${gastosToUpdate.length} gastos (categoriaNombre -> '${newName}')`);
        continue;
      }

      // Apply changes in batches
      const batch = db.batch();
      let ops = 0;
      for (const c of found) {
        const cref = db.collection('categorias').doc(c.id);
        batch.set(cref, { nombre: newName }, { merge: true });
        ops++;
        if (ops >= 450) { await batch.commit(); ops = 0; }
      }

      for (const p of productos) {
        const pref = db.collection('productos').doc(p.id);
        batch.set(pref, { categoriaNombre: newName }, { merge: true });
        ops++;
        if (ops >= 450) { await batch.commit(); ops = 0; }
      }

      for (const g of gastosToUpdate) {
        const gref = db.collection('gastos').doc(g.id);
        batch.update(gref, { items: g.afterItems });
        ops++;
        if (ops >= 450) { await batch.commit(); ops = 0; }
      }

      if (ops > 0) await batch.commit();
      console.log('  Cambios aplicados para categoría', oldName);
    }
  }

  // Process products mappings
  if (mappings.productos) {
    for (const [oldName, newName] of Object.entries(mappings.productos)) {
      console.log(`\nProcesando producto: '${oldName}' => '${newName}'`);
      const found = [];
      const prodById = await db.collection('productos').doc(oldName).get();
      if (prodById.exists) found.push({ id: prodById.id, data: prodById.data() });
      const snapByName = await db.collection('productos').where('nombre', '==', oldName).limit(opts.limit).get();
      snapByName.forEach(d => { if (!found.find(f=>f.id===d.id)) found.push({ id: d.id, data: d.data() }); });

      console.log('  Productos encontrados:', found.length);
      for (const p of found) backup.products.push({ id: p.id, data: p.data });

      // Gastos: items.producto.nombre == oldName or items.producto.id == productId
      const gastosToUpdate = [];
      // ensure cutoffTs exists for product loop as well
      const pCutoffDate = new Date();
      pCutoffDate.setDate(pCutoffDate.getDate() - (opts.days || 30));
      const pCutoffTs = admin.firestore.Timestamp.fromDate(pCutoffDate);
      if (opts.verbose) console.log('    usando cutoff (createdAt) >=', pCutoffDate.toISOString());
      const gastosQuery2 = db.collection('gastos')
        .where('createdAt', '>=', pCutoffTs)
        .orderBy('createdAt', 'desc')
        .limit(opts.limit);
      let gastosSnap2;
      try {
        gastosSnap2 = await gastosQuery2.get();
        if (opts.verbose) console.log('    gastos leídos por consulta (productos):', gastosSnap2.size);
      } catch (e) {
        console.error('Error ejecutando consulta de gastos (productos):', e && e.stack ? e.stack : e);
        throw e;
      }

      gastosSnap2.forEach(d => {
        const data = d.data() || {};
        const items = data.items || [];
        let changed = false;
        const newItems = items.map(it => {
          try {
            const copy = JSON.parse(JSON.stringify(it));
            if (caseEq((copy.producto && copy.producto.nombre), oldName) || caseEq(copy.productoId, oldName) ) {
              if (!copy.producto) copy.producto = {};
              copy.producto.nombre = newName;
              changed = true;
            }
            return copy;
          } catch (e) {
            if (opts.verbose) console.warn('    item parse warning in gasto', d.id, e && e.stack ? e.stack : e);
            return it;
          }
        });
        if (changed) gastosToUpdate.push({ id: d.id, before: data, afterItems: newItems });
      });

      console.log('  Gastos afectados (muestra limitada por --limit):', gastosToUpdate.length);
      for (const g of gastosToUpdate) backup.gastos.push({ id: g.id, data: g.before });

      if (!opts.apply) {
        console.log('  Dry-run: no se aplicaron cambios. Mostrar resumen arriba.');
        continue;
      }

      // Apply product name updates
      const batch = db.batch();
      let ops = 0;
      for (const p of found) {
        const pref = db.collection('productos').doc(p.id);
        batch.set(pref, { nombre: newName }, { merge: true });
        ops++;
        if (ops >= 450) { await batch.commit(); ops = 0; }
      }
      for (const g of gastosToUpdate) {
        const gref = db.collection('gastos').doc(g.id);
        batch.update(gref, { items: g.afterItems });
        ops++;
        if (ops >= 450) { await batch.commit(); ops = 0; }
      }
      if (ops > 0) await batch.commit();
      console.log('  Cambios aplicados para producto', oldName);
    }
  }

  // Write backup file
  const backupPath = path.resolve(process.cwd(), `backup_rename_${timestamp}.json`);
  fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2), 'utf8');
  console.log('\nBackup escrito en:', backupPath);

  console.log('\nTerminado. Revisa los cambios en la consola de Firebase o con la app.');
  process.exit(0);
  } catch (e) {
    console.error('Runtime error:', e && e.stack ? e.stack : e);
    // attempt to write partial backup if available
    try {
      const backupPathErr = path.resolve(process.cwd(), `backup_rename_error_${timestamp}.json`);
      fs.writeFileSync(backupPathErr, JSON.stringify(backup, null, 2), 'utf8');
      console.error('Backup parcial escrito en:', backupPathErr);
    } catch (ee) {
      console.error('No se pudo escribir backup parcial:', ee && ee.stack ? ee.stack : ee);
    }
    process.exit(1);
  }
}

main().catch(e => { console.error('Error:', e && e.stack ? e.stack : e); process.exit(1); });
