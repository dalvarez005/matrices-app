import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Error de la API ya listo para mostrar al usuario.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Cliente JSON de la API de matrices. Los errores llegan como
/// `{ "detail": "mensaje" }` (FastAPI).
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Token de sesión; null si se usa la app sin cuenta.
  String? token;

  /// La API rechazó el token (vencido o cuenta borrada).
  VoidCallback? onUnauthorized;

  static const _timeout = Duration(seconds: 20);

  /// En la Orange Pi el OCR de una foto puede tardar varios segundos.
  static const _uploadTimeout = Duration(seconds: 90);

  Future<dynamic> get(String path) => _send(http.Request('GET', _uri(path)));

  Future<dynamic> post(String path, Map<String, dynamic> body) => _send(
    http.Request('POST', _uri(path))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body),
  );

  Future<dynamic> delete(String path) =>
      _send(http.Request('DELETE', _uri(path)));

  Future<dynamic> postImage(String path, Uint8List bytes, String fileName) =>
      _send(
        http.MultipartRequest('POST', _uri(path))
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: fileName),
          ),
        timeout: _uploadTimeout,
      );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _send(
    http.BaseRequest request, {
    Duration timeout = _timeout,
  }) async {
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'El servidor tardó demasiado. Intenta de nuevo.',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('API ${request.url}: $e');
      throw const ApiException('Sin conexión con el servidor.');
    }

    final status = response.statusCode;
    // FastAPI no indica charset: se decodifica como UTF-8 (tildes, ñ).
    final json = response.bodyBytes.isEmpty
        ? null
        : _decode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (status >= 200 && status < 300) return json;
    if (kDebugMode) {
      debugPrint(
        'API ${request.method} ${request.url} → $status: ${response.body}',
      );
    }
    if (status == 401 && token != null) onUnauthorized?.call();
    final detail = json is Map ? json['detail'] : null;
    throw ApiException(
      detail is String ? detail : 'Algo salió mal (error $status).',
      statusCode: status,
    );
  }

  static dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}
