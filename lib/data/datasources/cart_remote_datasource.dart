import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/cart_item_model.dart';

abstract class CartRemoteDataSource {
  Future<List<CartItemModel>> getCart();

  Future<void> add(int productId, int quantity);

  Future<void> updateQuantity(int productId, int quantity);

  Future<void> remove(int productId);

  Future<void> clear();

  /// Fusiona [items] con el carrito del servidor y devuelve el resultado.
  Future<List<CartItemModel>> sync(List<CartItemModel> items);
}

class CartRemoteDataSourceImpl implements CartRemoteDataSource {
  final ApiClient client;

  CartRemoteDataSourceImpl(this.client);

  List<CartItemModel> _parse(List<int> bytes) =>
      (jsonDecode(utf8.decode(bytes)) as List)
          .cast<Map<String, dynamic>>()
          // Los "guardados para después" de la web no son parte del carrito
          // activo.
          .where((i) => i['guardado_para_despues'] != true)
          .map(CartItemModel.fromApi)
          .toList();

  @override
  Future<List<CartItemModel>> getCart() async {
    final response = await client.get(ApiConstants.cartEndpoint);
    return _parse(response.bodyBytes);
  }

  @override
  Future<void> add(int productId, int quantity) async {
    await client.post(
      '${ApiConstants.cartEndpoint}/add',
      body: {'producto_id': productId, 'cantidad': quantity},
    );
  }

  @override
  Future<void> updateQuantity(int productId, int quantity) async {
    await client.put(
      '${ApiConstants.cartEndpoint}/update/$productId',
      body: {'cantidad': quantity},
    );
  }

  @override
  Future<void> remove(int productId) async {
    await client.delete('${ApiConstants.cartEndpoint}/remove/$productId');
  }

  @override
  Future<void> clear() async {
    await client.delete('${ApiConstants.cartEndpoint}/clear');
  }

  @override
  Future<List<CartItemModel>> sync(List<CartItemModel> items) async {
    final response = await client.post(
      '${ApiConstants.cartEndpoint}/sync',
      body: {
        'items': [
          for (final i in items)
            {'producto_id': i.productId, 'cantidad': i.quantity},
        ],
      },
    );
    return _parse(response.bodyBytes);
  }
}
