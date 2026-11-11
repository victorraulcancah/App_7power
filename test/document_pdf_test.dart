import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:appecommerce/data/datasources/statement_remote_datasource.dart';
import 'package:appecommerce/domain/entities/quote_entity.dart';
import 'package:appecommerce/domain/entities/user_entity.dart';
import 'package:appecommerce/presentation/utils/document_pdf.dart';

void _save(String name, List<int> bytes) {
  final dir = Platform.environment['PDF_OUT'];
  if (dir != null) File('$dir/$name').writeAsBytesSync(bytes);
}

/// Una fila del estado de cuenta como la devuelve el ERP: trae la venta
/// completa (cliente, sucursal, vendedor, formas de pago y productos).
Map<String, dynamic> _row({Map<String, dynamic>? boleta, bool dollars = false}) {
  Map<String, dynamic> product(int id, String code, String name, int qty, double price) => {
        'id': id,
        'codigo': code,
        'name': name,
        'brand': {'id': 1, 'name': '7POWER'},
        'pivot': {
          'id': 31000 + id,
          'cantidad': qty,
          'precio': price,
          'dolares': dollars,
          'monto_dto': 0,
          'subtotal_con_dto': qty * price,
        },
      };

  return {
    'id': 's-31001',
    'cantidad': 8,
    'dolares': dollars,
    'subtotal_con_dto': 3360,
    'created_at': '2026-11-10T17:24:24.000000Z',
    'boleta': boleta,
    'product': {'codigo': 'X9-BT', 'name': 'PANTALLA', 'brand': {'name': '7POWER'}},
    'sale': {
      'id': 8058,
      'nro_documento': 7289,
      'total_soles': dollars ? 0 : 4620,
      'total_dolares': dollars ? 1215.79 : 0,
      'tipo_de_cambio': dollars ? 3.8 : 1,
      'created_at': '2026-11-10T17:24:24.000000Z',
      'observaciones': null,
      'boleta': boleta,
      'ejecutivo_de_la_venta': {
        'id': 8,
        'name': 'FRANCIS BULNES GONZALES',
        'email': 'fbulnes@7power.pe',
        'telefono': '986750757',
      },
      'client': {
        'dni_ruc': '41415927',
        'name': 'YENY',
        'last_name': 'FALCON CANTEÑO',
        'razon_social': null,
        'calle': null,
        'direccion': 'AV. CANADA 3257',
        'lote': null,
      },
      'warehouse': {
        'name': 'PRINCIPAL',
        'direccion': 'AV ARGENTINA 980',
        'email': 'ventas@7power.pe',
        'telefono': null,
        'web': null,
        'datos': true,
        'datos_vendedor': true,
        'comentarios': null,
      },
      'payment_methods': [
        {'name': 'CONTRAENTREGA'},
      ],
      'products': [
        product(1, 'X9-BT', 'PANTALLA ANDROID 9" MEMORIA 4+64 QLED/GPS/CAR PLAY/SIM CARD/ 1 CAMARA', 8, 420),
        product(2, 'G9-DUAL', 'PANTALLA ANDROID 9" MEMORIA 4+64 QLED/GPS/CAR PLAY/ 2 CAMARAS ACEPTA TODAS LAS CAMARAS', 3, 420),
      ],
    },
  };
}

void main() {
  group('Documento de la venta (como el ERP)', () {
    test('se lee la venta completa del estado de cuenta', () {
      final sale = saleDocumentFromRow(_row())!;

      expect(sale.number, 'V001-7289');
      expect(sale.title, 'Nota de Venta');
      expect(sale.isVoucher, isFalse);
      expect(sale.clientDocument, '41415927');
      expect(sale.clientName, 'YENY FALCON CANTEÑO');
      expect(sale.clientAddress, 'AV. CANADA 3257');
      expect(sale.paymentMethods, ['CONTRAENTREGA']);
      expect(sale.sellerName, 'FRANCIS BULNES GONZALES');
      expect(sale.warehouseName, 'PRINCIPAL');
      // Con "datos del vendedor", el contacto es el del vendedor.
      expect(sale.cel, '986750757');
      expect(sale.email, 'fbulnes@7power.pe');
      expect(sale.address, 'AV ARGENTINA 980');
      expect(sale.lines, hasLength(2));
      expect(sale.lines.first.code, 'X9-BT');
      expect(sale.lines.first.brand, '7POWER');
    });

    test('las filas de una misma venta comparten el documento', () {
      final page = statementFromJson({
        'data': [
          _row(),
          {..._row(), 'id': 's-31002'},
        ],
        'total': 2,
      });

      expect(identical(page.movements[0].sale, page.movements[1].sale), isTrue);
    });

    test('con boleta sale como boleta electrónica y desglosa el IGV', () {
      final sale = saleDocumentFromRow(_row(
        boleta: {'tipo': 'b', 'serie': '1', 'numero': '23'},
      ))!;
      final doc = pdfFromSale(sale);

      expect(sale.number, 'B001-0023');
      expect(doc.title, 'BOLETA ELECTRÓNICA');
      expect(doc.total, 4620);
      expect(doc.subTotal, closeTo(4620 / 1.18, 0.001));
      expect(doc.igv, closeTo(4620 - 4620 / 1.18, 0.001));
    });

    test('el PDF de la nota de venta se genera', () async {
      final doc = pdfFromSale(saleDocumentFromRow(_row())!);

      expect(doc.title, 'NOTA DE VENTA');
      expect(doc.itemCount, 11);
      expect(doc.total, 4620);
      expect(doc.symbol, 'S/.');
      expect(doc.subTotal, isNull);
      expect(
        doc.right.map((r) => r.$1),
        containsAll(['MONEDA :', 'CONDICIÓN DE PAGO :', 'VENDEDOR :', 'SUCURSAL :']),
      );

      final bytes = await buildDocumentPdf(doc);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      _save('venta.pdf', bytes);
    });

    test('una venta en dólares lleva el tipo de cambio', () async {
      final doc = pdfFromSale(saleDocumentFromRow(_row(dollars: true))!);

      expect(doc.symbol, '\$.');
      expect(doc.exchangeRate, 3.8);
      final bytes = await buildDocumentPdf(doc);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      _save('venta-dolares.pdf', bytes);
    });
  });

  test('la cotización sale con su número y la reserva de stock', () async {
    const user = UserEntity(
      id: 1,
      fullName: 'Nelson Antonio Valencia Mendoza',
      email: 'a@b.com',
      documentNumber: '10157362378',
    );
    final quote = QuoteEntity(
      id: 3435,
      code: 'C001-3435',
      status: 'En espera',
      total: 4910,
      date: DateTime(2026, 11, 9),
      expiresAt: DateTime(2026, 11, 14),
      currency: 's',
      deliveryAddress: 'AV. NICOLÁS DE PIÉROLA REF INT. 3 NÚMERO 1770A PUESTO 3',
      items: const [
        QuoteItemEntity(productId: 1, code: 'EVO.4', name: 'AMPLIFICADOR DIGITAL 4CH * 150 RMS 3000WATTS', quantity: 5, unitPrice: 270, subtotal: 1350),
        QuoteItemEntity(productId: 2, code: 'ST8.4', name: '8" MEDIO RANGO PRO 325 RMS 650 WATTS 4 OHM', quantity: 2, unitPrice: 90, subtotal: 180),
      ],
    );

    final doc = pdfFromQuote(quote, user: user);

    expect(doc.title, 'COTIZACIÓN');
    expect(doc.symbol, 'S/.');
    expect(doc.items.first.code, 'EVO.4');
    expect(doc.reservedUntil, DateTime(2026, 11, 14));
    expect(doc.left.map((r) => r.$1), contains('DIRECCIÓN :'));

    final bytes = await buildDocumentPdf(doc);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    _save('cotizacion.pdf', bytes);
  });
}
