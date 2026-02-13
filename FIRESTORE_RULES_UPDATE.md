# 📝 Actualización de Reglas de Firestore

## 🎯 Nueva Funcionalidad: Estado de Salsa de Ajo en Tiempo Real

Se ha agregado una nueva colección `configuracion` en Firestore para almacenar configuraciones compartidas entre todos los dispositivos, incluyendo el estado de los potes de salsa de ajo.

---

## 🔧 Pasos para Aplicar las Nuevas Reglas

### **Opción 1: Desde Firebase Console (Recomendado)**

1. **Ir a Firebase Console**:
   - Abre [https://console.firebase.google.com](https://console.firebase.google.com)
   - Selecciona tu proyecto: **Shawarma-Oxa-APB**

2. **Navegar a Firestore Rules**:
   - En el menú lateral, ve a **Firestore Database**
   - Haz clic en la pestaña **Reglas** (Rules)

3. **Copiar las nuevas reglas**:
   - Abre el archivo `firestore.rules` en este proyecto
   - Copia TODO el contenido
   - Pégalo en el editor de la consola de Firebase

4. **Publicar**:
   - Haz clic en **Publicar** (Publish)
   - Espera la confirmación

---

### **Opción 2: Desde Firebase CLI**

Si tienes Firebase CLI instalado:

```powershell
# Asegúrate de estar en el directorio del proyecto
cd C:\Users\Usuario\shawarma_pos_nuevo

# Desplegar las reglas
firebase deploy --only firestore:rules
```

---

## 📋 Resumen de Cambios en las Reglas

### **✅ Nueva Sección Agregada**

```javascript
// ---------- configuración (estado compartido) ----------
match /configuracion/{configId} {
  // Cualquier usuario autenticado puede leer la configuración
  allow read: if isSignedIn();
  
  // Cualquier usuario autenticado puede escribir
  allow write: if isSignedIn();
  
  // Solo admins pueden eliminar configuraciones
  allow delete: if isAdmin();
}
```

### **🔐 Permisos Configurados**

- **Lectura (`read`)**: Cualquier usuario autenticado
- **Escritura (`write`)**: Cualquier usuario autenticado
- **Eliminación (`delete`)**: Solo administradores

> **💡 Nota de Seguridad**: Si prefieres que solo los administradores puedan modificar el estado de salsa, cambia la línea:
> ```javascript
> allow write: if isAdmin();
> ```

---

## 🗂️ Estructura del Documento en Firestore

**Ruta**: `configuracion/salsa_de_ajo`

**Contenido**:
```json
{
  "potes": [
    {
      "id": 1,
      "fraccion": 1.0
    },
    {
      "id": 2,
      "fraccion": 0.75
    },
    {
      "id": 3,
      "fraccion": 0.5
    }
  ],
  "ultimaActualizacion": "timestamp"
}
```

---

## ✅ Verificación

Después de aplicar las reglas:

1. **Prueba desde la app**:
   - Abre la app en cualquier dispositivo
   - Toca el icono de salsa de ajo (🧴)
   - Modifica algún pote
   - Presiona "Guardar"
   - ✅ No debería aparecer ningún error

2. **Verifica sincronización**:
   - Abre la app en otro dispositivo/navegador
   - Toca el icono de salsa
   - ✅ Deberías ver los cambios que hiciste en el paso 1

---

## 🚨 Solución de Problemas

### Error: "permission-denied"
- ✅ **Solución**: Asegúrate de haber publicado las reglas correctamente
- Verifica que el usuario esté autenticado (`isSignedIn()`)

### Los cambios no se sincronizan
- ✅ **Solución**: Verifica tu conexión a Internet
- Comprueba que ambos dispositivos tengan la sesión activa
- Revisa la consola de Firebase para ver logs

---

## 📞 Soporte

Si tienes problemas aplicando las reglas:

1. Revisa los logs en Firebase Console → Firestore → Reglas
2. Verifica que la sintaxis del archivo `firestore.rules` sea correcta
3. Asegúrate de que Firebase CLI esté actualizado: `npm install -g firebase-tools`

---

**Fecha de actualización**: 17 de octubre de 2025  
**Versión de reglas**: 2.1.0  
**Característica**: Sistema de Salsa de Ajo en Tiempo Real
