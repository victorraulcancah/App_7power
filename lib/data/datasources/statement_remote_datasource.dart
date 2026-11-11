import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/entities/statement_entity.dart';

abstract class StatementRemoteDataSource {
  Future<AccountStatementPage> getStatement({
    required String erpCode,
    required DateTime from,
    required DateTime to,
    int page = 1,
  });
}

/// Movimientos por página que devuelve el ERP.
const int statementPageSize = 50;

class StatementRemoteDataSourceImpl implements StatementRemoteDataSource {
  /// Cliente apuntado al ERP (no al de la tienda).
  final ApiClient client;

  StatementRemoteDataSourceImpl(this.client);

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<AccountStatementPage> getStatement({
    required String erpCode,
    required DateTime from,
    required DateTime to,
    int page = 1,
  }) async {
    final response = await client.get(
      ApiConstants.statementEndpoint,
      queryParameters: {
        'codigo': erpCode,
        // La vista detallada por producto, la misma del ERP.
        'agrupado': 'false',
        'fechas[0]': _day(from),
        'fechas[1]': _day(to),
        'pagination[current]': '$page',
        'pagination[pageSize]': '$statementPageSize',
      },
    );
    return statementFromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}

double _num(Object? value) => FormatUtils.toDouble(value);

String? _text(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map<String, dynamic> ? value : null;

/// "Documento" como lo arma el ERP: boleta o factura con serie y número, y
/// "V001-nnnn" para una venta sin comprobante. Los pagos no tienen.
String _document(Map<String, dynamic> row) {
  final sale = _map(row['sale']);
  if (row['type'] == 'payment_seller_aggregated' || sale == null) return '-';

  final voucher = _map(sale['boleta']);
  if (voucher != null) {
    final type = (_text(voucher['tipo']) ?? 'bol').toUpperCase();
    final serie = (_text(voucher['serie']) ?? '001').padLeft(3, '0');
    final number = (_text(voucher['numero']) ?? '0').padLeft(4, '0');
    return '$type$serie-$number';
  }
  final number = (_text(sale['nro_documento']) ?? '0').padLeft(4, '0');
  return 'V001-$number';
}

/// "código | nombre | marca" de un producto, o "Pagó con {método}".
String _description(Map<String, dynamic> row) {
  final product = _map(row['product']);
  if (product != null) {
    final brand = _text(_map(product['brand'])?['name']) ?? '-';
    return '${_text(product['codigo']) ?? ''} | ${_text(product['name']) ?? ''} | $brand';
  }
  final method = _text(_map(row['payment_method'])?['name']) ??
      _text(_map(row['paymentMethod'])?['name']) ??
      'N/A';
  return 'Pagó con $method';
}

bool _isPayment(Map<String, dynamic> row) =>
    row['type'] == 'payment_seller_aggregated' ||
    _map(row['payment_method']) != null ||
    _map(row['paymentMethod']) != null ||
    ((row['payment_methods'] as List?)?.isNotEmpty ?? false) ||
    _map(row['product']) == null;

/// La moneda de una venta se decide por `total_dolares` de la venta, nunca por
/// el tipo de cambio (que es solo una referencia).
({double soles, double dollars}) _amounts(Map<String, dynamic> row) {
  if (row['type'] == 'payment_seller_aggregated') {
    final total = _num(row['total_sumado']);
    final inDollars = row['moneda'] == 'dolares';
    return (soles: inDollars ? 0 : total, dollars: inDollars ? total : 0);
  }
  if (_map(row['payment_method']) != null) {
    final saleDollars = _num(_map(row['sale'])?['total_dolares']);
    final amount = _num(row['monto']);
    return saleDollars > 0
        ? (soles: 0, dollars: amount)
        : (soles: amount, dollars: 0);
  }
  final subtotal = _num(row['subtotal_con_dto']);
  return row['dolares'] == true
      ? (soles: 0, dollars: subtotal)
      : (soles: subtotal, dollars: 0);
}

/// La dirección como la imprime el ERP (`direccionCompleta`): urbanización,
/// dirección y número, sin repetir lo que ya está escrito en lo anterior.
String _fullAddress(Map<String, dynamic>? d) {
  if (d == null) return '';
  String compare(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  var text = '';
  for (final part in [d['calle'], d['direccion'], d['lote']]) {
    final p = (part?.toString() ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (p.isEmpty) continue;
    if (text.isNotEmpty && compare(text).contains(compare(p))) continue;
    text = text.isNotEmpty && compare(p).contains(compare(text))
        ? p
        : text.isNotEmpty
            ? '$text $p'
            : p;
  }
  return text;
}

/// El documento de una venta tal como lo imprime el ERP. Sigue las reglas de
/// su plantilla (`boleta.tsx`): la dirección y el contacto de la sucursal o del
/// vendedor, el cliente, la forma de pago y los productos de la venta.
SaleDocumentEntity? saleDocumentFromRow(Map<String, dynamic> row) {
  final sale = _map(row['sale']);
  if (sale == null || sale['products'] is! List) return null;

  final warehouse = _map(sale['warehouse']);
  final client = _map(sale['client']);
  final voucher = _map(sale['boleta']) ?? _map(row['boleta']);
  final useWarehouse = warehouse?['datos'] == true;
  final useSeller = warehouse?['datos_vendedor'] == true;

  // El vendedor: el ejecutivo de la venta o, si no, el vendedor elegido o quien
  // la registró (`datosVendedorDeVenta`).
  final executive = _map(sale['ejecutivo_de_la_venta']);
  final seller = _map(sale['vendedor']);
  final user = _map(sale['user']);
  final sellerName = executive != null
      ? _text(executive['name'])
      : (_text(seller?['name']) ?? _text(user?['name']));
  final sellerPhone = executive != null
      ? _text(executive['telefono'])
      : (_text(seller?['telefono']) ?? _text(user?['telefono']));
  final sellerEmail = executive != null
      ? _text(executive['email'])
      : (_text(seller?['email']) ?? _text(user?['email']));

  String number;
  String title;
  if (voucher != null) {
    final type = (_text(voucher['tipo']) ?? '').toUpperCase();
    number = '$type${(_text(voucher['serie']) ?? '001').padLeft(3, '0')}-'
        '${(_text(voucher['numero']) ?? '0').padLeft(4, '0')}';
    title =
        voucher['tipo'] == 'b' ? 'Boleta Electrónica' : 'Factura Electrónica';
  } else {
    number = 'V001-${(_text(sale['nro_documento']) ?? '0').padLeft(4, '0')}';
    title = 'Nota de Venta';
  }

  final lines = <SaleDocumentLine>[];
  for (final p in (sale['products'] as List).whereType<Map<String, dynamic>>()) {
    final pivot = _map(p['pivot']);
    if (pivot == null) continue;
    lines.add(SaleDocumentLine(
      code: _text(p['codigo']) ?? '',
      name: _text(p['name']) ?? _text(pivot['concepto_libre']) ?? '',
      brand: _text(_map(p['brand'])?['name']),
      quantity: _num(pivot['cantidad']).round(),
      unitPrice: _num(pivot['precio']),
      discount: _num(pivot['monto_dto']),
      total: _num(pivot['subtotal_con_dto']),
      dollars: pivot['dolares'] == true,
    ));
  }

  final lastName = _text(client?['last_name']);
  return SaleDocumentEntity(
    number: number,
    title: title,
    isVoucher: voucher != null,
    date: DateTime.tryParse(sale['created_at']?.toString() ?? ''),
    address: useWarehouse ? _text(warehouse?['direccion']) : null,
    cel: useSeller
        ? sellerPhone
        : (useWarehouse ? _text(warehouse?['telefono']) : null),
    email: useSeller
        ? sellerEmail
        : (useWarehouse ? _text(warehouse?['email']) : null),
    web: useWarehouse ? _text(warehouse?['web']) : null,
    clientDocument: _text(client?['dni_ruc']),
    clientName: _text(client?['razon_social']) ??
        '${_text(client?['name']) ?? '-'}${lastName != null ? ' $lastName' : ''}',
    clientAddress: _fullAddress(client),
    inDollars: _num(sale['total_dolares']) > 0,
    exchangeRate: _num(sale['tipo_de_cambio']),
    paymentMethods: [
      for (final m in ((sale['payment_methods'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>())
        if (_text(m['name']) != null) _text(m['name'])!,
    ],
    sellerName: sellerName ?? '-',
    warehouseName: _text(warehouse?['name']),
    observations: _text(sale['observaciones']),
    comments: useWarehouse ? _text(warehouse?['comentarios']) : null,
    lines: lines,
  );
}

AccountMovement movementFromJson(Map<String, dynamic> row,
    {SaleDocumentEntity? sale}) {
  final amounts = _amounts(row);
  return AccountMovement(
    sale: sale ?? saleDocumentFromRow(row),
    id: row['id']?.toString() ?? '',
    date: DateTime.tryParse(row['created_at']?.toString() ?? ''),
    document: _document(row),
    description: _description(row),
    quantity: row['cantidad'] == null ? null : _num(row['cantidad']).round(),
    soles: amounts.soles,
    dollars: amounts.dollars,
    isPayment: _isPayment(row),
    isVoided: _map(row['sale'])?['estado'] == false,
  );
}

/// Los movimientos de una página. Las filas de una misma venta comparten un
/// solo documento (cada fila trae la venta completa: se arma una sola vez).
List<AccountMovement> _movements(List<Map<String, dynamic>> rows) {
  final sales = <Object?, SaleDocumentEntity?>{};
  return [
    for (final row in rows)
      movementFromJson(
        row,
        sale: _map(row['sale'])?['id'] == null
            ? null
            : sales.putIfAbsent(
                _map(row['sale'])!['id'],
                () => saleDocumentFromRow(row),
              ),
      ),
  ];
}

/// Respuesta de `GET /ecommerce/estado-de-cuenta`. Cada fila trae la venta
/// completa (con cliente y vendedor); solo se leen los datos que se muestran.
AccountStatementPage statementFromJson(Map<String, dynamic> json) {
  final client = _map(json['client']) ?? const <String, dynamic>{};
  return AccountStatementPage(
    summary: AccountSummary(
      creditLimit: _num(client['credito']),
      creditUsed: _num(client['linea_utilizada']),
      creditAvailable: _num(client['credito_disponible']),
      debtSoles: _num(json['deudaTotalSoles']),
      debtDollars: _num(json['deudaTotalDolares']),
      previousDebtSoles: _num(json['deuda_anterior_soles']),
      previousDebtDollars: _num(json['deuda_anterior_dolares']),
    ),
    movements: _movements(((json['data'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()),
    total: _num(json['total']).round(),
  );
}
