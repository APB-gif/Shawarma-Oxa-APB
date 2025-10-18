/*
  Script para normalizar insumos[].cantidad a 2 decimales en Firestore.

  Requisitos:
  - Tener Node.js instalado.
  - Crear una cuenta de servicio en Firebase Console (Project Settings -> Service Accounts -> Generate new private key) y guardar el JSON localmente.
  - En PowerShell, exportar la variable de entorno:
      $env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\ruta\a\serviceAccountKey.json'
  - Ejecutar:
      node scripts\fix_insumos_firestore.js

  Qué hace:
  - Lee todos los documentos de la colección `recetas`.
  - Para cada documento con campo `insumos` (array), redondea cada `insumo.cantidad` a 2 decimales.
  - Si algún insumo cambió, actualiza el documento con el array normalizado.

  Nota: Haz un respaldo (export) de la colección `recetas` antes de correr el script en producción.
*/

const admin = require('firebase-admin');

async function main() {
  try {
    const args = process.argv.slice(2);
    const dryRun = args.includes('--dry-run');
    const truncate = args.includes('--truncate');

    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
    const db = admin.firestore();
    const col = db.collection('recetas');

    console.log('Obteniendo documentos de `recetas`...');
    const snapshot = await col.get();
    console.log(`Encontrados ${snapshot.size} documentos.`);

  let updatedDocs = 0;
  const changedPreview = [];

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const insumos = data.insumos;
      if (!Array.isArray(insumos) || insumos.length === 0) continue;

      let changed = false;
      const newInsumos = insumos.map((ins) => {
        if (ins == null || typeof ins !== 'object') return ins;
        // Manejar cantidad que puede venir como number o string
        let c = ins.cantidad;
        if (c === undefined || c === null) return ins;
        if (typeof c === 'string') {
          // aceptar coma decimal
          const normalized = c.replace(',', '.');
          c = parseFloat(normalized);
        }
        if (typeof c === 'number' && !Number.isNaN(c)) {
          const rounded = truncate ? Math.trunc(c * 100) / 100 : Math.round(c * 100) / 100;
          // Si difiere, marcar como cambiado
          if (Math.abs(rounded - c) > 1e-9) {
            changed = true;
            const newIns = Object.assign({}, ins, { cantidad: rounded });
            changedPreview.push({ doc: doc.id, before: ins.cantidad, after: rounded, insumo: ins.nombre || ins.id });
            return newIns;
          }
        }
        return ins;
      });

      if (changed) {
        if (dryRun) {
          console.log(`DRY-RUN: Documento ${doc.id} tendría ${insumos.length} insumos modificados.`);
        } else {
          await doc.ref.update({ insumos: newInsumos });
          console.log(`Documento actualizado: ${doc.id}`);
        }
        updatedDocs++;
      }
    }

    console.log(`Proceso terminado. Documentos que cambiarían/actualizados: ${updatedDocs}`);
    if (dryRun && changedPreview.length > 0) {
      console.log('\nPreview de cambios (primeros 50):');
      changedPreview.slice(0, 50).forEach((c) => console.log(`- doc=${c.doc} insumo=${c.insumo} ${c.before} -> ${c.after}`));
    }
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}

main();
