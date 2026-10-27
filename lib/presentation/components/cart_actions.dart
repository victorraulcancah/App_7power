import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/product_entity.dart';
import '../providers/cart_provider.dart';
import 'app_snackbar.dart';

/// Acciones del carrito reutilizables desde cualquier pantalla.
class CartActions {
  /// Agrega [quantity] unidades de [product] y avisa del resultado.
  static Future<bool> add(
    BuildContext context,
    ProductEntity product, {
    int quantity = 1,
  }) async {
    final cart = context.read<CartProvider>();
    final error = await cart.add(product, quantity: quantity);

    if (!context.mounted) return error == null;
    if (error == null) {
      AppSnackbar.success(context, 'Agregado al carrito');
    } else {
      AppSnackbar.error(context, error);
    }
    return error == null;
  }
}
