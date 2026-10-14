# Matrices

App de **suma y resta de matrices** en Flutter: web (PC y PWA para iPhone),
APK de Android e iOS. API en `../matrices-api`.

- Sin cuenta: la calculadora funciona completa (el cálculo es local y exacto).
- Con Google: cada operación se guarda en el historial del usuario.
- **Desde foto**: se sube una foto de una o dos matrices, la API las lee
  (OCR) y se muestran para corregir antes de usarlas.

Tamaños de 1×1 a 10×10, enteros, decimales (`2.5` o `2,5`) y fracciones
(`3/4`). Paso a paso del cálculo, "usar resultado como A" para encadenar,
copiar resultado, tema claro/oscuro.

## Estructura

```
lib/
  app/        env (URL de la API, client ids de Google), tema, servicios
  core/       cliente HTTP, sesión, aritmética exacta (Rational), suma/resta
  features/
    calculator/   pantalla principal y editor de matrices
    ocr/          lectura de fotos y pantalla de revisión
    history/      historial (paginado, deslizar para borrar)
    auth/         login con Google (botón propio en móvil, de Google en web)
web/          PWA: index, manifest, service worker (sw.js)
deploy/web/   imagen nginx y script de publicación
```

## Desarrollo

```bash
flutter pub get
flutter test

# Contra la API local (uv run matrices-api en ../matrices-api)
flutter run -d chrome --web-port 5191 --dart-define=API_BASE_URL=local
flutter run --dart-define=API_BASE_URL=local     # emulador Android (usa 10.0.2.2)
```

Sin `API_BASE_URL` usa la del servidor (`Env.productionApiBaseUrl`).

## Compilar

```bash
flutter build apk --release        # build/app/outputs/flutter-apk/app-release.apk
flutter build web --release        # build/web
flutter build ipa                  # en una Mac
```

El APK se firma con la clave de debug (como Yankees). Para la Play Store hay
que crear una clave propia y registrar su SHA-1 en Google (docs/GOOGLE.md).

## Web: landing + app

`matrices.quantis.site` sirve la **landing** (`landing/`) en `/` y la app
Flutter en `/app/`. La landing detecta el dispositivo:

- **iPhone/iPad:** pasos para instalarla como PWA desde Safari.
- **Android:** descarga del APK publicado (lo sirve la API).
- **PC:** abrir la app en el navegador, con las tres opciones abajo.

`/subir` es la página para publicar un APK nuevo (pide la clave de subida).

```bash
deploy/web/build.sh                              # arma build/site (landing + app)
deploy/web/deploy.sh orangepi@192.168.1.77       # publica en ~/matrices-web, puerto 5190
```

En el iPhone: abrir `matrices.quantis.site/app/` en Safari → Compartir →
*Agregar a inicio*.

## Inicio de sesión con Google

Falta configurar los client ids: [docs/GOOGLE.md](docs/GOOGLE.md). Mientras
tanto la app funciona sin cuenta y el panel de login lo indica.
