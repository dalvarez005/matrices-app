import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema elegido por el usuario (claro por defecto), guardado en el equipo.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._(super.value);

  static const _key = 'matrices.theme';

  static Future<ThemeController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      return ThemeController._(
        ThemeMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => ThemeMode.light,
        ),
      );
    } catch (_) {
      // Sin almacenamiento (navegador privado): se usa el claro.
      return ThemeController._(ThemeMode.light);
    }
  }

  Future<void> set(ThemeMode mode) async {
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {}
  }
}

/// Botón de la barra superior para elegir claro, oscuro o el del sistema.
class ThemeButton extends StatelessWidget {
  const ThemeButton({super.key, required this.controller});

  final ThemeController controller;

  static const _options = [
    (ThemeMode.light, Icons.light_mode_rounded, 'Claro'),
    (ThemeMode.dark, Icons.dark_mode_rounded, 'Oscuro'),
    (ThemeMode.system, Icons.brightness_auto_rounded, 'Como el sistema'),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, mode, _) => PopupMenuButton<ThemeMode>(
        tooltip: 'Tema',
        icon: Icon(_options.firstWhere((o) => o.$1 == mode).$2),
        initialValue: mode,
        onSelected: controller.set,
        itemBuilder: (_) => [
          for (final (value, icon, label) in _options)
            PopupMenuItem(
              value: value,
              child: Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 12),
                  Text(label),
                  if (value == mode) ...[
                    const Spacer(),
                    const Icon(Icons.check_rounded, size: 18),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
