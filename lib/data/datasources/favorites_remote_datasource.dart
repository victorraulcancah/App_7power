import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/product_model.dart';

abstract class FavoritesRemoteDataSource {
  Future<List<ProductModel>> getFavorites();

  Future<void> add(int productId);

  Future<void> remove(int productId);
}

class FavoritesRemoteDataSourceImpl implements FavoritesRemoteDataSource {
  final ApiClient client;

  FavoritesRemoteDataSourceImpl(this.client);

  @override
  Future<List<ProductModel>> getFavorites() async {
    final response = await client.get(ApiConstants.favoritesEndpoint);
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    return (body['data'] as List)
        .cast<Map<String, dynamic>>()
        // Un producto desactivado llega con `producto: null` pero el favorito
        // sigue en la lista: no hay nada que mostrar.
        .map((f) => f['producto'])
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromFavoriteJson)
        .toList();
  }

  @override
  Future<void> add(int productId) async {
    await client.post(
      ApiConstants.favoritesEndpoint,
      body: {'producto_id': productId},
    );
  }

  /// La ruta lleva el id del PRODUCTO, no el del favorito.
  @override
  Future<void> remove(int productId) async {
    await client.delete('${ApiConstants.favoritesEndpoint}/$productId');
  }
}
