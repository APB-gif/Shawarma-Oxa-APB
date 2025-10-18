/*
Script de migración para Firestore: renombra claves de pagos en documentos de la colección 'gastos'.

Comportamiento:
 - Dry-run por defecto: lista cantidad de documentos afectados y muestra ejemplos.
 - --apply para ejecutar los cambios.
 - --limit <n> para limitar documentos procesados (útil para pruebas).
 - Requiere GOOGLE_APPLICATION_CREDENTIALS apuntando a JSON de service account o --key <path>.

Uso (PowerShell):
 $env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\path\to\service-account.json'; node migrate_gastos_payment_keys.js --dry-run
 node migrate_gastos_payment_keys.js --apply --limit 100

Nota: Haz backup de tus datos antes de ejecutar --apply.
*/

const { Firestore } = require('@google-cloud/firestore');
const argv = require('minimist')(process.argv.slice(2));

async function main() {
  const apply = !!argv.apply;
  const limit = argv.limit ? parseInt(argv.limit, 10) : null;
  const keyPath = argv.key || null;

  if (keyPath) process.env.GOOGLE_APPLICATION_CREDENTIALS = keyPath;

  const firestore = new Firestore();
  console.log('Conectando a Firestore...');

  let q = firestore.collection('gastos').orderBy('createdAt', 'desc');
  if (limit) q = q.limit(limit);

  const snap = await q.get();
  console.log(`Documentos leídos: ${snap.size}`);

  let toChange = [];

  snap.forEach(doc => {
    const data = doc.data();
    if (!data) return;
    const pagos = data.pagos || data['payments'] || null;
    if (pagos && typeof pagos === 'object') {
      const keys = Object.keys(pagos);
      let needs = false;
      const newPagos = {};
      for (const k of keys) {
        const lower = (k || '').toString().toLowerCase().trim();
        let newKey = k;
        if (lower === 'tarjeta') newKey = 'Ruben';
        else if (lower === 'yape personal' || lower === 'yape') newKey = 'Aharhel';
        if (newPagos[newKey]) {
          newPagos[newKey] += pagos[k];
        } else {
          newPagos[newKey] = pagos[k];
        }
        if (newKey !== k) needs = true;
      }
      if (needs) {
        toChange.push({ id: doc.id, old: pagos, nuevo: newPagos });
      }
    }
  });

  console.log(`Documentos a actualizar: ${toChange.length}`);
  if (toChange.length > 0) {
    console.log('Ejemplos:');
    toChange.slice(0, 5).forEach(x => {
      console.log(`- id=${x.id}`);
      console.log('  before:', x.old);
      console.log('  after: ', x.nuevo);
    });
  }

  if (!apply) {
    console.log('\nModo dry-run. Para aplicar los cambios ejecuta con --apply');
    return;
  }

  // Aplicar cambios en lotes de 400 (Firestore limit)
  const BATCH_SIZE = 400;
  let idx = 0;
  while (idx < toChange.length) {
    const batch = firestore.batch();
    const chunk = toChange.slice(idx, idx + BATCH_SIZE);
    for (const c of chunk) {
      const ref = firestore.collection('gastos').doc(c.id);
      batch.update(ref, { pagos: c.nuevo });
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
