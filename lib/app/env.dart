import 'package:flutter/foundation.dart';

/// Configuración por ambiente. Se sobrescribe al compilar con
/// `--dart-define=API_BASE_URL=local`, etc.
class Env {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// API en la Orange Pi (HTTPS por el túnel de Cloudflare).
  static const productionApiBaseUrl = 'https://matricalcapi.quantis.site';

  /// API en la máquina de desarrollo: el emulador de Android llega por
  /// 10.0.2.2; el navegador y el simulador de iOS, por localhost.
  static String get localApiBaseUrl =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:5120'
      : 'http://localhost:5120';

  static String get apiBaseUrl => switch (_apiBaseUrl) {
    '' => productionApiBaseUrl,
    'local' => localApiBaseUrl,
    _ => _apiBaseUrl,
  };

  /// Client ID "Web" de Google: la API valida el idToken contra él
  /// (GOOGLE_CLIENT_IDS del backend). Lo usan web, Android e iOS.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '633999953572-814g0n5hc3d30m3b4svk88k2sr9sdjsg.apps.googleusercontent.com',
  );

  /// Client ID de iOS (también en ios/Runner/Info.plist como GIDClientID).
  /// Pendiente: solo hace falta para la app nativa de iPhone (la PWA usa el web).
  /// Android no lleva ID en código: Google lo reconoce por paquete + SHA-1.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  static bool get googleConfigured =>
      googleServerClientId.isNotEmpty &&
      (kIsWeb ||
          defaultTargetPlatform != TargetPlatform.iOS ||
          googleIosClientId.isNotEmpty);
}
