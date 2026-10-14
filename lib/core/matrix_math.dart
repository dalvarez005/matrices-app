import 'rational.dart';

enum MatrixOp {
  add('add', '+', 'Suma'),
  subtract('subtract', '−', 'Resta');

  const MatrixOp(this.api, this.symbol, this.label);

  /// Valor que usa la API ("add" / "subtract").
  final String api;
  final String symbol;
  final String label;

  static MatrixOp fromApi(String? value) =>
      value == 'subtract' ? MatrixOp.subtract : MatrixOp.add;
}

typedef Grid = List<List<String>>;

/// Celda que no es un número: [matrix] es 'A' o 'B'.
class CellError {
  const CellError(this.matrix, this.row, this.col);

  final String matrix;
  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is CellError &&
      other.matrix == matrix &&
      other.row == row &&
      other.col == col;

  @override
  int get hashCode => Object.hash(matrix, row, col);
}

class MatrixResult {
  const MatrixResult({required this.values, this.errors = const {}});

  final Grid values;
  final Set<CellError> errors;

  bool get ok => errors.isEmpty;
}

/// Suma o resta celda a celda. Las celdas vacías o inválidas se devuelven en
/// [MatrixResult.errors] para marcarlas en pantalla.
MatrixResult calculate(MatrixOp op, Grid a, Grid b) {
  assert(a.length == b.length && a.first.length == b.first.length);
  final errors = <CellError>{};
  Rational? read(String name, Grid m, int r, int c) {
    final v = Rational.tryParse(m[r][c]);
    if (v == null) errors.add(CellError(name, r, c));
    return v;
  }

  final values = [
    for (var r = 0; r < a.length; r++)
      [
        for (var c = 0; c < a[r].length; c++)
          () {
            final x = read('A', a, r, c);
            final y = read('B', b, r, c);
            if (x == null || y == null) return '';
            final z = op == MatrixOp.add ? x + y : x - y;
            // Fracción solo si alguna de las dos celdas era fracción.
            final asFraction = a[r][c].contains('/') || b[r][c].contains('/');
            return z.format(asFraction: asFraction);
          }(),
      ],
  ];
  return MatrixResult(values: values, errors: errors);
}
