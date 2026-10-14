import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/matrix_math.dart';
import '../calculator/matrix_fields.dart';
import '../calculator/matrix_widgets.dart';
import 'ocr_service.dart';

/// Muestra lo que se leyó de la foto para corregirlo antes de usarlo.
class OcrReviewPage extends StatefulWidget {
  const OcrReviewPage({super.key, required this.image, required this.result});

  final Uint8List image;
  final OcrResult result;

  @override
  State<OcrReviewPage> createState() => _OcrReviewPageState();
}

class _OcrReviewPageState extends State<OcrReviewPage> {
  late final List<MatrixFields> _fields = [
    for (final (i, m) in widget.result.matrices.take(2).indexed)
      MatrixFields(widget.result.matrices.length == 2 ? 'AB'[i] : 'M', 0, 0)
        ..setValues(m)
        ..addListener(_changed),
  ];
  late MatrixOp _op = widget.result.operation ?? MatrixOp.add;

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  int get _emptyCells => _fields.fold(
    0,
    (n, f) => n + f.values.expand((r) => r).where((v) => v.isEmpty).length,
  );

  void _use({OcrGrid? a, OcrGrid? b}) => Navigator.pop(
    context,
    OcrSelection(a: a, b: b, operation: _fields.length == 2 ? _op : null),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final two = _fields.length == 2;
    final sizeMismatch =
        two &&
        (_fields[0].rows != _fields[1].rows ||
            _fields[0].cols != _fields[1].cols);
    return Scaffold(
      appBar: AppBar(title: const Text('Revisa lo que leí')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Image.memory(widget.image, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                two
                    ? 'Encontré dos matrices. Corrige cualquier número mal leído.'
                    : 'Encontré una matriz. Corrige cualquier número mal leído.',
                style: text.bodyLarge,
              ),
              if (_emptyCells > 0) ...[
                const SizedBox(height: 8),
                _Notice(
                  icon: Icons.edit_note_rounded,
                  text: _emptyCells == 1
                      ? 'Hay 1 celda que no pude leer: complétala.'
                      : 'Hay $_emptyCells celdas que no pude leer: complétalas.',
                ),
              ],
              if (sizeMismatch) ...[
                const SizedBox(height: 8),
                const _Notice(
                  icon: Icons.warning_amber_rounded,
                  text:
                      'Las matrices tienen distinto tamaño. Se usará el de A; '
                      'revisa B en la calculadora.',
                ),
              ],
              const SizedBox(height: 16),
              for (final (i, f) in _fields.indexed) ...[
                if (i == 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SegmentedButton<MatrixOp>(
                        segments: [
                          for (final op in MatrixOp.values)
                            ButtonSegment(
                              value: op,
                              label: Text('${op.symbol}  ${op.label}'),
                            ),
                        ],
                        selected: {_op},
                        onSelectionChanged: (s) =>
                            setState(() => _op = s.first),
                      ),
                    ),
                  ),
                Center(
                  child: MatrixEditor(
                    fields: f,
                    label: MatrixLabel(
                      two ? f.name : '?',
                      caption: '${f.rows}×${f.cols}',
                    ),
                    errors: {
                      for (var r = 0; r < f.rows; r++)
                        for (var c = 0; c < f.cols; c++)
                          if (f.cell(r, c).text.trim().isEmpty) (r, c),
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (two)
                FilledButton.icon(
                  onPressed: () =>
                      _use(a: _fields[0].values, b: _fields[1].values),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Usar como A y B'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _use(a: _fields[0].values),
                        child: const Text('Usar como A'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => _use(b: _fields[0].values),
                        child: const Text('Usar como B'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
