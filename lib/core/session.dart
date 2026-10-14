import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.picture,
  });

  final int id;
  final String email;
  final String name;
  final String? picture;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    email: json['email'] as String,
    name: json['name'] as String? ?? '',
    picture: json['picture'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'picture': picture,
  };
}

/// Sesión opcional: sin cuenta la calculadora funciona igual, con cuenta
/// además se guarda el historial.
class Session extends ChangeNotifier {
  Session({required this.api, FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    api.onUnauthorized = () {
      _clear();
      onExpired?.call();
    };
  }

  final ApiClient api;
  final FlutterSecureStorage _storage;
  static const _key = 'matrices.session';

  AppUser? _user;
  AppUser? get user => _user;
  bool get signedIn => _user != null;

  /// Se avisa al usuario que la sesión venció.
  VoidCallback? onExpired;

  /// Recupera la sesión guardada en el dispositivo (sin red).
  Future<void> restore() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      api.token = json['token'] as String;
      _user = AppUser.fromJson(json['user'] as Map<String, dynamic>);
    } catch (e) {
      // Dato ilegible (p. ej. tras reinstalar): se descarta.
      if (kDebugMode) debugPrint('Sesión guardada ilegible: $e');
      await _storage.delete(key: _key);
    }
  }

  /// Cambia el idToken de Google por una sesión de la API.
  Future<void> signInWithGoogle(String idToken) async {
    final json = await api.post('/api/auth/google', {
      'idToken': idToken,
    }) as Map<String, dynamic>;
    api.token = json['token'] as String;
    _user = AppUser.fromJson(json['user'] as Map<String, dynamic>);
    await _storage.write(key: _key, value: jsonEncode(json));
    notifyListeners();
  }

  Future<void> signOut() async {
    await _clear();
  }

  /// Borra la cuenta y todo su historial en el servidor.
  Future<void> deleteAccount() async {
    await api.delete('/api/auth/me');
    await _clear();
  }

  Future<void> _clear() async {
    api.token = null;
    _user = null;
    notifyListeners();
    await _storage.delete(key: _key);
  }
}

/// Acceso a la [Session] desde cualquier pantalla: `SessionScope.of(context)`.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({
    super.key,
    required Session session,
    required super.child,
  }) : super(notifier: session);

  static Session of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;

  /// Sin suscribirse a cambios (para usar en callbacks).
  static Session read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}
