import '../../core/api_client.dart';
import '../../core/matrix_math.dart';

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.matrices,
    required this.operators,
    required this.result,
    required this.source,
    required this.createdAt,
  });

  final int id;

  /// A, B, C… y el operador entre cada par.
  final List<Grid> matrices;
  final List<MatrixOp> operators;
  final Grid result;
  final String source;
  final DateTime createdAt;

  static Grid _grid(Object? json) => [
    for (final row in json! as List) [for (final v in row as List) v as String],
  ];

  bool get compound => matrices.length > 2;

  /// "Suma", "Resta" o "Compuesta (3)".
  String get label =>
      compound ? 'Compuesta (${matrices.length})' : operators.first.label;

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'] as int,
    // Las operaciones guardadas antes de las compuestas solo traen a y b.
    matrices: json['matrices'] == null
        ? [_grid(json['a']), _grid(json['b'])]
        : [for (final m in json['matrices'] as List) _grid(m)],
    operators: json['operators'] == null
        ? [MatrixOp.fromApi(json['operation'] as String)]
        : [
            for (final op in json['operators'] as List)
              MatrixOp.fromSymbol(op as String),
          ],
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
  Future<void> save(
    List<Grid> matrices,
    List<MatrixOp> operators, {
    required bool fromImage,
  }) => api.post('/api/calculate', {
    'matrices': matrices,
    'operators': [for (final op in operators) op.apiSymbol],
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
