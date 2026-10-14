import 'dart:typed_data';

import '../../core/api_client.dart';
import '../../core/matrix_math.dart';

typedef OcrGrid = List<List<String?>>;

/// Lo que la API leyó de la foto: una o dos matrices (celdas ilegibles en
/// null) y la operación si se vio el signo entre ellas.
class OcrResult {
  const OcrResult({required this.matrices, this.operation});

  final List<OcrGrid> matrices;
  final MatrixOp? operation;

  factory OcrResult.fromJson(Map<String, dynamic> json) => OcrResult(
    matrices: [
      for (final m in json['matrices'] as List)
        [
          for (final row in (m as Map)['values'] as List)
            [for (final v in row as List) v as String?],
        ],
    ],
    operation: json['operation'] == null
        ? null
        : MatrixOp.fromApi(json['operation'] as String),
  );
}

class OcrService {
  OcrService(this.api);

  final ApiClient api;

  Future<OcrResult> read(Uint8List bytes, String fileName) async =>
      OcrResult.fromJson(
        await api.postImage('/api/ocr', bytes, fileName)
            as Map<String, dynamic>,
      );
}

/// Lo elegido en la revisión: valores para A y/o B.
class OcrSelection {
  const OcrSelection({this.a, this.b, this.operation});

  final OcrGrid? a;
  final OcrGrid? b;
  final MatrixOp? operation;
}
