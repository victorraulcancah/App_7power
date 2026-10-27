import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appecommerce/core/utils/format_utils.dart';
import 'package:appecommerce/presentation/components/components.dart';
import 'package:appecommerce/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  test('FormatUtils formatea soles y convierte strings', () {
    expect(FormatUtils.money(1234.5), contains('1,234.50'));
    expect(FormatUtils.toDouble('12.5'), 12.5);
    expect(FormatUtils.toDouble(null), 0);
  });

  testWidgets('AppButton muestra spinner y no responde cuando carga',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(AppButton(
      label: 'Comprar',
      isLoading: true,
      onPressed: () => taps++,
    )));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 0);
  });

  testWidgets('QuantitySelector respeta mínimo y máximo', (tester) async {
    var value = 1;
    await tester.pumpWidget(_wrap(StatefulBuilder(
      builder: (context, setState) => QuantitySelector(
        value: value,
        max: 2,
        onChanged: (v) => setState(() => value = v),
      ),
    )));

    await tester.tap(find.byIcon(Icons.remove));
    expect(value, 1);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(value, 2);
    await tester.tap(find.byIcon(Icons.add));
    expect(value, 2);
  });

  testWidgets('AppSearchField notifica tras el debounce', (tester) async {
    final searches = <String>[];
    await tester.pumpWidget(_wrap(AppSearchField(onSearch: searches.add)));

    await tester.enterText(find.byType(TextField), 'taladro');
    expect(searches, isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    expect(searches, ['taladro']);
  });

  testWidgets('ProductCard muestra datos, agotado y acción de carrito',
      (tester) async {
    var added = 0;
    await tester.pumpWidget(_wrap(SizedBox(
      width: 200,
      height: 330,
      child: ProductCard(
        name: 'Taladro percutor',
        brand: 'Bosch',
        price: 199.9,
        oldPrice: 249.9,
        stock: 25,
        onAddToCart: () => added++,
      ),
    )));

    expect(find.text('Taladro percutor'), findsOneWidget);
    expect(find.text('BOSCH'), findsOneWidget);
    expect(find.text('Agotado'), findsNothing);
    await tester.tap(find.byIcon(Icons.add_shopping_cart));
    expect(added, 1);
  });

  testWidgets('ErrorState ofrece reintentar', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
        _wrap(ErrorState(message: 'Sin conexión', onRetry: () => retries++)));

    await tester.tap(find.text('Reintentar'));
    expect(retries, 1);
  });
}
