# Publicar el APK de 7Power

## 1. Probar un APK ya mismo

```bash
flutter build apk --release
```

Queda en `build/app/outputs/flutter-apk/app-release.apk`. Sin clave de firma
propia se firma con la clave de **debug**: sirve para instalarlo y probarlo,
**no** para subirlo a Play Store.

Por defecto la app usa la API de producción (`https://api.7power.pe`). Para
apuntar a otro backend al compilar:

```bash
flutter build apk --release --dart-define=API_DOMAIN=https://otro-dominio.pe
```

## 2. Crear la clave de firma (una sola vez)

```bash
keytool -genkey -v -keystore sevenpower-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias sevenpower
```

Guarda el `.jks` y sus contraseñas en un lugar seguro y con respaldo: **si se
pierde, no se puede actualizar la app en Play Store**. No se sube a git.

Luego copia `android/key.properties.example` como `android/key.properties` y
completa tus datos. Con ese archivo presente, `flutter build apk --release` y
`flutter build appbundle --release` firman con tu clave.

## 3. Subir a Play Store

Play Store pide un **App Bundle**:

```bash
flutter build appbundle --release
```

Queda en `build/app/outputs/bundle/release/app-release.aab`.

Antes de la primera publicación:

- **Identificador:** hoy es `com.novik.appecommerce` (`android/app/build.gradle.kts`).
  No se puede cambiar después de publicar. Confírmalo.
- **Versión:** sube `version:` en `pubspec.yaml` en cada publicación (`1.0.0+1`:
  el número tras el `+` es el código de versión y debe aumentar siempre).

## 4. Ícono y pantalla de arranque

Salen del "7" de la marca (`assets/icon/seven.svg`). Para regenerarlos:

```bash
flutter test tool/generate_icons.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
