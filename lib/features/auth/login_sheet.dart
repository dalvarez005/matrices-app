import 'package:flutter/material.dart';

import '../../app/env.dart';
import '../../core/api_client.dart';
import '../../core/feedback.dart';
import '../../core/session.dart';
import 'google_id_token.dart';
import 'google_sign_in_area.dart';

/// Inicio de sesión opcional. Devuelve true si se inició sesión.
Future<bool> showLoginSheet(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (_) => const _LoginSheet(),
    ) ??
    false;

class _LoginSheet extends StatefulWidget {
  const _LoginSheet();

  @override
  State<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<_LoginSheet> {
  var _loading = false;

  Future<void> _withToken(Future<String?> Function() getToken) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final idToken = await getToken();
      if (idToken == null || !mounted) return; // cerró el selector
      await SessionScope.read(context).signInWithGoogle(idToken);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showToast(
          context,
          'No se pudo iniciar sesión con Google.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Guarda tu historial',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Inicia sesión para guardar tus operaciones y verlas desde '
              'cualquier dispositivo. Sin cuenta la calculadora funciona igual.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (Env.googleConfigured)
              GoogleSignInArea(
                loading: _loading,
                onPressed: () => _withToken(googleIdToken),
                onWebIdToken: (token) => _withToken(() async => token),
              )
            else
              Text(
                'El inicio con Google aún no está configurado en esta versión.',
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir sin cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
