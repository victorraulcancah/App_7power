import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/response_cache.dart';
import '../models/banner_model.dart';
import '../models/company_info_model.dart';

abstract class StoreRemoteDataSource {
  Future<CompanyInfoModel> getCompanyInfo();

  Future<List<BannerModel>> getBanners();

  /// Los banners de la última vez que se pidieron, o null si no hay guardados.
  Future<List<BannerModel>?> getCachedBanners();
}

class StoreRemoteDataSourceImpl implements StoreRemoteDataSource {
  static const _bannersKey = 'banners';

  final ApiClient client;
  final ResponseCache? cache;

  StoreRemoteDataSourceImpl(this.client, {this.cache});

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
    final text = utf8.decode(response.bodyBytes);
    final banners = _parseBanners(text);
    // Solo se guarda lo que se pudo interpretar.
    await cache?.write(_bannersKey, text);
    return banners;
  }

  @override
  Future<List<BannerModel>?> getCachedBanners() async {
    final text = await cache?.read(_bannersKey);
    if (text == null) return null;
    try {
      return _parseBanners(text);
    } catch (_) {
      return null;
    }
  }

  List<BannerModel> _parseBanners(String text) =>
      ((jsonDecode(text) as Map<String, dynamic>)['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(BannerModel.fromJson)
          .toList();
}
