import 'rational.dart';

enum MatrixOp {
  add('add', '+', '+', 'Suma'),
  subtract('subtract', '-', '−', 'Resta');

  const MatrixOp(this.api, this.apiSymbol, this.symbol, this.label);

  /// Valor que usa la API en la forma simple ("add" / "subtract").
  final String api;

  /// Operador en las expresiones de la API ("+" / "-").
  final String apiSymbol;
  final String symbol;
  final String label;

  MatrixOp get flipped => this == add ? subtract : add;

  static MatrixOp fromApi(String? value) =>
      value == 'subtract' ? MatrixOp.subtract : MatrixOp.add;

  static MatrixOp fromSymbol(String value) =>
      value == '-' ? MatrixOp.subtract : MatrixOp.add;
}

typedef Grid = List<List<String>>;

/// Máximo de matrices en una operación compuesta (A … H).
const maxMatrices = 8;

/// Nombre de la matriz en la posición [index]: A, B, C…
String matrixName(int index) => String.fromCharCode(0x41 + index);

/// "A + B − C" para las primeras `ops.length + 1` matrices.
String expressionOf(List<MatrixOp> ops) => [
  matrixName(0),
  for (final (i, op) in ops.indexed) '${op.symbol} ${matrixName(i + 1)}',
].join(' ');

/// Celda que no es un número: [matrix] es 'A', 'B', 'C'…
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
  const MatrixResult({
    required this.values,
    this.partials = const [],
    this.errors = const {},
    this.sizeError,
  });

  final Grid values;

  /// Resultado acumulado tras cada operador, de izquierda a derecha:
  /// `partials[k]` es el valor de las primeras k + 2 matrices. El último es
  /// [values].
  final List<Grid> partials;
  final Set<CellError> errors;

  /// Mensaje si las matrices no tienen todas el mismo tamaño.
  final String? sizeError;

  bool get ok => errors.isEmpty && sizeError == null;
}

/// Evalúa A op₁ B op₂ C … celda a celda, de izquierda a derecha. Las celdas
/// vacías o inválidas se devuelven en [MatrixResult.errors] para marcarlas en
/// pantalla.
MatrixResult evaluate(List<Grid> matrices, List<MatrixOp> ops) {
  assert(matrices.length >= 2 && ops.length == matrices.length - 1);
  final rows = matrices.first.length;
  final cols = rows == 0 ? 0 : matrices.first.first.length;
  for (final (i, m) in matrices.indexed) {
    final size = m.isEmpty ? (0, 0) : (m.length, m.first.length);
    if (size != (rows, cols) || m.any((r) => r.length != cols)) {
      return MatrixResult(
        values: const [],
        sizeError:
            'Todas las matrices deben tener el mismo tamaño '
            '(A es $rows×$cols y ${matrixName(i)} es ${size.$1}×${size.$2}).',
      );
    }
  }

  final errors = <CellError>{};
  final parsed = [
    for (final (i, m) in matrices.indexed)
      [
        for (var r = 0; r < rows; r++)
          [
            for (var c = 0; c < cols; c++)
              () {
                final v = Rational.tryParse(m[r][c]);
                if (v == null) errors.add(CellError(matrixName(i), r, c));
                return v;
              }(),
          ],
      ],
  ];
  if (errors.isNotEmpty) {
    return MatrixResult(values: const [], errors: errors);
  }

  final partials = <Grid>[];
  final acc = [
    for (final row in parsed.first) [for (final v in row) v!],
  ];
  // Fracción solo en las celdas donde alguna matriz usada tenía una fracción.
  final asFraction = [
    for (final row in matrices.first) [for (final v in row) v.contains('/')],
  ];
  for (final (k, op) in ops.indexed) {
    final next = parsed[k + 1];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final y = next[r][c]!;
        acc[r][c] = op == MatrixOp.add ? acc[r][c] + y : acc[r][c] - y;
        asFraction[r][c] |= matrices[k + 1][r][c].contains('/');
      }
    }
    partials.add([
      for (var r = 0; r < rows; r++)
        [
          for (var c = 0; c < cols; c++)
            acc[r][c].format(asFraction: asFraction[r][c]),
        ],
    ]);
  }
  return MatrixResult(values: partials.last, partials: partials);
}

/// Operación simple entre dos matrices.
MatrixResult calculate(MatrixOp op, Grid a, Grid b) => evaluate([a, b], [op]);
