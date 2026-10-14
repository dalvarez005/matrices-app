import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../core/api_client.dart';
import '../../core/feedback.dart';
import '../../core/session.dart';
import '../auth/login_sheet.dart';
import '../calculator/matrix_widgets.dart';
import 'history_repository.dart';

/// Operaciones guardadas del usuario. Tocar una la abre en la calculadora
/// (se devuelve el [HistoryItem] con Navigator.pop).
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _repo = Services.instance.history;
  final _items = <HistoryItem>[];
  int? _nextBefore;
  var _loading = false;
  var _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (Services.instance.session.signedIn) _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repo.page(before: reset ? null : _nextBefore);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.items);
        _nextBefore = page.nextBefore;
        _loaded = true;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(HistoryItem item) async {
    final index = _items.indexOf(item);
    setState(() => _items.remove(item));
    try {
      await _repo.delete(item.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _items.insert(index, item));
      showToast(context, e.message, error: true);
    }
  }

  Future<void> _clear() async {
    final ok = await confirm(
      context,
      title: '¿Borrar todo el historial?',
      message: 'Se eliminarán todas tus operaciones guardadas.',
      action: 'Borrar todo',
    );
    if (!ok) return;
    try {
      await _repo.clear();
      if (mounted) setState(_items.clear);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          if (session.signedIn && _items.isNotEmpty)
            IconButton(
              tooltip: 'Borrar todo',
              onPressed: _clear,
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: !session.signedIn ? _signedOut(context) : _body(context),
        ),
      ),
    );
  }

  Widget _signedOut(BuildContext context) => _EmptyState(
    icon: Icons.lock_outline_rounded,
    title: 'Inicia sesión para ver tu historial',
    message: 'Tus operaciones se guardan en tu cuenta y las ves en cualquier dispositivo.',
    action: FilledButton(
      onPressed: () async {
        if (await showLoginSheet(context)) _load(reset: true);
      },
      child: const Text('Iniciar sesión'),
    ),
  );

  Widget _body(BuildContext context) {
    if (!_loaded) {
      return _error != null
          ? _EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'No se pudo cargar',
              message: _error!,
              action: FilledButton(
                onPressed: () => _load(reset: true),
                child: const Text('Reintentar'),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const _EmptyState(
        icon: Icons.grid_on_rounded,
        title: 'Aún no hay operaciones',
        message: 'Cada suma o resta que calcules aparecerá aquí.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (_nextBefore != null && n.metrics.extentAfter < 400) _load();
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length + (_nextBefore != null ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == _items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final item = _items[i];
            return Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_rounded),
              ),
              onDismissed: (_) => _delete(item),
              child: _HistoryCard(
                item: item,
                onOpen: () => Navigator.pop(context, item),
                onDelete: () => _delete(item),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.onOpen,
    required this.onDelete,
  });

  final HistoryItem item;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final size = '${item.a.length}×${item.a.first.length}';
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    item.source == 'image'
                        ? Icons.photo_camera_rounded
                        : Icons.edit_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${item.operation.label} $size · ${_date(item.createdAt)}',
                      style: text.labelLarge,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) => v == 'open' ? onOpen() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'open',
                        child: Text('Abrir en calculadora'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    MatrixView(values: item.a, dense: true),
                    _Symbol(item.operation.symbol),
                    MatrixView(values: item.b, dense: true),
                    const _Symbol('='),
                    MatrixView(
                      values: item.result,
                      dense: true,
                      highlight: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime d) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(d.hour)}:${two(d.minute)}';
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'hoy $time';
    }
    return '${two(d.day)}/${two(d.month)}/${d.year} $time';
  }
}

class _Symbol extends StatelessWidget {
  const _Symbol(this.symbol);

  final String symbol;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(symbol, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
