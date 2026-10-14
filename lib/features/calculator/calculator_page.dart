import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/services.dart';
import '../../app/theme_controller.dart';
import '../../core/api_client.dart';
import '../../core/feedback.dart';
import '../../core/matrix_math.dart';
import '../../core/session.dart';
import '../auth/account_button.dart';
import '../history/history_page.dart';
import '../history/history_repository.dart';
import '../ocr/ocr_review_page.dart';
import '../ocr/ocr_service.dart';
import 'matrix_fields.dart';
import 'matrix_widgets.dart';

const _maxSize = 10;

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  var _rows = 2;
  var _cols = 2;
  var _op = MatrixOp.add;

  late final _a = MatrixFields('A', _rows, _cols, onFocus: _onCellFocus);
  late final _b = MatrixFields('B', _rows, _cols, onFocus: _onCellFocus);

  /// Celda con foco, para la barra de signo / fracción sobre el teclado.
  TextEditingController? _focusedCell;
  FocusNode? _focusedNode;

  MatrixResult? _result;
  Set<CellError> _errors = {};
  var _showSteps = false;

  /// Los valores vienen de una foto (se guarda así en el historial).
  var _fromImage = false;
  var _reading = false;

  final _resultKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _a.addListener(_edited);
    _b.addListener(_edited);
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _onCellFocus(TextEditingController cell, FocusNode node) => setState(() {
    _focusedCell = cell;
    _focusedNode = node;
  });

  /// Al editar, el resultado anterior ya no corresponde.
  void _edited() {
    if (_result == null && _errors.isEmpty) return;
    setState(() {
      _result = null;
      _errors = {};
    });
  }

  void _resize(int rows, int cols) {
    setState(() {
      _rows = rows.clamp(1, _maxSize);
      _cols = cols.clamp(1, _maxSize);
      _a.resize(_rows, _cols);
      _b.resize(_rows, _cols);
      _result = null;
      _errors = {};
    });
  }

  void _clear() {
    _a.clear();
    _b.clear();
    setState(() {
      _result = null;
      _errors = {};
      _fromImage = false;
    });
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    final a = _a.values, b = _b.values;
    final result = calculate(_op, a, b);
    if (!result.ok) {
      setState(() {
        _errors = result.errors;
        _result = null;
      });
      final onlyEmpty = result.errors.every(
        (e) => (e.matrix == 'A' ? a : b)[e.row][e.col].isEmpty,
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              onlyEmpty
                  ? 'Hay celdas vacías (marcadas en rojo).'
                  : 'Revisa las celdas en rojo: no son números válidos.',
            ),
            action: onlyEmpty
                ? SnackBarAction(
                    label: 'Usar 0',
                    onPressed: () {
                      _a.fillEmpty('0');
                      _b.fillEmpty('0');
                      _calculate();
                    },
                  )
                : null,
          ),
        );
      return;
    }
    setState(() {
      _result = result;
      _errors = {};
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _resultKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
    _save(a, b);
  }

  Future<void> _save(Grid a, Grid b) async {
    if (!Services.instance.session.signedIn) return;
    try {
      await Services.instance.history.save(_op, a, b, fromImage: _fromImage);
    } on ApiException catch (e) {
      if (mounted) {
        showToast(
          context,
          'No se guardó en el historial: ${e.message}',
          error: true,
        );
      }
    }
  }

  // ------------------------------------------------------------- Foto

  Future<void> _fromPhoto() async {
    final source = await _pickSource();
    if (source == null) return;
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 85,
      );
    } on PlatformException {
      if (mounted) {
        showToast(
          context,
          'Sin permiso para usar la cámara o las fotos.',
          error: true,
        );
      }
      return;
    }
    if (file == null || !mounted) return;

    setState(() => _reading = true);
    final bytes = await file.readAsBytes();
    OcrResult result;
    try {
      result = await Services.instance.ocr.read(bytes, file.name);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
      return;
    } finally {
      if (mounted) setState(() => _reading = false);
    }
    if (!mounted) return;

    final selection = await Navigator.push<OcrSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => OcrReviewPage(image: bytes, result: result),
      ),
    );
    if (selection == null) return;
    _apply(selection.a, selection.b, selection.operation);
    _fromImage = true;
  }

  Future<ImageSource?> _pickSource() => showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Toma la foto de frente, con buena luz y solo las matrices. '
              'Después podrás corregir lo leído.',
              textAlign: TextAlign.center,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: Text(kIsWeb ? 'Elegir imagen' : 'Elegir de la galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  /// Carga valores (de una foto o del historial). El tamaño lo manda A, o
  /// B si solo llega B.
  void _apply(List<List<String?>>? a, List<List<String?>>? b, MatrixOp? op) {
    final sizer = a ?? b!;
    _resize(sizer.length, sizer.first.length);
    if (a != null) _a.fillFrom(a);
    if (b != null) _b.fillFrom(b);
    setState(() {
      if (op != null) _op = op;
      _result = null;
      _errors = {};
      _fromImage = false;
    });
  }

  Future<void> _openHistory() async {
    final item = await Navigator.push<HistoryItem>(
      context,
      MaterialPageRoute(builder: (_) => const HistoryPage()),
    );
    if (item == null) return;
    _apply(item.a, item.b, item.operation);
    // Se muestra el resultado sin volver a guardarlo.
    setState(() => _result = calculate(_op, _a.values, _b.values));
  }

  void _useResultAsA() {
    final result = _result;
    if (result == null) return;
    _a.fillFrom(result.values);
    _b.clear();
    setState(() {
      _result = null;
      _fromImage = false;
    });
    showToast(context, 'El resultado ahora es A. Escribe la nueva B.');
  }

  // --------------------------------------------------- Barra de teclado

  void _toggleSign() {
    final cell = _focusedCell;
    if (cell == null) return;
    final text = cell.text;
    cell.text = text.startsWith('-') ? text.substring(1) : '-$text';
    cell.selection = TextSelection.collapsed(offset: cell.text.length);
  }

  void _insert(String s) {
    final cell = _focusedCell;
    if (cell == null) return;
    final sel = cell.selection.isValid
        ? cell.selection
        : TextSelection.collapsed(offset: cell.text.length);
    cell.value = TextEditingValue(
      text: cell.text.replaceRange(sel.start, sel.end, s),
      selection: TextSelection.collapsed(offset: sel.start + s.length),
    );
  }

  // ------------------------------------------------------------- UI

  /// PC y tablet horizontal: calculadora a la izquierda, resultado a la
  /// derecha. Teléfono: todo en una columna.
  static const _wideBreakpoint = 1000.0;

  @override
  Widget build(BuildContext context) {
    SessionScope.of(context); // se redibuja al entrar o salir
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= _wideBreakpoint;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final anyCellFocused = _focusedNode?.hasFocus ?? false;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/icon/icon.png', width: 32, height: 32),
            ),
            const SizedBox(width: 12),
            const Text(
              'Matrices',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          if (wide)
            TextButton.icon(
              onPressed: _openHistory,
              icon: const Icon(Icons.history_rounded),
              label: const Text('Historial'),
            )
          else
            IconButton(
              tooltip: 'Historial',
              onPressed: _openHistory,
              icon: const Icon(Icons.history_rounded),
            ),
          ThemeButton(controller: Services.instance.theme),
          const AccountButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  wide ? 32 : 16,
                  wide ? 24 : 8,
                  wide ? 32 : 16,
                  32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1280 : 640),
                    child: wide ? _wideLayout(context) : _narrowLayout(context),
                  ),
                ),
              ),
            ),
          ),
          if (keyboardOpen && anyCellFocused) _keyboardBar(context),
        ],
      ),
    );
  }

  Widget _narrowLayout(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _controls(context),
      const SizedBox(height: 16),
      _matrices(context),
      const SizedBox(height: 20),
      _actions(context),
      if (_result != null) ...[
        const SizedBox(height: 24),
        KeyedSubtree(key: _resultKey, child: _resultCard(context)),
      ],
    ],
  );

  Widget _wideLayout(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Suma y resta de matrices', style: text.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Escribe los valores, cárgalos desde una foto o abre una operación del historial.',
          style: text.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _controls(context),
                      const SizedBox(height: 24),
                      _matrices(context),
                      const SizedBox(height: 24),
                      _actions(context),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _result != null
                  ? _resultCard(context)
                  : _resultPlaceholder(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resultPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget tip(IconData icon, String label) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: text.bodyMedium)),
        ],
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MatrixLabel('R'),
                const SizedBox(width: 12),
                Text('Resultado', style: text.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Aparecerá aquí al tocar Calcular.',
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Divider(height: 32),
            Text('Consejos', style: text.titleSmall),
            tip(
              Icons.keyboard_tab_rounded,
              'Tab o Enter pasa a la siguiente celda.',
            ),
            tip(
              Icons.percent_rounded,
              'Acepta decimales (2.5 o 2,5) y fracciones (3/4).',
            ),
            tip(
              Icons.photo_camera_rounded,
              'Desde foto lee una o dos matrices; luego puedes corregirlas.',
            ),
            tip(
              Icons.cloud_done_rounded,
              Services.instance.session.signedIn
                  ? 'Cada cálculo se guarda en tu historial.'
                  : 'Inicia sesión para guardar tu historial.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 12,
      children: [
        _Stepper(
          label: 'Filas',
          value: _rows,
          onChanged: (v) => _resize(v, _cols),
        ),
        _Stepper(
          label: 'Columnas',
          value: _cols,
          onChanged: (v) => _resize(_rows, v),
        ),
        SegmentedButton<MatrixOp>(
          showSelectedIcon: false,
          segments: [
            for (final op in MatrixOp.values)
              ButtonSegment(
                value: op,
                label: Text(
                  '${op.symbol}  ${op.label}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
          ],
          selected: {_op},
          onSelectionChanged: (s) => setState(() {
            _op = s.first;
            _result = null;
          }),
        ),
      ],
    );
  }

  Set<(int, int)> _errorsOf(String matrix) => {
    for (final e in _errors)
      if (e.matrix == matrix) (e.row, e.col),
  };

  /// A y B lado a lado si caben; si no (teléfono o matrices grandes), una
  /// debajo de la otra.
  Widget _matrices(BuildContext context) {
    final symbol = Text(
      _op.symbol,
      style: Theme.of(context).textTheme.displaySmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    );
    final a = MatrixEditor(
      fields: _a,
      errors: _errorsOf('A'),
      label: const MatrixLabel('A'),
    );
    final b = MatrixEditor(
      fields: _b,
      errors: _errorsOf('B'),
      label: const MatrixLabel('B'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final matrixWidth = MatrixEditor.widthFor(_cols);
        final sideBySide = constraints.maxWidth >= matrixWidth * 2 + 80;
        if (sideBySide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              a,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: symbol,
              ),
              b,
            ],
          );
        }
        return Column(
          children: [
            a,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: symbol,
            ),
            b,
          ],
        );
      },
    );
  }

  Widget _actions(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _calculate,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              icon: const Icon(Icons.calculate_rounded),
              label: Text(
                'Calcular A ${_op.symbol} B',
                style: const TextStyle(fontSize: 17),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reading ? null : _fromPhoto,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: _reading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_rounded),
                    label: Text(_reading ? 'Leyendo…' : 'Desde foto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clear,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.backspace_outlined),
                    label: const Text('Limpiar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(BuildContext context) {
    final result = _result!;
    final text = Theme.of(context).textTheme;
    final a = _a.values, b = _b.values;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const MatrixLabel('R'),
                const SizedBox(width: 12),
                Text('Resultado', style: text.titleLarge),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'A ${_op.symbol} B',
                    style: text.labelLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: MatrixView(values: result.values, highlight: true),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _showSteps = !_showSteps),
                  icon: Icon(
                    _showSteps
                        ? Icons.expand_less_rounded
                        : Icons.list_alt_rounded,
                  ),
                  label: Text(_showSteps ? 'Ocultar pasos' : 'Ver paso a paso'),
                ),
                TextButton.icon(
                  onPressed: _useResultAsA,
                  icon: const Icon(Icons.redo_rounded),
                  label: const Text('Usar como A'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: result.values.map((r) => r.join('\t')).join('\n'),
                      ),
                    );
                    showToast(context, 'Resultado copiado.');
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar'),
                ),
              ],
            ),
            if (_showSteps) ...[
              const Divider(height: 24),
              Text(
                'Se ${_op == MatrixOp.add ? 'suma' : 'resta'} cada celda de B '
                '${_op == MatrixOp.add ? 'a' : 'de'} la celda en la misma posición de A:',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 8),
              for (var r = 0; r < a.length; r++)
                for (var c = 0; c < a[r].length; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'r${r + 1}${c + 1} = ',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          TextSpan(
                            text:
                                '${_paren(a[r][c])} ${_op.symbol} ${_paren(b[r][c])} = ',
                          ),
                          TextSpan(
                            text: result.values[r][c],
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      style: text.bodyLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  /// Negativos entre paréntesis en los pasos: 3 − (−2).
  static String _paren(String v) => v.startsWith('-') ? '($v)' : v;

  Widget _keyboardBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget key(String label, VoidCallback onTap, {String? tooltip}) => Expanded(
      child: Tooltip(
        message: tooltip ?? label,
        child: TextButton(
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              key('±', _toggleSign, tooltip: 'Cambiar signo'),
              key('/', () => _insert('/'), tooltip: 'Fracción'),
              key('.', () => _insert('.'), tooltip: 'Decimal'),
              key(
                '→',
                () => FocusScope.of(context).nextFocus(),
                tooltip: 'Siguiente',
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => FocusScope.of(context).unfocus(),
                  child: const Text('Listo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Filas  [−] 2 [+]".
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Menos',
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 20,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Más',
            onPressed: value < _maxSize ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
