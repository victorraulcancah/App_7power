import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/purchase_model.dart';

abstract class PurchasesRemoteDataSource {
  Future<List<PurchaseModel>> getOnlinePurchases();

  Future<StorePurchasesModel> getStorePurchases();
}

class PurchasesRemoteDataSourceImpl implements PurchasesRemoteDataSource {
  final ApiClient client;

  PurchasesRemoteDataSourceImpl(this.client);

  Map<String, dynamic> _body(List<int> bytes) =>
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

  @override
  Future<List<PurchaseModel>> getOnlinePurchases() async {
    final response = await client.get(ApiConstants.onlinePurchasesEndpoint);
    return (_body(response.bodyBytes)['pagos'] as List)
        .cast<Map<String, dynamic>>()
        .map(PurchaseModel.fromJson)
        .toList();
  }

  @override
  Future<StorePurchasesModel> getStorePurchases() async {
    final response = await client.get(ApiConstants.storePurchasesEndpoint);
    return StorePurchasesModel.fromJson(_body(response.bodyBytes));
  }
}
