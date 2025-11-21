#!/usr/bin/env node
/**
 * fix_tipo_category_gastos.js
 *
 * Inspecciona una categoría por id y lista los productos que la usan.
 * Dry-run por defecto: muestra la 'tipo' actual de la categoría y de cada producto.
 * --apply: actualiza la categoría (`tipo='gasto'`) y todos los productos con esa
 * categoriaId para tener `tipo='gasto'` también. Hace backup local antes de escribir.
 *
 * Uso:
 *  node fix_tipo_category_gastos.js --cat Aharhel --key "C:\keys\shawarma...json" [--apply]
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function parseArgs() {
  const args = process.argv.slice(2);
  const out = { apply: false };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--cat' && args[i+1]) { out.cat = args[++i]; }
    else if (a === '--key' && args[i+1]) { out.key = args[++i]; }
    else if (a === '--apply') { out.apply = true; }
    else if (a === '--help' || a === '-h') { out.help = true; }
  }
  return out;
}

async function main() {
  const opts = parseArgs();
  if (opts.help || !opts.cat) {
    console.log('Usage: node fix_tipo_category_gastos.js --cat <categoryId> --key <serviceAccount.json> [--apply]');
    process.exit(0);
  }

  // Init admin
  if (opts.key) {
    process.env.GOOGLE_APPLICATION_CREDENTIALS = opts.key;
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  } else {
    // Try default
    try { admin.initializeApp(); } catch (e) {}
  }

  const db = admin.firestore();
  const catRef = db.collection('categorias').doc(opts.cat);
  const catSnap = await catRef.get();

  if (!catSnap.exists) {
    console.error('Categoría no encontrada:', opts.cat);
    process.exit(1);
  }

  const catData = catSnap.data() || {};
  console.log('\nCategoría:', opts.cat);
  console.log('  nombre:', (catData.nombre || '').toString());
  console.log('  tipo (actual):', (catData.tipo || '').toString() || '<vacío>');

  // Buscar productos con categoriaId == opts.cat
  const productosSnap = await db.collection('productos').where('categoriaId', '==', opts.cat).get();
  console.log(`\nProductos encontrados con categoriaId='${opts.cat}': ${productosSnap.size}`);

  const productos = [];
  productosSnap.forEach(d => {
    productos.push({ id: d.id, data: d.data() || {} });
  });

  const mismatched = productos.filter(p => ((p.data.tipo || '').toString().toLowerCase() !== 'gasto'));

  console.log('\nResumen:');
  console.log('  Total productos:', productos.length);
  console.log('  Productos con tipo distinto a "gasto":', mismatched.length);

  if (productos.length > 0) {
    console.log('\nListado (id -> tipo):');
    productos.forEach(p => {
      console.log(`  - ${p.id} -> '${(p.data.tipo || '').toString() || '<vacío>'}'`);
    });
  }

  if (!opts.apply) {
    console.log('\nModo dry-run. Ningún cambio fue aplicado. Ejecuta con --apply para aplicar.');
    process.exit(0);
  }

  // Confirmar
  console.log('\n--apply indicado. Se hará backup local y se aplicarán cambios.');
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupPath = path.resolve(process.cwd(), `backup_fix_tipo_${opts.cat}_${timestamp}.json`);

  const backup = {
    category: { id: catSnap.id, data: catData },
    products: productos,
    updatedAt: new Date().toISOString(),
  };

  fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2), 'utf8');
  console.log('Backup escrito en:', backupPath);

  // Aplicar cambios: set categoria.tipo='gasto' (merge) y producto.tipo='gasto' (merge)
  const batch = db.batch();
  batch.set(catRef, { tipo: 'gasto' }, { merge: true });
  for (const p of productos) {
    const pref = db.collection('productos').doc(p.id);
    batch.set(pref, { tipo: 'gasto' }, { merge: true });
  }

  await batch.commit();
  console.log('Cambios aplicados: categoría y', productos.length, 'productos actualizados a tipo="gasto"');
  console.log('Terminado. Por seguridad, revisa en la consola de Firebase o con la app.');
  process.exit(0);
}

main().catch(e => {
  console.error('Error:', e);
  process.exit(1);
});
