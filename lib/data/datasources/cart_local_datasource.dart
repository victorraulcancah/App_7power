import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item_model.dart';

abstract class CartLocalDataSource {
  Future<List<CartItemModel>> read();

  Future<void> write(List<CartItemModel> items);

  Future<void> clear();
}

/// Carrito del invitado, guardado en el dispositivo.
class CartLocalDataSourceImpl implements CartLocalDataSource {
  static const _key = 'guest_cart_v1';

  @override
  Future<List<CartItemModel>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];

    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(CartItemModel.fromLocal)
          .toList();
    } catch (_) {
      // Datos corruptos: se descartan en vez de romper el carrito.
      await prefs.remove(_key);
      return [];
    }
  }

  @override
  Future<void> write(List<CartItemModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((i) => i.toLocal()).toList()),
    );
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
