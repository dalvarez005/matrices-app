import '../core/api_client.dart';
import 'theme_controller.dart';
import '../core/session.dart';
import '../features/history/history_repository.dart';
import '../features/ocr/ocr_service.dart';

/// Servicios de la app, creados una vez en main().
class Services {
  Services._(this.api, this.session, this.history, this.ocr);

  factory Services(ApiClient api) => Services._(
    api,
    Session(api: api),
    HistoryRepository(api),
    OcrService(api),
  );

  static late Services instance;

  final ApiClient api;
  final Session session;
  final HistoryRepository history;
  final OcrService ocr;

  /// Se asigna en main() antes de arrancar la app.
  late final ThemeController theme;
}
