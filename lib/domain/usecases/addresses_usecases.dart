import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/address_entity.dart';
import '../repositories/addresses_repository.dart';

class GetAddressesUseCase {
  final AddressesRepository repository;
  GetAddressesUseCase(this.repository);

  Future<Either<Failure, List<AddressEntity>>> call() =>
      repository.getAddresses();
}

class SaveAddressUseCase {
  final AddressesRepository repository;
  SaveAddressUseCase(this.repository);

  /// Valida lo mínimo antes de llamar al servidor (mismas reglas que la web).
  Future<Either<Failure, void>> call(AddressDraft draft, {int? id}) {
    if (draft.fullAddress.trim().isEmpty) {
      return Future.value(Either.left(
        const ValidationFailure('Ingresa la dirección'),
      ));
    }
    if (draft.ubigeoId.isEmpty) {
      return Future.value(Either.left(
        const ValidationFailure('Elige departamento, provincia y distrito'),
      ));
    }
    if ((draft.reference ?? '').length > 500) {
      return Future.value(Either.left(
        const ValidationFailure('Las indicaciones no pueden pasar de 500 letras'),
      ));
    }
    return repository.save(draft, id: id);
  }
}

class DeleteAddressUseCase {
  final AddressesRepository repository;
  DeleteAddressUseCase(this.repository);

  Future<Either<Failure, void>> call(int id) => repository.delete(id);
}

class SetDefaultAddressUseCase {
  final AddressesRepository repository;
  SetDefaultAddressUseCase(this.repository);

  Future<Either<Failure, void>> call(int id) => repository.setDefault(id);
}

class GetUbigeoUseCase {
  final AddressesRepository repository;
  GetUbigeoUseCase(this.repository);

  Future<Either<Failure, List<UbigeoOption>>> departments() =>
      repository.getDepartments();

  Future<Either<Failure, List<UbigeoOption>>> provinces(String department) =>
      repository.getProvinces(department);

  Future<Either<Failure, List<UbigeoOption>>> districts(
    String department,
    String province,
  ) =>
      repository.getDistricts(department, province);
}
