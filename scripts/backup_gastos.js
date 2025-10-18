/*
Backup de la colección 'gastos' a una nueva colección 'gastos_backup_YYYYMMDD_HHMMSS'.
Uso: node backup_gastos.js
Requiere: GOOGLE_APPLICATION_CREDENTIALS apuntando al service account JSON
*/

const { Firestore } = require('@google-cloud/firestore');

async function main() {
  const firestore = new Firestore();
  const now = new Date();
  const pad = n => n.toString().padStart(2, '0');
  const ts = `${now.getFullYear()}${pad(now.getMonth()+1)}${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
  const backupCollection = `gastos_backup_${ts}`;
  console.log(`Backup target collection: ${backupCollection}`);

  const snap = await firestore.collection('gastos').get();
  console.log(`Documentos encontrados en 'gastos': ${snap.size}`);

  if (snap.empty) {
    console.log('No hay documentos para respaldar.');
    return;
  }

  const BATCH_SIZE = 400;
  let batch = firestore.batch();
  let count = 0;
  let idx = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const ref = firestore.collection(backupCollection).doc(doc.id);
    const copy = {
      ...data,
      _backupFrom: 'gastos',
      _backupAt: new Date().toISOString(),
    };
    batch.set(ref, copy);
    idx++;
    if (idx % BATCH_SIZE === 0) {
      await batch.commit();
      count += BATCH_SIZE;
      console.log(`Committed ${count} documents...`);
      batch = firestore.batch();
    }
  }
  // commit remaining
  await batch.commit();
  count = idx;
  console.log(`Backup completado. Documentos copiados: ${count}`);
  console.log(`Colección de backup: ${backupCollection}`);
}

main().catch(err => {
  console.error('Error durante backup:', err);
  process.exit(1);
});
