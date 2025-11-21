/*
Restore script for backup_aharhel_docs.json

Usage (PowerShell):
  # Dry-run (preview):
  node restore_aharhel_from_backup.js --backup 'backup_aharhel_docs.json' --key 'C:\keys\...json'

  # Apply restore (will write to Firestore):
  node restore_aharhel_from_backup.js --apply --backup 'backup_aharhel_docs.json' --key 'C:\keys\...json'

This script will:
 - Read the backup JSON created earlier (productos + gastos)
 - In dry-run mode (default) it prints what would be restored
 - In --apply mode it writes back productos and gastos items using set/merge or update

Precaución: Antes de ejecutar --apply, crea un backup actual (por seguridad). The script will also create a current-backup file automatically before applying.
*/

const admin = require('firebase-admin');
const argv = require('minimist')(process.argv.slice(2));
const fs = require('fs');
const path = require('path');

const keyPath = argv.key || null;
const backupPath = argv.backup || 'backup_aharhel_docs.json';
const apply = !!argv.apply;

if (!fs.existsSync(backupPath)) {
  console.error('Backup file not found:', backupPath);
  process.exit(1);
}

if (keyPath) process.env.GOOGLE_APPLICATION_CREDENTIALS = keyPath;

if (!admin.apps.length) {
  try {
    if (keyPath) {
      const cred = require(path.resolve(keyPath));
      admin.initializeApp({ credential: admin.credential.cert(cred) });
    } else {
      admin.initializeApp();
    }
  } catch (e) {
    try {
      admin.initializeApp();
    } catch (e2) {
      console.error('Failed to initialize firebase-admin:', e, e2);
      process.exit(1);
    }
  }
}

const firestore = admin.firestore();

async function main() {
  const raw = fs.readFileSync(backupPath, 'utf8');
  const backup = JSON.parse(raw);

  const productos = backup.productos || {};
  const gastos = backup.gastos || {};

  console.log('Backup loaded:', Object.keys(productos).length, 'productos,', Object.keys(gastos).length, 'gastos');

  if (!apply) {
    console.log('\n--- DRY-RUN: Preview of actions ---');
    if (Object.keys(productos).length > 0) {
      console.log('Productos to restore:');
      Object.keys(productos).forEach(id => {
        const p = productos[id];
        console.log(` - producto id=${id} nombre='${p.nombre}' categoriaId='${p.categoriaId || ''}'`);
      });
    }

    if (Object.keys(gastos).length > 0) {
      console.log('\nGastos to restore items for:');
      Object.keys(gastos).forEach(id => {
        const g = gastos[id];
        const items = g.items || [];
        console.log(` - gasto id=${id} items_in_backup=${items.length}`);
      });
    }
    console.log('\nRun with --apply to perform the restore.');
    return;
  }

  // BEFORE applying, write a snapshot of current docs to a file
  const ts = new Date().toISOString().replace(/[:.]/g, '-');
  const currentBackupFile = `current_before_restore_${ts}.json`;
  const currentSnapshot = { productos: {}, gastos: {} };

  console.log('Creating current snapshot before applying...');
  // snapshot productos
  for (const id of Object.keys(productos)) {
    try {
      const doc = await firestore.collection('productos').doc(id).get();
      currentSnapshot.productos[id] = doc.exists ? doc.data() : null;
    } catch (e) {
      currentSnapshot.productos[id] = { error: String(e) };
    }
  }

  // snapshot gastos
  for (const id of Object.keys(gastos)) {
    try {
      const doc = await firestore.collection('gastos').doc(id).get();
      currentSnapshot.gastos[id] = doc.exists ? doc.data() : null;
    } catch (e) {
      currentSnapshot.gastos[id] = { error: String(e) };
    }
  }

  fs.writeFileSync(currentBackupFile, JSON.stringify(currentSnapshot, null, 2), 'utf8');
  console.log('Current snapshot written to', currentBackupFile);

  // Apply productos restore (set with merge)
  for (const id of Object.keys(productos)) {
    const pdata = productos[id];
    const updateObj = {};
    if (pdata.nombre != null) updateObj.nombre = pdata.nombre;
    if (pdata.categoriaId != null) updateObj.categoriaId = pdata.categoriaId;
    try {
      await firestore.collection('productos').doc(id).set(updateObj, { merge: true });
      console.log(`Producto restaurado/actualizado: ${id}`);
    } catch (e) {
      console.error('Failed to restore producto', id, e);
    }
  }

  // Apply gastos restore: restore items only (merge)
  for (const id of Object.keys(gastos)) {
    const gdata = gastos[id];
    const items = gdata.items || null;
    if (!items) continue;
    try {
      await firestore.collection('gastos').doc(id).update({ items });
      console.log(`Gasto items restaurados: ${id} (items=${items.length})`);
    } catch (e) {
      // If update fails because doc missing, set full doc
      try {
        await firestore.collection('gastos').doc(id).set({ items }, { merge: true });
        console.log(`Gasto creado/merge restaurado: ${id}`);
      } catch (e2) {
        console.error('Failed to restore gasto', id, e2);
      }
    }
  }

  console.log('Restore completed. Review the current snapshot file and check Firestore.');
}

main().catch(err => { console.error('Error:', err); process.exit(1); });
