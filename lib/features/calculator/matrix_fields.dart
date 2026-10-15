import 'package:flutter/widgets.dart';

import '../../core/matrix_math.dart';

/// Celdas editables de una matriz: un controlador y un foco por celda.
/// Al cambiar el tamaño se conservan los valores que siguen entrando.
class MatrixFields {
  MatrixFields(this.name, int rows, int cols, {this.onFocus}) {
    resize(rows, cols);
  }

  /// 'A', 'B', 'C'… (cambia si se quita una matriz anterior).
  String name;

  /// Se llama cuando una celda gana el foco.
  final void Function(TextEditingController cell, FocusNode node)? onFocus;

  final _cells = <List<TextEditingController>>[];
  final _focus = <List<FocusNode>>[];

  int get rows => _cells.length;
  int get cols => _cells.isEmpty ? 0 : _cells.first.length;

  TextEditingController cell(int r, int c) => _cells[r][c];
  FocusNode focus(int r, int c) => _focus[r][c];

  Grid get values => [
    for (final row in _cells) [for (final c in row) c.text.trim()],
  ];

  bool get isEmpty =>
      _cells.every((r) => r.every((c) => c.text.trim().isEmpty));

  void resize(int rows, int cols) {
    while (_cells.length > rows) {
      _disposeRow(_cells.removeLast(), _focus.removeLast());
    }
    for (var r = 0; r < _cells.length; r++) {
      while (_cells[r].length > cols) {
        _cells[r].removeLast().dispose();
        _focus[r].removeLast().dispose();
      }
      while (_cells[r].length < cols) {
        _add(r);
      }
    }
    while (_cells.length < rows) {
      _cells.add([]);
      _focus.add([]);
      for (var c = 0; c < cols; c++) {
        _add(_cells.length - 1);
      }
    }
  }

  /// Llena con [grid] (null = celda que no se pudo leer), cambiando el tamaño.
  void setValues(List<List<String?>> grid) {
    resize(grid.length, grid.isEmpty ? 0 : grid.first.length);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        _cells[r][c].text = c < grid[r].length ? grid[r][c] ?? '' : '';
      }
    }
  }

  /// Copia valores sin cambiar el tamaño (lo que no entra se descarta).
  void fillFrom(List<List<String?>> grid) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final inside = r < grid.length && c < grid[r].length;
        _cells[r][c].text = inside ? grid[r][c] ?? '' : '';
      }
    }
  }

  void fillEmpty(String value) {
    for (final row in _cells) {
      for (final c in row) {
        if (c.text.trim().isEmpty) c.text = value;
      }
    }
  }

  void clear() {
    for (final row in _cells) {
      for (final c in row) {
        c.clear();
      }
    }
  }

  void addListener(VoidCallback listener) {
    _listener = listener;
    for (final row in _cells) {
      for (final c in row) {
        c.addListener(listener);
      }
    }
  }

  VoidCallback? _listener;

  void _add(int r) {
    final controller = TextEditingController();
    if (_listener != null) controller.addListener(_listener!);
    final node = FocusNode();
    node.addListener(() {
      if (node.hasFocus) onFocus?.call(controller, node);
    });
    _cells[r].add(controller);
    _focus[r].add(node);
  }

  void _disposeRow(List<TextEditingController> cells, List<FocusNode> nodes) {
    for (final c in cells) {
      c.dispose();
    }
    for (final n in nodes) {
      n.dispose();
    }
  }

  void dispose() {
    for (var r = 0; r < _cells.length; r++) {
      _disposeRow(_cells[r], _focus[r]);
    }
    _cells.clear();
    _focus.clear();
  }
}
