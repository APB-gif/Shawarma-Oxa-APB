#!/usr/bin/env node
/**
 * update_gasto_items_by_product.js
 *
 * Actualiza el campo `nombre` dentro de `gastos.items` cuando un producto fue renombrado.
 * Dry-run por defecto; use --apply para escribir.
 *
 * Usage examples:
 *  node update_gasto_items_by_product.js --productId p-coca --newName "Coca Cola" --key C:\path\sa.json --days 30 --limit 500
 *  node update_gasto_items_by_product.js --oldName "Gastos Aharhel Per" --newName "Aharhel Gastos" --key C:\path\sa.json --apply
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function parseArgs() {
  const args = process.argv.slice(2);
  const out = { apply: false, limit: 500, days: 30, verbose: false };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--productId' && args[i+1]) out.productId = args[++i];
    else if (a === '--oldName' && args[i+1]) out.oldName = args[++i];
    else if (a === '--newName' && args[i+1]) out.newName = args[++i];
    else if (a === '--sync') out.sync = true;
    else if (a === '--key' && args[i+1]) out.key = args[++i];
    else if (a === '--apply') out.apply = true;
    else if (a === '--limit' && args[i+1]) out.limit = parseInt(args[++i], 10) || out.limit;
    else if (a === '--days' && args[i+1]) out.days = parseInt(args[++i], 10) || out.days;
    else if (a === '--verbose' || a === '-v') out.verbose = true;
    else if (a === '--help' || a === '-h') out.help = true;
  }
  return out;
}

function ensureOpts(opts) {
  // allow operation when either newName provided OR user asked to sync from product doc
  if (!opts.newName && !(opts.sync && opts.productId)) throw new Error('Debe especificar --newName o usar --sync con --productId');
  if (!opts.productId && !opts.oldName) throw new Error('Debe especificar --productId o --oldName');
}

async function main() {
  const opts = parseArgs();
  if (opts.help) { console.log('Usage: node update_gasto_items_by_product.js --newName "Nuevo" --productId p-id OR --oldName "Viejo" --key path --apply'); process.exit(0);} 
  try { ensureOpts(opts); } catch (e) { console.error(e.message); process.exit(1); }

  // init admin
  try {
    if (opts.key) {
      const kp = path.resolve(process.cwd(), opts.key);
      if (!fs.existsSync(kp)) throw new Error('Service account key not found: ' + kp);
      const cred = require(kp);
      admin.initializeApp({ credential: admin.credential.cert(cred) });
      if (opts.verbose) console.log('Initialized admin with', kp);
    } else {
      admin.initializeApp();
      if (opts.verbose) console.log('Initialized admin with default credentials');
    }
  } catch (e) { console.error('Error initializing firebase-admin:', e); process.exit(1); }

  const db = admin.firestore();
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - (opts.days || 30));
  const cutoffTs = admin.firestore.Timestamp.fromDate(cutoffDate);
  if (opts.verbose) console.log('Cutoff:', cutoffDate.toISOString());

  // If sync requested, fetch the authoritative product name from productos/<productId>
  if (opts.sync && opts.productId) {
    if (opts.verbose) console.log('Sync enabled: fetching product', opts.productId);
    try {
      const prodDoc = await db.collection('productos').doc(opts.productId).get();
      if (!prodDoc.exists) {
        console.error('Producto no encontrado en productos/' + opts.productId);
        process.exit(1);
      }
      const prodData = prodDoc.data() || {};
      const fetchedName = (prodData.nombre || '').toString();
      if (!fetchedName) {
        console.error('Producto encontrado pero sin campo nombre en productos/' + opts.productId);
        process.exit(1);
      }
      opts.newName = fetchedName;
      if (opts.verbose) console.log('Fetched product name:', opts.newName);
    } catch (e) {
      console.error('Error fetching product doc for sync:', e && e.stack ? e.stack : e);
      process.exit(1);
    }
  }

  const query = db.collection('gastos')
    .where('createdAt', '>=', cutoffTs)
    .orderBy('createdAt', 'desc')
    .limit(opts.limit);

  const snap = await query.get();
  console.log('Gastos leídos:', snap.size);

  const updates = [];
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const items = Array.isArray(data.items) ? data.items : [];
    let changed = false;
    const newItems = items.map(it => {
      try {
        const item = typeof it === 'object' ? Object.assign({}, it) : it;
        const itemNombre = (item.nombre || '').toString();
        const prod = item.producto || {};
        const prodNombre = (prod.nombre || '').toString();
        const prodId = (item.productoId || '').toString();
        // match by productId if provided, or by oldName
        if ((opts.productId && prodId === opts.productId) || (opts.oldName && (itemNombre === opts.oldName || prodNombre === opts.oldName))) {
          item.nombre = opts.newName;
          if (prod && typeof prod === 'object') prod.nombre = opts.newName;
          item.producto = prod;
          changed = true;
        }
        return item;
      } catch (e) {
        if (opts.verbose) console.warn('item parse error', doc.id, e);
        return it;
      }
    });
    if (changed) updates.push({ id: doc.id, ref: doc.ref, before: data, afterItems: newItems });
  }

  console.log('Gastos que requerirían update:', updates.length);
  const backup = { createdAt: new Date().toISOString(), opts, updates: updates.map(u => ({ id: u.id, before: u.before })) };
  const backupPath = path.resolve(process.cwd(), `backup_update_gastos_items_${new Date().toISOString().replace(/[:.]/g,'-')}.json`);
  fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2), 'utf8');
  console.log('Backup escrito en', backupPath);

  if (!opts.apply) {
    console.log('Dry-run: no se aplicaron cambios. Vuelve a ejecutar con --apply para escribir.');
    process.exit(0);
  }

  // apply in batches
  let batch = db.batch();
  let ops = 0;
  for (const u of updates) {
    batch.update(u.ref, { items: u.afterItems });
    ops++;
    if (ops >= 450) { await batch.commit(); batch = db.batch(); ops = 0; }
  }
  if (ops > 0) await batch.commit();

  console.log('Cambios aplicados:', updates.length);
  process.exit(0);
}

main().catch(e => { console.error('Error:', e && e.stack ? e.stack : e); process.exit(1); });
