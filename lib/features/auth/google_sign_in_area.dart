import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'google_id_token.dart';
import 'google_web_button.dart'
    if (dart.library.js_interop) 'google_web_button_web.dart';

/// "Continuar con Google": en el teléfono es un botón propio que abre el
/// selector ([onPressed]); en web es el botón de Google, transparente sobre
/// el nuestro, que entrega el idToken a [onWebIdToken].
class GoogleSignInArea extends StatefulWidget {
  const GoogleSignInArea({
    super.key,
    required this.loading,
    required this.onPressed,
    required this.onWebIdToken,
  });

  final bool loading;
  final VoidCallback onPressed;
  final ValueChanged<String> onWebIdToken;

  @override
  State<GoogleSignInArea> createState() => _GoogleSignInAreaState();
}

class _GoogleSignInAreaState extends State<GoogleSignInArea> {
  StreamSubscription<String>? _tokens;
  late final Future<void> _ready = kIsWeb
      ? initializeGoogleSignIn()
      : Future.value();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _tokens = googleWebIdTokens().listen(
        widget.onWebIdToken,
        onError: (_) {}, // ventana cerrada: el siguiente intento funciona
      );
    }
  }

  @override
  void dispose() {
    unawaited(_tokens?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || widget.loading) {
      return _GoogleButton(
        loading: widget.loading,
        onPressed: widget.onPressed,
      );
    }
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) =>
          snapshot.connectionState == ConnectionState.done
          ? buildGoogleWebButton(
              // Solo se ve: el clic lo atiende el botón de Google encima.
              visual: _GoogleButton(loading: false, onPressed: () {}),
            )
          : const SizedBox(height: 54),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: scheme.surfaceContainerHigh,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: loading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.string(_googleLogo, width: 20, height: 20),
                const SizedBox(width: 12),
                const Text(
                  'Continuar con Google',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
    );
  }
}

const _googleLogo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';
