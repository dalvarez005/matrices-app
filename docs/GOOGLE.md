# Inicio de sesión con Google

La app pide a Google un **idToken** y la API lo valida contra el client id
**web**. Se necesitan 3 client ids OAuth en Google Cloud Console
(proyecto nuevo o el mismo de Yankees) → *APIs y servicios → Credenciales*:

| Tipo | Datos | Dónde va |
| --- | --- | --- |
| **Web** | Orígenes JS: `https://matrices.quantis.site`, `http://localhost:5191` | `Env.googleServerClientId` (app), `GOOGLE_CLIENT_IDS` (API `.env`), `GIDServerClientID` (iOS) |
| **Android** | Paquete `site.quantis.matrices` + SHA-1 de la clave que firma el APK | No va en código: Google lo reconoce por paquete + SHA-1 |
| **iOS** | Bundle ID `site.quantis.matrices` | `Env.googleIosClientId`, `GIDClientID` y el URL scheme invertido en `ios/Runner/Info.plist` |

SHA-1 de la clave de debug (la que firma el APK hoy):

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android | grep SHA1
```

## Dónde reemplazar

1. `lib/app/env.dart`: `defaultValue` de `googleServerClientId` y
   `googleIosClientId` (los client ids no son secretos).
2. `ios/Runner/Info.plist`: los tres `REEMPLAZAR_...`. El URL scheme es el
   client id de iOS al revés: `com.googleusercontent.apps.<número-xxxx>`.
3. API: `GOOGLE_CLIENT_IDS=<client id web>` en `~/matrices-api/.env` y
   `docker compose up -d`.

En la pantalla de consentimiento OAuth, mientras esté en modo *Prueba*,
solo pueden entrar los correos agregados como usuarios de prueba.
