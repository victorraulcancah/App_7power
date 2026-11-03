import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appecommerce/core/utils/format_utils.dart';
import 'package:appecommerce/core/utils/image_url.dart';
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

  group('ImageUrl.resized', () {
    const base = 'https://api.7power.pe';
    const foto = '$base/storage/productos/a.jpg';

    test('pide el ancho que alcanza para la densidad de la pantalla', () {
      // 160 px lógicos a 2.6x = 416 px → el de 480.
      expect(ImageUrl.resized(foto, 160, 2.6), '$base/api/img/480/productos/a.jpg');
      // Ancho completo (360 a 3x = 1080).
      expect(ImageUrl.resized(foto, 360, 3), '$base/api/img/1080/productos/a.jpg');
      expect(ImageUrl.resized(foto, 60, 1), '$base/api/img/160/productos/a.jpg');
    });

    test('nunca pide más del mayor ancho disponible', () {
      expect(ImageUrl.resized(foto, 900, 3), '$base/api/img/1080/productos/a.jpg');
    });

    test('deja igual lo que no es de storage o no tiene ancho', () {
      expect(ImageUrl.resized('https://otro.com/a.jpg', 160, 2), isNull);
      expect(ImageUrl.resized(foto, null, 2), isNull);
      expect(ImageUrl.resized(foto, double.infinity, 2), isNull);
    });
  });

  group('DataCard', () {
    testWidgets('muestra cabecera, filas dato/valor, contenido extra y pie',
        (tester) async {
      await tester.pumpWidget(_wrap(const DataCard(
        icon: Icons.receipt_long_outlined,
        badge: 'PD-0016',
        trailing: StatusTag(label: 'Pendiente', type: StatusTagType.warning),
        fields: [
          DataField('Cliente', 'G-GLADIS PUCHOC'),
          DataField('Fecha', '22/10/2026'),
        ],
        footerLabel: 'Total',
        footerValue: 'S/ 51.50',
        children: [Text('Contenido extra')],
      )));

      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      expect(find.text('PD-0016'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      for (final text in ['Cliente', 'G-GLADIS PUCHOC', 'Fecha', '22/10/2026']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Contenido extra'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('S/ 51.50'), findsOneWidget);
    });

    testWidgets('sin pie ni cabecera no dibuja separador ni espacio de más',
        (tester) async {
      await tester.pumpWidget(_wrap(const DataCard(
        fields: [DataField('Tipo', 'Reclamo')],
      )));

      expect(find.byType(Divider), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.text('Reclamo'), findsOneWidget);
    });

    testWidgets('un valor largo se recorta en las líneas pedidas', (tester) async {
      await tester.pumpWidget(_wrap(DataCard(
        fields: [DataField('Descripción', 'palabra ' * 80, maxLines: 2)],
      )));

      final text = tester.widget<Text>(find.textContaining('palabra').last);
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('con onTap responde al toque', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(DataCard(
        badge: 'REC-1',
        fields: const [DataField('Tipo', 'Queja')],
        onTap: () => taps++,
      )));

      await tester.tap(find.text('Queja'));

      expect(taps, 1);
    });
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

  testWidgets('BrandLogo usa el de la empresa y, si no hay o falla, el de la web',
      (tester) async {
    await tester.pumpWidget(_wrap(const BrandLogo()));
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    // Con URL se intenta cargar la imagen; en los tests la red responde 400,
    // así que termina mostrando el logo de respaldo.
    await tester.pumpWidget(_wrap(const BrandLogo(url: 'http://api.test/logo.png')));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ErrorState ofrece reintentar', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
        _wrap(ErrorState(message: 'Sin conexión', onRetry: () => retries++)));

    await tester.tap(find.text('Reintentar'));
    expect(retries, 1);
  });
}
