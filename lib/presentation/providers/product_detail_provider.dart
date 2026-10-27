import 'package:flutter/foundation.dart';

import '../../domain/entities/product_detail_entity.dart';
import '../../domain/usecases/get_product_detail_usecase.dart';

enum ProductDetailStatus { loading, loaded, error }

class ProductDetailProvider extends ChangeNotifier {
  final GetProductDetailUseCase getProductDetailUseCase;

  ProductDetailProvider({required this.getProductDetailUseCase});

  ProductDetailStatus _status = ProductDetailStatus.loading;
  ProductDetailEntity? _detail;
  String _errorMessage = '';
  int? _productId;

  ProductDetailStatus get status => _status;
  ProductDetailEntity? get detail => _detail;
  String get errorMessage => _errorMessage;

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
