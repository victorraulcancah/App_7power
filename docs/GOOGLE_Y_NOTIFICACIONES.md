# Google y notificaciones push: qué configurar

El código del app y del backend ya está hecho. Estas dos funciones se **encienden**
con una configuración que solo se puede hacer en las cuentas de Google/Firebase de
la empresa. Mientras no se haga, el app funciona igual: el botón "Continuar con
Google" no aparece y no se piden permisos de notificaciones.

## 1. "Continuar con Google"

El servidor ya usa un proyecto de Google para el login de la web
(`GOOGLE_CLIENT_ID` en el `.env` del backend). El app usa **ese mismo proyecto**.

1. Entra a [Google Cloud Console](https://console.cloud.google.com) → el proyecto
   del login de la web → **APIs y servicios → Credenciales**.
2. **Crear credenciales → ID de cliente de OAuth → Android**:
   - Nombre del paquete: `com.novik.appecommerce`
   - Huella SHA-1 del certificado con el que se firma el APK:
     - APK actual (firmado con la clave de depuración de este equipo):
       `88:9E:98:33:D4:D1:AF:57:F5:A3:14:33:84:0B:5D:E6:C5:11:89:CC`
     - Cuando exista el keystore de publicación, agregar también su SHA-1
       (`keytool -list -v -keystore <archivo>.jks`). Se pueden registrar varios
       clientes Android en el mismo proyecto.
3. Copia el **ID de cliente de tipo "Web"** (el que ya usa la web) y compila el app
   con él:

   ```bash
   flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_ID=1234-abc.apps.googleusercontent.com
   ```

4. En el servidor no hace falta nada más: `POST /api/auth/google/token` valida el
   token con Google contra `GOOGLE_CLIENT_ID`. Si se usa otro ID de cliente,
   agregarlo a `GOOGLE_MOBILE_CLIENT_IDS` (separados por comas).

Notas:
- Una cuenta nueva entra con los mismos datos provisionales que crea la web
  (apellido "Google" y documento `GOOGLE_...`); igual que en la web, el cliente
  debe completar sus datos para comprar.
- Si el proyecto de Google está en modo "Prueba", solo entran los correos
  agregados como usuarios de prueba.

## 2. Notificaciones push (avisos del estado de la compra)

Cuando el personal cambia la etapa de una compra (facturada, en camino,
entregada o cancelada) el cliente recibe un aviso en su teléfono.

**Firebase**

1. [Consola de Firebase](https://console.firebase.google.com) → crear un proyecto
   (o usar el de Google Cloud) → **Agregar app → Android**, con el paquete
   `com.novik.appecommerce`.
2. Descargar `google-services.json` y guardarlo en
   `appecommerce/android/app/google-services.json` (no se sube a git). Con ese
   archivo el build activa Firebase solo; sin él, compila sin notificaciones.
3. **Configuración del proyecto → Cuentas de servicio → Generar nueva clave
   privada**: descarga un JSON. Subirlo al servidor **fuera de la carpeta pública**
   (por ejemplo `/etc/7power/firebase-push.json`).

**Servidor (ecommerce-back)**

```bash
# .env
FCM_CREDENTIALS=/etc/7power/firebase-push.json

php artisan migrate          # crea la tabla dispositivos_cliente
php artisan config:cache
```

**Probar**: iniciar sesión en el app con un cliente que tenga una compra pagada,
aceptar el permiso de notificaciones y, desde el panel de "Compras en línea",
cambiar la etapa de seguimiento. Llega el aviso; al tocarlo abre "Mis compras".

Cómo funciona:
- Al iniciar sesión el app registra su teléfono (`POST /api/cliente/dispositivos`)
  y al cerrar sesión lo quita, así los avisos de un cliente no llegan al teléfono
  de otro.
- Los envíos usan FCM HTTP v1 con la cuenta de servicio; si Firebase falla, el
  seguimiento se guarda igual.

## 3. Bloqueo con huella

No necesita configuración. En **Mi cuenta → Seguridad** el cliente lo activa o lo
apaga (aparece solo si el teléfono tiene huella, rostro o PIN). También se ofrece
una vez al iniciar sesión.
