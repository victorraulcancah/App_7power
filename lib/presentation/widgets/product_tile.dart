import 'package:flutter/material.dart';

import '../../domain/entities/product_entity.dart';
import '../components/components.dart';
import '../pages/product_detail_page.dart';

/// Tarjeta de un producto con su comportamiento estándar: abre la ficha al
/// tocarla y agrega al carrito desde el botón.
class ProductTile extends StatelessWidget {
  final ProductEntity product;

  const ProductTile({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return ProductCard(
      name: product.name,
      brand: product.brand,
      imageUrl: product.imageUrl,
      price: product.price,
      currency: product.currency,
      stock: product.stock,
      priceVisible: product.priceVisible,
      onTap: () => ProductDetailPage.open(context, product),
      onAddToCart: () => CartActions.add(context, product),
    );
  }
}
