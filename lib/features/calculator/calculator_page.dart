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

  /// Simple: A ± B. Compuesta: tres o más matrices, cada una con su operador.
  var _compound = false;

  /// Todas las matrices creadas. En modo simple se usan las dos primeras y
  /// las demás se conservan por si se vuelve a compuesta.
  final _fields = <MatrixFields>[];

  /// Operador antes de cada matriz desde B: `_ops[i]` va entre la matriz i e
  /// i + 1.
  final _ops = <MatrixOp>[];

  /// Matrices quitadas (para "Deshacer"); se liberan al cerrar la página.
  final _removed = <MatrixFields>[];

  /// Celda con foco, para la barra de signo / fracción sobre el teclado.
  TextEditingController? _focusedCell;
  FocusNode? _focusedNode;

  MatrixResult? _result;

  /// La expresión tal como se calculó (para el paso a paso).
  List<Grid> _calcMatrices = const [];
  List<MatrixOp> _calcOps = const [];
  Set<CellError> _errors = {};
  var _showSteps = false;

  /// Los valores vienen de una foto (se guarda así en el historial).
  var _fromImage = false;
  var _reading = false;

  final _resultKey = GlobalKey();

  int get _count => _compound ? _fields.length : 2;
  List<MatrixFields> get _active => _fields.sublist(0, _count);
  List<MatrixOp> get _activeOps => _ops.sublist(0, _count - 1);

  @override
  void initState() {
    super.initState();
    _addFields();
    _addFields();
  }

  @override
  void dispose() {
    for (final f in [..._fields, ..._removed]) {
      f.dispose();
    }
    super.dispose();
  }

  void _addFields() {
    final f = MatrixFields(
      matrixName(_fields.length),
      _rows,
      _cols,
      onFocus: _onCellFocus,
    )..addListener(_edited);
    if (_fields.isNotEmpty) _ops.add(MatrixOp.add);
    _fields.add(f);
  }

  void _onCellFocus(TextEditingController cell, FocusNode node) => setState(() {
    _focusedCell = cell;
    _focusedNode = node;
  });

  /// Al editar, el resultado anterior ya no corresponde.
  void _edited() {
    if (_result == null && _errors.isEmpty) return;
    _invalidate();
  }

  void _invalidate() => setState(() {
    _result = null;
    _errors = {};
  });

  void _resize(int rows, int cols) {
    setState(() {
      _rows = rows.clamp(1, _maxSize);
      _cols = cols.clamp(1, _maxSize);
      for (final f in _fields) {
        f.resize(_rows, _cols);
      }
      _result = null;
      _errors = {};
    });
  }

  void _setCompound(bool compound) {
    setState(() {
      _compound = compound;
      while (compound && _fields.length < 3) {
        _addFields();
      }
      _result = null;
      _errors = {};
    });
  }

  void _addMatrix() {
    if (_fields.length >= maxMatrices) return;
    setState(() {
      _addFields();
      _result = null;
      _errors = {};
    });
  }

  /// Quita la matriz [index]. Si era A, la siguiente pasa a ser A y pierde su
  /// operador.
  void _removeMatrix(int index) {
    if (_fields.length <= 3) return;
    final removed = _fields[index];
    final op = _ops[index == 0 ? 0 : index - 1];
    setState(() {
      _fields.removeAt(index);
      _ops.removeAt(index == 0 ? 0 : index - 1);
      _rename();
      _result = null;
      _errors = {};
    });
    if (removed.isEmpty) {
      removed.dispose();
      return;
    }
    _removed.add(removed);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Se quitó la matriz ${removed.name}.'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () {
              if (!mounted || !_removed.remove(removed)) return;
              if (_fields.length >= maxMatrices) {
                removed.dispose();
                return;
              }
              final at = index.clamp(0, _fields.length);
              removed.resize(_rows, _cols);
              setState(() {
                _fields.insert(at, removed);
                _ops.insert(at == 0 ? 0 : at - 1, op);
                _rename();
                _result = null;
                _errors = {};
              });
            },
          ),
        ),
      );
  }

  void _rename() {
    for (final (i, f) in _fields.indexed) {
      f.name = matrixName(i);
    }
  }

  void _setOp(int index, MatrixOp op) {
    if (_ops[index] == op) return;
    setState(() {
      _ops[index] = op;
      _result = null;
      _errors = {};
    });
  }

  void _clear() {
    for (final f in _active) {
      f.clear();
    }
    setState(() {
      _result = null;
      _errors = {};
      _fromImage = false;
    });
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    final matrices = [for (final f in _active) f.values];
    final ops = List.of(_activeOps);
    final result = evaluate(matrices, ops);
    if (result.sizeError != null) {
      showToast(context, result.sizeError!, error: true);
      return;
    }
    if (!result.ok) {
      setState(() {
        _errors = result.errors;
        _result = null;
      });
      final onlyEmpty = result.errors.every(
        (e) => matrices[e.matrix.codeUnitAt(0) - 0x41][e.row][e.col].isEmpty,
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
                      for (final f in _active) {
                        f.fillEmpty('0');
                      }
                      _calculate();
                    },
                  )
                : null,
          ),
        );
      return;
    }
    _show(result, matrices, ops);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _resultKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
    _save(matrices, ops);
  }

  void _show(MatrixResult result, List<Grid> matrices, List<MatrixOp> ops) {
    setState(() {
      _result = result;
      _calcMatrices = matrices;
      _calcOps = ops;
      _errors = {};
    });
  }

  Future<void> _save(List<Grid> matrices, List<MatrixOp> ops) async {
    if (!Services.instance.session.signedIn) return;
    try {
      await Services.instance.history.save(
        matrices,
        ops,
        fromImage: _fromImage,
      );
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

  /// Carga valores de una foto en A y/o B (null = no se toca). El tamaño lo
  /// manda A, o B si solo llega B.
  void _apply(List<List<String?>>? a, List<List<String?>>? b, MatrixOp? op) {
    final sizer = a ?? b!;
    _resize(sizer.length, sizer.first.length);
    if (a != null) _fields[0].fillFrom(a);
    if (b != null) _fields[1].fillFrom(b);
    setState(() {
      if (op != null) _ops[0] = op;
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
    final first = item.matrices.first;
    _resize(first.length, first.first.length);
    setState(() {
      _compound = item.compound;
      while (_fields.length < item.matrices.length) {
        _addFields();
      }
      // En compuesta se usan exactamente las del historial.
      while (item.compound && _fields.length > item.matrices.length) {
        _fields.removeLast().dispose();
        _ops.removeLast();
      }
      for (final (i, m) in item.matrices.indexed) {
        _fields[i].fillFrom(m);
      }
      _ops.setRange(0, item.operators.length, item.operators);
      _fromImage = false;
    });
    // Se muestra el resultado sin volver a guardarlo.
    final matrices = [for (final f in _active) f.values];
    final result = evaluate(matrices, _activeOps);
    if (result.ok) _show(result, matrices, List.of(_activeOps));
  }

  void _useResultAsA() {
    final result = _result;
    if (result == null) return;
    _fields[0].fillFrom(result.values);
    for (final f in _active.skip(1)) {
      f.clear();
    }
    setState(() {
      _result = null;
      _fromImage = false;
    });
    showToast(
      context,
      _compound
          ? 'El resultado ahora es A. Escribe las demás matrices.'
          : 'El resultado ahora es A. Escribe la nueva B.',
    );
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
              'MatriCalc',
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
      if (_compound) ...[const SizedBox(height: 16), _expression(context)],
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
          'Opera dos matrices o combina varias en una sola expresión. '
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
                      if (_compound) ...[
                        const SizedBox(height: 20),
                        _expression(context),
                      ],
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
              Icons.functions_rounded,
              'En Compuesta combina hasta $maxMatrices matrices: toca un signo para cambiarlo.',
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
    return Column(
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.exposure_rounded),
              label: Text('Simple'),
              tooltip: 'Dos matrices: A + B o A − B',
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.functions_rounded),
              label: Text('Compuesta'),
              tooltip: 'Tres o más matrices con sumas y restas',
            ),
          ],
          selected: {_compound},
          onSelectionChanged: (s) => _setCompound(s.first),
        ),
        const SizedBox(height: 12),
        Wrap(
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
            if (_compound)
              _Stepper(
                label: 'Matrices',
                value: _fields.length,
                min: 3,
                max: maxMatrices,
                onChanged: (v) => v > _fields.length
                    ? _addMatrix()
                    : _removeMatrix(_fields.length - 1),
              )
            else
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
                selected: {_ops[0]},
                onSelectionChanged: (s) => _setOp(0, s.first),
              ),
          ],
        ),
      ],
    );
  }

  /// "R = A + B − C" con los signos tocables: la expresión completa antes de
  /// calcular.
  Widget _expression(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.titleLarge;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Expresión · toca un signo para cambiarlo',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: scheme.onSecondaryContainer),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('R =  ', style: style?.copyWith(color: scheme.outline)),
              for (var i = 0; i < _count; i++) ...[
                if (i > 0)
                  _OpButton(
                    op: _ops[i - 1],
                    onChanged: (op) => _setOp(i - 1, op),
                    dense: true,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    matrixName(i),
                    style: style?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Set<(int, int)> _errorsOf(String matrix) => {
    for (final e in _errors)
      if (e.matrix == matrix) (e.row, e.col),
  };

  /// Las matrices con su signo delante. Lado a lado si caben; si no
  /// (teléfono o matrices grandes), una debajo de la otra.
  Widget _matrices(BuildContext context) {
    Widget editor(int i) {
      final f = _fields[i];
      return MatrixEditor(
        key: ObjectKey(f),
        fields: f,
        errors: _errorsOf(f.name),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MatrixLabel(f.name),
            // Tab y Enter van de celda en celda, sin pasar por estos botones.
            if (_compound && _fields.length > 3)
              ExcludeFocusTraversal(
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Quitar ${f.name}',
                  onPressed: () => _removeMatrix(i),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
          ],
        ),
      );
    }

    Widget op(int i) =>
        _OpButton(op: _ops[i - 1], onChanged: (op) => _setOp(i - 1, op));

    final add = _compound
        ? Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              onPressed: _fields.length < maxMatrices ? _addMatrix : null,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                _fields.length < maxMatrices
                    ? 'Agregar matriz ${matrixName(_fields.length)}'
                    : 'Máximo $maxMatrices matrices',
              ),
            ),
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final matrixWidth = MatrixEditor.widthFor(_cols);
        final sideBySide = constraints.maxWidth >= matrixWidth * 2 + 80;
        if (sideBySide) {
          return Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.end,
            runSpacing: 20,
            children: [
              editor(0),
              for (var i = 1; i < _count; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(8, 0, 8, _rows * 27.0 - 24),
                      child: op(i),
                    ),
                    editor(i),
                  ],
                ),
              ?add,
            ],
          );
        }
        return Column(
          children: [
            editor(0),
            for (var i = 1; i < _count; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: op(i),
              ),
              editor(i),
            ],
            if (add != null) ...[const SizedBox(height: 8), add],
          ],
        );
      },
    );
  }

  Widget _actions(BuildContext context) {
    // Con muchas matrices la expresión ya se ve arriba.
    final label = _count <= 3
        ? 'Calcular ${expressionOf(_activeOps)}'
        : 'Calcular';
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
              label: Text(label, style: const TextStyle(fontSize: 17)),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        expressionOf(_calcOps),
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
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
              ..._steps(context, result),
            ],
          ],
        ),
      ),
    );
  }

  /// Compuesta: primero cada operación de izquierda a derecha con su
  /// resultado parcial; después el cálculo de cada celda.
  List<Widget> _steps(BuildContext context, MatrixResult result) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final matrices = _calcMatrices, ops = _calcOps;
    final first = matrices.first;
    final compound = ops.length > 1;
    String partialName(int k) => k == ops.length - 1 ? 'R' : 'P${k + 1}';
    return [
      if (!compound)
        Text(
          'Se ${ops[0] == MatrixOp.add ? 'suma' : 'resta'} cada celda de B '
          '${ops[0] == MatrixOp.add ? 'a' : 'de'} la celda en la misma posición de A:',
          style: text.bodyMedium,
        )
      else ...[
        Text(
          'Se resuelve de izquierda a derecha, una operación a la vez:',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 8),
        for (var k = 0; k < ops.length; k++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Paso ${k + 1}:  ${partialName(k)} = '
                  '${k == 0 ? 'A' : partialName(k - 1)} ${ops[k].symbol} ${matrixName(k + 1)}',
                  style: text.titleSmall,
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: MatrixView(
                    values: result.partials[k],
                    dense: true,
                    highlight: k == ops.length - 1,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text('Celda por celda:', style: text.bodyMedium),
      ],
      const SizedBox(height: 8),
      for (var r = 0; r < first.length; r++)
        for (var c = 0; c < first[r].length; c++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'r${r + 1}${c + 1} = ',
                    style: TextStyle(color: scheme.outline),
                  ),
                  TextSpan(
                    text: [
                      _paren(matrices[0][r][c]),
                      for (final (i, op) in ops.indexed)
                        '${op.symbol} ${_paren(matrices[i + 1][r][c])}',
                    ].join(' '),
                  ),
                  const TextSpan(text: ' = '),
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
    ];
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
    this.min = 1,
    this.max = _maxSize,
  });

  final String label;
  final int value;
  final int min;
  final int max;
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
            onPressed: value > min ? () => onChanged(value - 1) : null,
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
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

/// Signo entre dos matrices: al tocarlo cambia entre + y −.
class _OpButton extends StatelessWidget {
  const _OpButton({
    required this.op,
    required this.onChanged,
    this.dense = false,
  });

  final MatrixOp op;
  final ValueChanged<MatrixOp> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = dense ? 36.0 : 52.0;
    // Fuera del recorrido con Tab: así se pasa de una matriz a la siguiente.
    return ExcludeFocusTraversal(
      child: Tooltip(
        message: 'Cambiar a ${op.flipped.label.toLowerCase()}',
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: dense ? 2 : 0),
          child: Material(
            color: dense ? scheme.surface : scheme.primaryContainer,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(op.flipped),
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child: Text(
                    op.symbol,
                    style:
                        (dense
                                ? textTheme.titleLarge
                                : textTheme.headlineMedium)
                            ?.copyWith(
                              color: dense
                                  ? scheme.primary
                                  : scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
