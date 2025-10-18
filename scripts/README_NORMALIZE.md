Uso del workflow automático para normalizar `insumos[].cantidad` en Firestore

Resumen

He agregado un workflow de GitHub Actions que puede ejecutar el script `scripts/fix_insumos_firestore.js` en un runner de GitHub y actualizar tus documentos en Firestore.

Pasos para permitir que lo ejecute por ti (requeridos una sola vez)

1) Genera una clave de cuenta de servicio en Firebase Console (Project Settings → Service accounts → Generate new private key). Se descargará un JSON.

2) En tu repositorio de GitHub: ve a Settings → Secrets → Actions → New repository secret.
   - Crea un secret llamado `FIREBASE_SA` y pega todo el contenido del JSON allí (valor entero).

3) En GitHub Actions: ve a la pestaña 'Actions' del repo, selecciona el workflow 'Normalize Insumos in Firestore' y ejecútalo (botón 'Run workflow').
   - Marca `dry_run` = true para revisar primero.
   - Si todo está bien, ejecútalo con `dry_run` = false para aplicar los cambios.

Opciones
- dry_run: Si es true, el workflow detecta y muestra los cambios pero no hace actualizaciones.
- truncate: Si es true, el script truncará a 2 decimales en vez de redondear.

Consejos
- Haz un respaldo por si acaso (Firestore export o descarga manual).
- Revisa la salida del workflow (logs) y el artifact `normalize-log` si quieres registros.

Si quieres, puedo crear una PR que incluya el secret por ti, pero por seguridad GitHub no permite escribir secretos por API sin permisos y necesitarás pegar la clave manualmente en los Secrets del repo. Si me das acceso a tu GitHub (o me autorizas a crear un fork y PR), puedo abrir una PR que incluya el workflow; aún así deberás añadir el secret con la clave.
