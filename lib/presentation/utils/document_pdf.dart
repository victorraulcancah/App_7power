import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/format_utils.dart';
import '../../domain/entities/quote_entity.dart';
import '../../domain/entities/statement_entity.dart';
import '../../domain/entities/user_entity.dart';

/// Los datos de la empresa que el ERP imprime en el encabezado de sus
/// documentos (`company` en su plantilla). Cuando la sucursal o el vendedor
/// traen los suyos, esos van primero (ver [SaleDocumentEntity]).
class PdfIssuer {
  final String name;
  final String ruc;
  final String address;
  final String? phone;
  final String email;
  final String web;

  const PdfIssuer({
    this.name = 'GRUPO 7POWER SAC',
    this.ruc = '20608003380',
    this.address = 'AV ARGENTINA 980',
    this.phone,
    this.email = 'ventas@7power.pe',
    this.web = 'WWW.7POWER.PE',
  });
}

/// Una fila de la tabla de productos.
class PdfDocItem {
  final String quantity;
  final String code;
  final String description;
  final String? brand;
  final double unitPrice;
  final double total;

  /// "S/." o "$." de esa línea.
  final String symbol;

  const PdfDocItem({
    required this.quantity,
    required this.code,
    required this.description,
    required this.unitPrice,
    required this.total,
    this.brand,
    this.symbol = 'S/.',
  });
}

/// Un documento impreso con el diseño del ERP (nota de venta, boleta, factura
/// o cotización): encabezado con la empresa y el cuadro del número,
/// "INFORMACIÓN GENERAL", tabla de productos y totales.
class PdfDocument {
  final String title;
  final String number;
  final PdfIssuer issuer;
  final String address;
  final String cel;
  final String email;
  final String web;

  /// Las dos columnas de "INFORMACIÓN GENERAL": (rótulo, valor).
  final List<(String, String)> left;
  final List<(String, String)> right;
  final List<PdfDocItem> items;

  /// "S/." o "$." del documento.
  final String symbol;
  final double discount;
  final double total;

  /// Con boleta o factura, el desglose del IGV (`Sub Total`, `Valor Venta`,
  /// `IGV`); null en nota de venta y cotización.
  final double? subTotal;
  final double? igv;

  /// Solo en ventas en dólares: "Tipo de Cambio: S/. 3.8".
  final double? exchangeRate;

  /// Cotizaciones: hasta cuándo se reserva el stock.
  final DateTime? reservedUntil;
  final String? comments;
  final String? observations;

  const PdfDocument({
    required this.title,
    required this.number,
    required this.address,
    required this.cel,
    required this.email,
    required this.web,
    required this.left,
    required this.right,
    required this.items,
    required this.symbol,
    required this.total,
    this.issuer = const PdfIssuer(),
    this.discount = 0,
    this.subTotal,
    this.igv,
    this.exchangeRate,
    this.reservedUntil,
    this.comments,
    this.observations,
  });

  /// "NRO. DE ITEMS": la suma de las cantidades.
  int get itemCount => items.fold(0, (n, i) => n + (int.tryParse(i.quantity) ?? 0));
}

// ── Arma el documento a partir de los datos del app ─────────────────────────────────────────

String _dmy(DateTime d) => FormatUtils.date(d.toLocal());

/// El documento de una venta del estado de cuenta, con las mismas reglas de la
/// plantilla del ERP.
PdfDocument pdfFromSale(SaleDocumentEntity sale, {PdfIssuer issuer = const PdfIssuer()}) {
  final symbol = sale.inDollars ? '\$.' : 'S/.';
  final total = sale.lines.fold<double>(0, (n, l) => n + l.total);
  // El IGV de la empresa (18 %) solo se desglosa en boleta y factura.
  const divisor = 1.18;

  return PdfDocument(
    title: sale.title.toUpperCase(),
    number: sale.number,
    issuer: issuer,
    address: sale.address ?? issuer.address,
    cel: sale.cel ?? issuer.phone ?? '-',
    email: sale.email ?? issuer.email,
    web: sale.web ?? issuer.web,
    left: [
      ('RUC/DNI :', sale.clientDocument ?? '-'),
      ('CLIENTE :', sale.clientName),
      ('FECHA DE EMISIÓN :', sale.date == null ? '-' : _dmy(sale.date!)),
      ('DIRECCIÓN :', sale.clientAddress.isEmpty ? '-' : sale.clientAddress),
    ],
    right: [
      ('MONEDA :', sale.inDollars ? 'DÓLARES' : 'SOLES'),
      ('CONDICIÓN DE PAGO :', sale.paymentMethods.join(', ')),
      ('VENDEDOR :', sale.sellerName),
      ('SUCURSAL :', sale.warehouseName ?? '-'),
    ],
    items: [
      for (final l in sale.lines)
        PdfDocItem(
          quantity: '${l.quantity}',
          code: l.code,
          description: l.name,
          brand: l.brand,
          unitPrice: l.unitPrice,
          total: l.total,
          symbol: l.dollars ? '\$.' : 'S/.',
        ),
    ],
    symbol: symbol,
    discount: sale.lines.fold<double>(0, (n, l) => n + l.discount),
    total: total,
    subTotal: sale.isVoucher ? total / divisor : null,
    igv: sale.isVoucher ? total - total / divisor : null,
    exchangeRate: sale.inDollars ? sale.exchangeRate : null,
    comments: sale.comments,
    observations: sale.observations,
  );
}

/// Una cotización del cliente.
PdfDocument pdfFromQuote(QuoteEntity quote, {UserEntity? user, PdfIssuer issuer = const PdfIssuer()}) {
  final inDollars = (quote.currency ?? '').toLowerCase().startsWith('d');
  final symbol = inDollars ? '\$.' : 'S/.';

  return PdfDocument(
    title: 'COTIZACIÓN',
    number: quote.code,
    issuer: issuer,
    address: issuer.address,
    cel: issuer.phone ?? '-',
    email: issuer.email,
    web: issuer.web,
    left: [
      ('RUC/DNI :', user?.displayDocument ?? '-'),
      ('CLIENTE :', user?.displayName ?? '-'),
      ('FECHA DE EMISIÓN :', quote.date == null ? '-' : _dmy(quote.date!)),
      (
        'DIRECCIÓN :',
        (quote.deliveryAddress == null || quote.deliveryAddress!.isEmpty) ? '-' : quote.deliveryAddress!,
      ),
    ],
    right: [('MONEDA :', inDollars ? 'DÓLARES' : 'SOLES')],
    items: [
      for (final i in quote.items)
        PdfDocItem(
          quantity: '${i.quantity}',
          code: i.code ?? '',
          description: i.name,
          unitPrice: i.unitPrice,
          total: i.subtotal,
          symbol: symbol,
        ),
    ],
    symbol: symbol,
    total: quote.total,
    reservedUntil: quote.expiresAt,
  );
}

// ── El PDF ──────────────────────────────────────────────────────────────────────────────────

/// Los montos como `toLocaleString('en-US')` del ERP: miles con coma y dos
/// decimales.
String _number(double v) {
  final parts = v.abs().toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${v < 0 ? '-' : ''}$whole.${parts[1]}';
}

/// El PDF, en hoja A4 vertical y con el mismo diseño del documento del ERP.
Future<Uint8List> buildDocumentPdf(PdfDocument d) async {
  const headerGray = PdfColor.fromInt(0xFFE6E6E6);
  const lineGray = PdfColor.fromInt(0xFFE3E3E3);
  const boxBorder = PdfColor.fromInt(0xFFD0D0D0);
  const slate = PdfColor.fromInt(0xFF94A3B8);
  const lime = PdfColor.fromInt(0xFF84CC16);

  final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
  String money(double v) => '${d.symbol} ${_number(v)}';

  pw.TextStyle t(double size, {bool b = false, PdfColor? color}) => pw.TextStyle(
    fontSize: size,
    fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: color,
  );

  pw.Widget labelValue(String label, String value) => pw.RichText(
    text: pw.TextSpan(
      style: t(8),
      children: [
        pw.TextSpan(text: '$label ', style: bold),
        pw.TextSpan(text: value),
      ],
    ),
  );

  // Cada fila de "INFORMACIÓN GENERAL": el rótulo y el valor, mitad y mitad.
  pw.Widget infoColumn(List<(String, String)> rows) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final r in rows)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 1.5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: pw.Text(r.$1, style: t(7.5, b: true))),
              pw.SizedBox(width: 6),
              pw.Expanded(child: pw.Text(r.$2, style: t(7.5))),
            ],
          ),
        ),
    ],
  );

  pw.Widget headerCell(String text, {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Align(alignment: align, child: pw.Text(text, style: t(8, b: true)));

  pw.Widget amountCell(String symbol, double value) => pw.RichText(
    text: pw.TextSpan(
      style: t(7.5),
      children: [
        pw.TextSpan(text: '$symbol ', style: t(7.5, b: true, color: slate)),
        pw.TextSpan(text: _number(value)),
      ],
    ),
  );

  pw.Widget totalBox(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Text(label, style: t(10, b: true)),
      pw.Text(value, style: t(10)),
    ],
  );

  final issuer = d.issuer;
  final doc = pw.Document(title: '${d.title} ${d.number}', author: issuer.name);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      build: (context) => [
        // Encabezado: (espacio del logo) · empresa · cuadro con el número.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(flex: 1, child: pw.SizedBox()),
            pw.SizedBox(width: 14),
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(issuer.name, style: t(12, b: true)),
                  pw.SizedBox(height: 2),
                  pw.Text(d.address, style: t(8)),
                  labelValue('Cel:', d.cel),
                  labelValue('Email:', d.email),
                  labelValue('Web:', d.web),
                ],
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              flex: 2,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: boxBorder, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('RUC: ${issuer.ruc}', style: t(11)),
                    pw.SizedBox(height: 6),
                    pw.Text(d.title, textAlign: pw.TextAlign.center, style: t(13, b: true)),
                    pw.SizedBox(height: 6),
                    pw.Text('Nro: ${d.number}', style: t(11)),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          width: double.infinity,
          color: headerGray,
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Center(child: pw.Text('INFORMACIÓN GENERAL', style: t(10, b: true))),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: infoColumn(d.left)),
            pw.SizedBox(width: 24),
            pw.Expanded(child: infoColumn(d.right)),
          ],
        ),
        pw.SizedBox(height: 14),
        // Tabla de productos: CANTIDAD · CÓDIGO · DESCRIPCIÓN · VALOR U. · Total.
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          decoration: const pw.BoxDecoration(
            color: headerGray,
            borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(8)),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(flex: 110, child: headerCell('CANTIDAD')),
              pw.Expanded(flex: 120, child: headerCell('CÓDIGO')),
              pw.Expanded(flex: 600, child: headerCell('DESCRIPCIÓN')),
              pw.Expanded(flex: 110, child: headerCell('VALOR U.')),
              pw.Expanded(flex: 110, child: headerCell('Total')),
            ],
          ),
        ),
        for (final i in d.items)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: lineGray, width: 0.6)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(flex: 110, child: pw.Text(i.quantity, style: t(7.5))),
                pw.Expanded(flex: 120, child: pw.Text(i.code, style: t(7.5))),
                pw.Expanded(
                  flex: 600,
                  child: pw.RichText(
                    text: pw.TextSpan(
                      style: t(7.5),
                      children: [
                        pw.TextSpan(text: i.description),
                        if (i.brand != null) ...[
                          pw.TextSpan(text: '  |  ', style: t(7.5, b: true, color: lime)),
                          pw.TextSpan(text: i.brand),
                        ],
                      ],
                    ),
                  ),
                ),
                pw.Expanded(flex: 110, child: amountCell(i.symbol, i.unitPrice)),
                pw.Expanded(flex: 110, child: amountCell(i.symbol, i.total)),
              ],
            ),
          ),
        pw.SizedBox(height: 8),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('NRO. DE ITEMS: ${d.itemCount}', style: t(10)),
        ),
        pw.SizedBox(height: 6),
        // Totales: con boleta o factura también el desglose del IGV.
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border.symmetric(
              horizontal: pw.BorderSide(color: PdfColors.black, width: 1.2),
            ),
          ),
          child: d.subTotal == null
              ? pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: totalBox('Desct. Total:', money(d.discount)),
                )
              : pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    totalBox('Sub Total:', money(d.subTotal!)),
                    totalBox('Descuento:', money(d.discount)),
                    totalBox('Valor Venta:', money(d.subTotal!)),
                    totalBox('IGV:', money(d.igv!)),
                  ],
                ),
        ),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.2)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('TOTAL: ${money(d.total)}', style: t(10, b: true)),
              if (d.exchangeRate != null)
                pw.Text(
                  'Tipo de Cambio: S/. ${d.exchangeRate}',
                  style: t(8, color: PdfColors.grey600),
                ),
            ],
          ),
        ),
        if (d.reservedUntil != null) ...[
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFEAF6DD),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Se reservó el Stock hasta:',
                  style: t(8, color: const PdfColor.fromInt(0xFF4C8A1E)),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(_dmy(d.reservedUntil!), style: t(9)),
            ],
          ),
        ],
        pw.SizedBox(height: 22),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('GRACIAS POR SU COMPRA!', style: t(10, b: true)),
        ),
        pw.SizedBox(height: 3),
        pw.Container(height: 1.2, color: PdfColors.black),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Row(
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (d.comments != null)
                        pw.Text(d.comments!, style: t(8, b: true, color: PdfColors.grey600)),
                      pw.Text('Representación Impresa de la Factura Electrónica', style: t(9)),
                      pw.Text('Contrata Factura en Novi-k Perú', style: t(9, b: true)),
                      pw.Text('GRACIAS POR SU VISITA', style: t(9, b: true)),
                      pw.Text('Yo vendo con https://novi-k.com', style: t(9, b: true)),
                    ],
                  ),
                ],
              ),
            ),
            if (d.observations != null)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Observaciones:', style: t(9, b: true)),
                    pw.Text(d.observations!, style: t(9)),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

/// Abre el PDF en una pantalla con vista previa, compartir e imprimir.
Future<void> openDocumentPdf(BuildContext context, PdfDocument document) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(document.number)),
        body: PdfPreview(
          build: (_) => buildDocumentPdf(document),
          pdfFileName: '${document.number}.pdf',
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
        ),
      ),
    ),
  );
}
