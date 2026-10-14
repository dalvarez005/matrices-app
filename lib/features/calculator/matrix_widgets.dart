import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'matrix_fields.dart';

const cellWidth = 64.0;
const cellHeight = 48.0;
const _gap = 6.0;

/// Corchetes a los lados de una matriz, como en el cuaderno.
class MatrixBrackets extends StatelessWidget {
  const MatrixBrackets({super.key, required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BracketPainter(
        color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: child,
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  _BracketPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const arm = 7.0;
    final h = size.height, w = size.width;
    canvas.drawPath(
      Path()
        ..moveTo(arm, 1)
        ..lineTo(1, 1)
        ..lineTo(1, h - 1)
        ..lineTo(arm, h - 1),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - arm, 1)
        ..lineTo(w - 1, 1)
        ..lineTo(w - 1, h - 1)
        ..lineTo(w - arm, h - 1),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}

/// Etiqueta redonda "A", "B", "R".
class MatrixLabel extends StatelessWidget {
  const MatrixLabel(this.text, {super.key, this.caption});

  final String text;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(width: 8),
          Text(caption!, style: Theme.of(context).textTheme.labelLarge),
        ],
      ],
    );
  }
}

/// Matriz editable. [errors] son las celdas (fila, columna) a marcar en rojo.
class MatrixEditor extends StatelessWidget {
  const MatrixEditor({
    super.key,
    required this.fields,
    this.errors = const {},
    this.label,
  });

  final MatrixFields fields;
  final Set<(int, int)> errors;
  final Widget? label;

  /// Ancho que ocupa una matriz de [cols] columnas (celdas, huecos y
  /// corchetes), para decidir si A y B entran lado a lado.
  static double widthFor(int cols) => cols * cellWidth + (cols - 1) * _gap + 24;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[label!, const SizedBox(height: 10)],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: MatrixBrackets(
            // A completa antes de pasar a B con "Siguiente".
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = 0; r < fields.rows; r++)
                    Padding(
                      padding: EdgeInsets.only(top: r == 0 ? 0 : _gap),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var c = 0; c < fields.cols; c++)
                            Padding(
                              padding: EdgeInsets.only(left: c == 0 ? 0 : _gap),
                              child: _Cell(
                                controller: fields.cell(r, c),
                                focusNode: fields.focus(r, c),
                                error: errors.contains((r, c)),
                                hint:
                                    '${fields.name.toLowerCase()}${r + 1}${c + 1}',
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.hint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool error;
  final String hint;

  static final _allowed = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9.,/\-−]'),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );
    return SizedBox(
      width: cellWidth,
      height: cellHeight,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        ),
        textInputAction: TextInputAction.next,
        inputFormatters: [_allowed, LengthLimitingTextInputFormatter(14)],
        style: const TextStyle(
          fontSize: 17,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12, color: scheme.outline),
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: error
              ? scheme.errorContainer
              : scheme.surfaceContainerHighest,
          enabledBorder: border(error ? scheme.error : Colors.transparent),
          focusedBorder: border(error ? scheme.error : scheme.primary, 2),
        ),
      ),
    );
  }
}

/// Matriz de solo lectura (resultado, historial).
class MatrixView extends StatelessWidget {
  const MatrixView({
    super.key,
    required this.values,
    this.dense = false,
    this.highlight = false,
  });

  final List<List<String>> values;
  final bool dense;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style =
        (dense
                ? Theme.of(context).textTheme.bodySmall
                : Theme.of(context).textTheme.titleLarge)!
            .copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: highlight ? FontWeight.w600 : null,
              color: highlight ? scheme.primary : null,
            );
    return MatrixBrackets(
      color: highlight ? scheme.primary : null,
      child: Table(
        defaultColumnWidth: IntrinsicColumnWidth(),
        children: [
          for (final row in values)
            TableRow(
              children: [
                for (final v in row)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: dense ? 6 : 16,
                      vertical: dense ? 2 : 10,
                    ),
                    child: Text(v, style: style, textAlign: TextAlign.center),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
