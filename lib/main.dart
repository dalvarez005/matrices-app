import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/env.dart';
import 'app/services.dart';
import 'app/theme_controller.dart';
import 'app/theme.dart';
import 'core/api_client.dart';
import 'core/session.dart';
import 'features/calculator/calculator_page.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  // Web: las pantallas no se agregan al historial del navegador (en iPhone
  // deslizar desde el borde recargaría la app en vez de volver).
  setUrlStrategy(null);
  WidgetsFlutterBinding.ensureInitialized();

  final services = Services.instance = Services(
    ApiClient(baseUrl: Env.apiBaseUrl),
  );
  services.theme = await ThemeController.load();
  // Sin cuenta se entra igual: la sesión solo agrega el historial.
  await services.session.restore();
  services.session.onExpired = () => _messengerKey.currentState?.showSnackBar(
    const SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(
        'Tu sesión expiró. Inicia sesión de nuevo para guardar el historial.',
      ),
    ),
  );

  runApp(MatricesApp(session: services.session, theme: services.theme));
}

class MatricesApp extends StatelessWidget {
  const MatricesApp({super.key, required this.session, required this.theme});

  final Session session;
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: session,
      child: ValueListenableBuilder(
        valueListenable: theme,
        builder: (context, mode, _) => MaterialApp(
          title: 'MatriCalc',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          scaffoldMessengerKey: _messengerKey,
          home: const CalculatorPage(),
        ),
      ),
    );
  }
}
