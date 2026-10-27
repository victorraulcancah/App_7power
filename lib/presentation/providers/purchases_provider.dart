import 'package:flutter/foundation.dart';

import '../../domain/entities/purchase_entity.dart';
import '../../domain/usecases/purchases_usecases.dart';
import 'auth_aware_reload.dart';
import 'load_status.dart';

class PurchasesProvider extends ChangeNotifier with AuthAwareReload {
  final GetOnlinePurchasesUseCase getOnlinePurchasesUseCase;
  final GetStorePurchasesUseCase getStorePurchasesUseCase;

  PurchasesProvider({
    required this.getOnlinePurchasesUseCase,
    required this.getStorePurchasesUseCase,
  });

  LoadStatus _status = LoadStatus.initial;
  String _errorMessage = '';
  List<PurchaseEntity> _online = const [];
  List<StoreSaleEntity> _store = const [];
  bool _storeLinked = false;

  LoadStatus get status => _status;
  String get errorMessage => _errorMessage;
  List<PurchaseEntity> get online => _online;
  List<StoreSaleEntity> get store => _store;

  /// Si la cuenta está vinculada al ERP (solo entonces hay compras en tienda).
  bool get storeLinked => _storeLinked;

  /// Al cambiar de cliente no debe quedar nada del anterior.
  @override
  Future<void> reloadForAuthChange() async {
    _online = const [];
    _store = const [];
    _storeLinked = false;
    _status = LoadStatus.initial;
    notifyListeners();
  }

  Future<void> load() async {
    _status = LoadStatus.loading;
    notifyListeners();

    final results = await Future.wait([
      getOnlinePurchasesUseCase(),
      getStorePurchasesUseCase(),
    ]);

    final online = results[0].fold<String?>(
      (f) => f.message,
      (list) {
        _online = list as List<PurchaseEntity>;
        return null;
      },
    );
    // Las compras en tienda son un extra: si fallan no tumban la pantalla.
    results[1].fold((_) {}, (r) {
      final result = r as StorePurchasesResult;
      _store = result.sales;
      _storeLinked = result.linked;
    });

    if (online != null) {
      _errorMessage = online;
      _status = LoadStatus.error;
    } else {
      _status = LoadStatus.loaded;
    }
    notifyListeners();
  }
}
