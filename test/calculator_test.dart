import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrices/app/services.dart';
import 'package:matrices/app/theme_controller.dart';
import 'package:matrices/core/api_client.dart';
import 'package:matrices/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('suma 2x2 sin cuenta', (tester) async {
    final services = Services.instance = Services(
      ApiClient(baseUrl: 'http://test'),
    );
    SharedPreferences.setMockInitialValues({});
    services.theme = await ThemeController.load();
    await tester.pumpWidget(
      MatricesApp(session: services.session, theme: services.theme),
    );

    final cells = find.byType(TextField);
    expect(cells, findsNWidgets(8));
    for (final (i, v) in [
      '1',
      '2',
      '3',
      '4',
      '10',
      '20',
      '30',
      '0.5',
    ].indexed) {
      await tester.enterText(cells.at(i), v);
    }
    await tester.tap(find.text('Calcular A + B'));
    await tester.pumpAndSettle();

    for (final v in ['11', '22', '33', '4.5']) {
      expect(find.text(v), findsOneWidget);
    }
  });

  testWidgets('cambia a 3 columnas y marca celdas vacías', (tester) async {
    final services = Services.instance = Services(
      ApiClient(baseUrl: 'http://test'),
    );
    SharedPreferences.setMockInitialValues({});
    services.theme = await ThemeController.load();
    await tester.pumpWidget(
      MatricesApp(session: services.session, theme: services.theme),
    );

    await tester.tap(find.byTooltip('Más').last);
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(12));

    await tester.tap(find.text('Calcular A + B'));
    await tester.pumpAndSettle();
    expect(find.text('Hay celdas vacías (marcadas en rojo).'), findsOneWidget);
    await tester.tap(find.text('Usar 0'));
    await tester.pumpAndSettle();
    expect(find.text('Resultado'), findsOneWidget);
  });
}
