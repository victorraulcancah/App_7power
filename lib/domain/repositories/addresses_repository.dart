import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/address_entity.dart';

abstract class AddressesRepository {
  Future<Either<Failure, List<AddressEntity>>> getAddresses();

  /// Crea una dirección, o edita la que tiene [id].
  Future<Either<Failure, void>> save(AddressDraft draft, {int? id});

  Future<Either<Failure, void>> delete(int id);

  Future<Either<Failure, void>> setDefault(int id);

  Future<Either<Failure, List<UbigeoOption>>> getDepartments();

  Future<Either<Failure, List<UbigeoOption>>> getProvinces(String department);

  Future<Either<Failure, List<UbigeoOption>>> getDistricts(
    String department,
    String province,
  );
}
