import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appecommerce/domain/entities/category_entity.dart';
import 'package:appecommerce/domain/entities/product_filters.dart';
import 'package:appecommerce/presentation/components/components.dart';
import 'package:appecommerce/theme/app_theme.dart';

List<CategoryEntity> _categories(int n) => [
      for (var i = 1; i <= n; i++) CategoryEntity(id: i, name: 'CATEGORIA $i'),
    ];

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.build(Colors.black),
      home: Scaffold(body: child),
    );

/// La posición actual del carril de categorías.
double _offset(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

void main() {
  group('CategoryCarousel', () {
    setUp(() => AutoScrollRow.autoScroll = true);
    tearDown(() => AutoScrollRow.autoScroll = false);

    testWidgets('avanza solo, sin que nadie lo toque', (tester) async {
      await tester.pumpWidget(_app(CategoryCarousel(
        categories: _categories(8),
        onTap: (_) {},
      )));

      final start = _offset(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Unos 26 px por segundo.
      expect(_offset(tester) - start, closeTo(26 * 2, 6));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no se acaba: después de la última vuelve a la primera',
        (tester) async {
      await tester.pumpWidget(_app(CategoryCarousel(
        categories: _categories(5),
        onTap: (_) {},
      )));

      // Más de lo que mide la lista (5 tarjetas): sigue habiendo tarjetas.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.byType(CategoryCard), findsWidgets);
      expect(_offset(tester), greaterThan(5 * (CategoryCard.width + 12)));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('se detiene al tocarlo y sigue pasados unos segundos',
        (tester) async {
      await tester.pumpWidget(_app(CategoryCarousel(
        categories: _categories(8),
        onTap: (_) {},
      )));
      await tester.pump(const Duration(seconds: 1));

      final gesture = await tester.startGesture(const Offset(200, 60));
      final held = _offset(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(_offset(tester), held, reason: 'quieto mientras se toca');

      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      expect(_offset(tester), held, reason: 'espera antes de seguir');

      await tester.pump(AutoScrollRow.resumeAfter);
      await tester.pump(const Duration(seconds: 1));
      expect(_offset(tester), greaterThan(held));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con pocas categorías no se mueve ni se repite', (tester) async {
      await tester.pumpWidget(_app(CategoryCarousel(
        categories: _categories(3),
        onTap: (_) {},
      )));

      await tester.pump(const Duration(seconds: 3));

      expect(_offset(tester), 0);
      expect(find.byType(CategoryCard), findsNWidgets(3));
    });

    testWidgets('tocar una tarjeta avisa cuál es', (tester) async {
      CategoryEntity? tapped;
      await tester.pumpWidget(_app(CategoryCarousel(
        categories: _categories(3),
        onTap: (c) => tapped = c,
      )));

      await tester.tap(find.text('Categoria 2'));

      expect(tapped?.id, 2);
    });

    testWidgets('con "reducir movimiento" en el sistema se queda quieto',
        (tester) async {
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(CategoryCarousel(
          categories: _categories(8),
          onTap: (_) {},
        )),
      ));

      await tester.pump(const Duration(seconds: 3));

      expect(_offset(tester), 0);
    });
  });

  group('BrandCarousel', () {
    List<BrandEntity> brands(int n) => [
          for (var i = 1; i <= n; i++)
            BrandEntity(id: i, name: 'MARCA $i', productsCount: i == 1 ? 1 : 40 + i),
        ];

    setUp(() => AutoScrollRow.autoScroll = true);
    tearDown(() => AutoScrollRow.autoScroll = false);

    testWidgets('avanza solo, más lento que las categorías', (tester) async {
      await tester.pumpWidget(_app(BrandCarousel(brands: brands(8), onTap: (_) {})));

      final start = _offset(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(_offset(tester) - start, closeTo(20 * 2, 6));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cada tarjeta muestra el nombre y cuántos productos tiene',
        (tester) async {
      await tester.pumpWidget(_app(BrandCarousel(brands: brands(3), onTap: (_) {})));

      expect(find.text('MARCA 1'), findsOneWidget);
      expect(find.text('1 producto'), findsOneWidget);
      expect(find.text('42 productos'), findsOneWidget);
    });

    testWidgets('tocar una marca avisa cuál es', (tester) async {
      BrandEntity? tapped;
      await tester.pumpWidget(
          _app(BrandCarousel(brands: brands(3), onTap: (b) => tapped = b)));

      await tester.tap(find.byKey(const Key('home-brand-2')));

      expect(tapped?.id, 2);
    });

    testWidgets('en las repeticiones del carril no hay claves duplicadas',
        (tester) async {
      await tester.pumpWidget(_app(BrandCarousel(brands: brands(5), onTap: (_) {})));

      // Se avanza hasta que se ven tarjetas repetidas: sin error de claves.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(tester.takeException(), isNull);
      expect(
        tester.widgetList(find.byKey(const Key('home-brand-1'))).length,
        lessThanOrEqualTo(1),
      );

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('FadeSlideIn', () {
    setUp(() => FadeSlideIn.enabled = true);
    tearDown(() => FadeSlideIn.enabled = false);

    double opacity(WidgetTester tester) =>
        tester.widget<Opacity>(find.descendant(
          of: find.byType(FadeSlideIn),
          matching: find.byType(Opacity),
        )).opacity;

    testWidgets('aparece de a poco hasta verse completo', (tester) async {
      await tester.pumpWidget(_app(const FadeSlideIn(child: Text('Hola'))));

      expect(opacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacity(tester), allOf(greaterThan(0), lessThan(1)));

      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
    });

    testWidgets('con retraso espera antes de empezar', (tester) async {
      await tester.pumpWidget(_app(const FadeSlideIn(
        delay: Duration(milliseconds: 300),
        child: Text('Hola'),
      )));

      await tester.pump(const Duration(milliseconds: 150));
      expect(opacity(tester), 0, reason: 'todavía no empieza');

      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
    });

    testWidgets('apagado deja el contenido tal cual', (tester) async {
      FadeSlideIn.enabled = false;
      await tester.pumpWidget(_app(const FadeSlideIn(child: Text('Hola'))));

      expect(find.byType(Opacity), findsNothing);
      expect(find.text('Hola'), findsOneWidget);
    });
  });
}
