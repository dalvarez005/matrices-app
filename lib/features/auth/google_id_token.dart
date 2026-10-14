import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../app/env.dart';

/// GoogleSignIn se inicializa una sola vez para toda la app.
Future<void>? _googleInit;

Future<void> initializeGoogleSignIn() =>
    _googleInit ??= GoogleSignIn.instance.initialize(
      // Web solo admite clientId (el web); en móvil el idToken se pide para
      // el client id web (serverClientId), que es el que valida la API.
      serverClientId: kIsWeb ? null : Env.googleServerClientId,
      clientId: kIsWeb
          ? Env.googleServerClientId
          : defaultTargetPlatform == TargetPlatform.iOS
          ? Env.googleIosClientId
          : null,
    );

/// Teléfono: abre el selector de cuentas. Devuelve null si el usuario lo
/// cierra; cualquier otra falla se lanza.
Future<String?> googleIdToken() async {
  try {
    await initializeGoogleSignIn();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'Sin idToken',
      );
    }
    return idToken;
  } on GoogleSignInException catch (e) {
    // Android reporta la falta del cliente OAuth (paquete + SHA-1) como
    // "canceled" con "[16] Account reauth failed"; eso no es cancelar.
    final cancelled =
        (e.code == GoogleSignInExceptionCode.canceled ||
            e.code == GoogleSignInExceptionCode.interrupted) &&
        !(e.description ?? '').contains('reauth failed');
    if (cancelled) return null;
    if (kDebugMode) {
      debugPrint('GoogleSignIn falló: ${e.code} ${e.description}');
    }
    rethrow;
  }
}

/// En web Google no deja abrir su selector desde un botón propio: se muestra
/// su botón (ver `google_sign_in_area.dart`) y el idToken llega por aquí.
Stream<String> googleWebIdTokens() async* {
  await initializeGoogleSignIn();
  yield* GoogleSignIn.instance.authenticationEvents
      .where((event) => event is GoogleSignInAuthenticationEventSignIn)
      .map(
        (event) => (event as GoogleSignInAuthenticationEventSignIn)
            .user
            .authentication
            .idToken,
      )
      .where((token) => token != null)
      .cast<String>();
}

/// Al cerrar sesión, para que la próxima vez se pueda elegir otra cuenta.
Future<void> googleSignOut() async {
  if (!Env.googleConfigured) return;
  try {
    await initializeGoogleSignIn();
    await GoogleSignIn.instance.signOut();
  } catch (_) {
    // Si no había sesión de Google no hay nada que cerrar.
  }
}
