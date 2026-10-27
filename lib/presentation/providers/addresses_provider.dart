import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/address_entity.dart';
import '../../domain/usecases/addresses_usecases.dart';
import 'auth_aware_reload.dart';
import 'load_status.dart';

class AddressesProvider extends ChangeNotifier with AuthAwareReload {
  final GetAddressesUseCase getAddressesUseCase;
  final SaveAddressUseCase saveAddressUseCase;
  final DeleteAddressUseCase deleteAddressUseCase;
  final SetDefaultAddressUseCase setDefaultAddressUseCase;
  final GetUbigeoUseCase ubigeo;

  AddressesProvider({
    required this.getAddressesUseCase,
    required this.saveAddressUseCase,
    required this.deleteAddressUseCase,
    required this.setDefaultAddressUseCase,
    required this.ubigeo,
  });

  LoadStatus _status = LoadStatus.initial;
  List<AddressEntity> _items = const [];
  String _errorMessage = '';

  LoadStatus get status => _status;
  List<AddressEntity> get items => _items;
  String get errorMessage => _errorMessage;

  @override
  Future<void> reloadForAuthChange() async {
    _items = const [];
    _status = LoadStatus.initial;
    notifyListeners();
  }

  Future<void> load() async {
    _status = LoadStatus.loading;
    notifyListeners();

    final result = await getAddressesUseCase();
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _status = LoadStatus.error;
      },
      (items) {
        _items = items;
        _status = LoadStatus.loaded;
      },
    );
    notifyListeners();
  }

  /// Devuelve null si se guardó, o el motivo por el que no se pudo.
  Future<String?> save(AddressDraft draft, {int? id}) =>
      _then(saveAddressUseCase(draft, id: id));

  Future<String?> delete(int id) => _then(deleteAddressUseCase(id));

  Future<String?> setDefault(int id) => _then(setDefaultAddressUseCase(id));

  /// Ejecuta una acción y, si salió bien, vuelve a pedir la lista (el servidor
  /// reasigna la predeterminada en varios casos).
  Future<String?> _then(Future<Either<Failure, void>> action) async {
    final result = await action;
    final error = result.fold<String?>((f) => f.message, (_) => null);
    if (error != null) return error;
    await load();
    return null;
  }
}
