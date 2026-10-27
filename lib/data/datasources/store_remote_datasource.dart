import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/banner_model.dart';
import '../models/company_info_model.dart';

abstract class StoreRemoteDataSource {
  Future<CompanyInfoModel> getCompanyInfo();

  Future<List<BannerModel>> getBanners();
}

class StoreRemoteDataSourceImpl implements StoreRemoteDataSource {
  final ApiClient client;

  StoreRemoteDataSourceImpl(this.client);

  @override
  Future<CompanyInfoModel> getCompanyInfo() async {
    final response = await client.get(ApiConstants.empresaInfoEndpoint);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    return CompanyInfoModel.fromJson(
      (body as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<BannerModel>> getBanners() async {
    final response = await client.get(ApiConstants.bannersEndpoint);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    return ((body as Map<String, dynamic>)['data'] as List)
        .cast<Map<String, dynamic>>()
        .map(BannerModel.fromJson)
        .toList();
  }
}
