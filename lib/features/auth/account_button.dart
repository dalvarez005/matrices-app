import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/feedback.dart';
import '../../core/session.dart';
import 'google_id_token.dart';
import 'login_sheet.dart';

/// Esquina de la barra superior: "Iniciar sesión" o la foto del usuario con
/// su menú.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final user = session.user;
    if (user == null) {
      return TextButton.icon(
        onPressed: () => showLoginSheet(context),
        icon: const Icon(Icons.login_rounded),
        label: const Text('Entrar'),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Cuenta',
      offset: const Offset(0, 48),
      onSelected: (value) => _onSelected(context, value),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(user.name),
            subtitle: Text(user.email),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded),
            title: Text('Cerrar sesión'),
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_forever_rounded),
            title: Text('Eliminar cuenta'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _Avatar(user: user),
      ),
    );
  }

  Future<void> _onSelected(BuildContext context, String value) async {
    final session = SessionScope.read(context);
    if (value == 'logout') {
      await session.signOut();
      await googleSignOut();
      if (context.mounted) showToast(context, 'Sesión cerrada.');
      return;
    }
    final ok = await confirm(
      context,
      title: '¿Eliminar tu cuenta?',
      message:
          'Se borrará tu cuenta y todo tu historial. No se puede deshacer.',
      action: 'Eliminar',
    );
    if (!ok) return;
    try {
      await session.deleteAccount();
      await googleSignOut();
      if (context.mounted) showToast(context, 'Cuenta eliminada.');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final initial = (user.name.isNotEmpty ? user.name : user.email)[0]
        .toUpperCase();
    final fallback = CircleAvatar(radius: 17, child: Text(initial));
    if (user.picture == null) return fallback;
    return ClipOval(
      child: Image.network(
        user.picture!,
        width: 34,
        height: 34,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
