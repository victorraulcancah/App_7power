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

AccountMovement movementFromJson(Map<String, dynamic> row) {
  final amounts = _amounts(row);
  return AccountMovement(
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
    movements: ((json['data'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(movementFromJson)
        .toList(),
    total: _num(json['total']).round(),
  );
}
