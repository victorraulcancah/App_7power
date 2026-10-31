import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/quote_model.dart';

abstract class QuotesRemoteDataSource {
  Future<List<QuoteModel>> getQuotes();

  Future<void> cancel(int id, {String? reason});

  /// Pide convertir la cotización en compra. Devuelve el mensaje del servidor.
  Future<String> convertToPurchase(int id);
}

class QuotesRemoteDataSourceImpl implements QuotesRemoteDataSource {
  final ApiClient client;

  QuotesRemoteDataSourceImpl(this.client);

  @override
  Future<List<QuoteModel>> getQuotes() async {
    final response = await client.get(ApiConstants.quotesEndpoint);
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (body['cotizaciones'] as List)
        .cast<Map<String, dynamic>>()
        .map(QuoteModel.fromJson)
        .toList();
  }

  @override
  Future<void> cancel(int id, {String? reason}) async {
    await client.post(
      '${ApiConstants.quoteEndpoint}/$id/cancelar',
      body: {'motivo': ?reason},
    );
  }

  @override
  Future<String> convertToPurchase(int id) async {
    final response = await client.post(
      '${ApiConstants.quoteEndpoint}/$id/convertir-compra',
      body: const {},
    );
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final code = body['codigo_compra']?.toString();
    return code == null
        ? body['message']?.toString() ?? 'Cotización enviada para compra'
        : 'Cotización enviada para aprobación de compra ($code)';
  }
}
