import 'package:flutter/foundation.dart';

import '../../domain/entities/product_detail_entity.dart';
import '../../domain/usecases/get_product_detail_usecase.dart';
import 'auth_aware_reload.dart';

enum ProductDetailStatus { loading, loaded, error }

class ProductDetailProvider extends ChangeNotifier with AuthAwareReload {
  final GetProductDetailUseCase getProductDetailUseCase;

  ProductDetailProvider({required this.getProductDetailUseCase});

  ProductDetailStatus _status = ProductDetailStatus.loading;
  ProductDetailEntity? _detail;
  String _errorMessage = '';
  int? _productId;

  ProductDetailStatus get status => _status;
  ProductDetailEntity? get detail => _detail;
  String get errorMessage => _errorMessage;

  /// Si hay una ficha abierta, se vuelve a pedir con los precios del cliente.
  @override
  Future<void> reloadForAuthChange() async {
    final id = _productId;
    if (id != null) await load(id);
  }

  Future<void> load(int productId) async {
    // Se descarta lo anterior: no debe verse la ficha de otro producto
    // mientras carga la nueva.
    _productId = productId;
    _detail = null;
    _status = ProductDetailStatus.loading;
    notifyListeners();

    final result = await getProductDetailUseCase(productId);
    if (_productId != productId) return;

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _status = ProductDetailStatus.error;
      },
      (detail) {
        _detail = detail;
        _status = ProductDetailStatus.loaded;
      },
    );
    notifyListeners();
  }
}
