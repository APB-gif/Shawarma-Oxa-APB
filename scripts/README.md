Migración de claves de pagos en la colección `gastos`

Propósito
--------
Este script renombra las claves usadas en el campo `pagos` de documentos de la colección `gastos` en Firestore:
- `Tarjeta` -> `Ruben`
- `Yape Personal` o `Yape` -> `Aharhel`

El script realiza un dry-run por defecto (solo muestra cuántos documentos serían afectados y ejemplos). Use `--apply` para realizar los cambios.

Requisitos
---------
- Node.js 16+ instalado.
- Acceso a un Service Account JSON con permisos para Firestore (Editor o custom con permisos de lectura/actualización de documentos).

Cómo ejecutar (PowerShell)
-------------------------
1) Dry-run (recomendado):

```powershell
# Exporta la variable de entorno con la ruta a tu JSON de service account
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\path\to\service-account.json'
# Ejecuta el script (dry-run)
node .\scripts\migrate_gastos_payment_keys.js
```

2) Aplicar los cambios (pruebe primero con --limit pequeño):

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\path\to\service-account.json'
node .\scripts\migrate_gastos_payment_keys.js --apply --limit 100
```

3) Ejecutar en toda la colección:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\path\to\service-account.json'
node .\scripts\migrate_gastos_payment_keys.js --apply
```

Opciones
-------
--apply   : Aplica realmente los cambios (sin esta opción solo dry-run).
--limit N : Limita el número de documentos leídos (útil para pruebas).
--key PATH: Si prefieres, en vez de usar variable de entorno puedes pasar la ruta al key con --key PATH.

Seguridad y recomendaciones
--------------------------
- Haz un backup exportando la colección antes de aplicar la migración (Firestore export o copiar a otra colección).
- Ejecuta primero con --limit pequeño y revisa los ejemplos que se muestran.
- El script suma valores cuando varias claves antiguas mapean a la misma nueva clave (p. ej. si un documento tiene tanto 'Tarjeta' como 'tarjeta' se consolidarán).

Notas técnicas
-------------
- El script usa la librería oficial `@google-cloud/firestore` y `minimist`.
- El script actualiza el campo `pagos` del documento asignando el nuevo objeto.

Si quieres, puedo modificar el script para:
- También migrar la colección de `cajas` u otras colecciones.
- Crear una copia de seguridad automática (p. ej. duplicar documentos antes de actualizar).
- Ejecutarlo desde una función de Cloud Run/Cloud Function (si prefieres no usar localmente).
