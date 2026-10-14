import '../../core/api_client.dart';
import '../../core/matrix_math.dart';

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.operation,
    required this.a,
    required this.b,
    required this.result,
    required this.source,
    required this.createdAt,
  });

  final int id;
  final MatrixOp operation;
  final Grid a;
  final Grid b;
  final Grid result;
  final String source;
  final DateTime createdAt;

  static Grid _grid(Object? json) => [
    for (final row in json! as List) [for (final v in row as List) v as String],
  ];

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'] as int,
    operation: MatrixOp.fromApi(json['operation'] as String),
    a: _grid(json['a']),
    b: _grid(json['b']),
    result: _grid(json['result']),
    source: json['source'] as String,
    // La API guarda en UTC.
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );
}

class HistoryChunk {
  const HistoryChunk(this.items, this.nextBefore);

  final List<HistoryItem> items;

  /// Para pedir la página siguiente; null si no hay más.
  final int? nextBefore;
}

class HistoryRepository {
  HistoryRepository(this.api);

  final ApiClient api;

  /// Guarda la operación en el historial (la API la vuelve a calcular).
  Future<void> save(MatrixOp op, Grid a, Grid b, {required bool fromImage}) =>
      api.post('/api/calculate', {
        'operation': op.api,
        'a': a,
        'b': b,
        'source': fromImage ? 'image' : 'manual',
      });

  Future<HistoryChunk> page({int? before, int limit = 20}) async {
    final json = await api.get(
      '/api/history?limit=$limit${before == null ? '' : '&before=$before'}',
    ) as Map<String, dynamic>;
    return HistoryChunk([
      for (final item in json['items'] as List)
        HistoryItem.fromJson(item as Map<String, dynamic>),
    ], json['nextBefore'] as int?);
  }

  Future<void> delete(int id) => api.delete('/api/history/$id');

  Future<void> clear() => api.delete('/api/history');
}
