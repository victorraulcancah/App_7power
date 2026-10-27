import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/address_entity.dart';
import '../../domain/repositories/addresses_repository.dart';
import '../datasources/addresses_remote_datasource.dart';

class AddressesRepositoryImpl implements AddressesRepository {
  final AddressesRemoteDataSource remote;

  AddressesRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, List<AddressEntity>>> getAddresses() =>
      guardRequest(remote.getAddresses);

  @override
  Future<Either<Failure, void>> save(AddressDraft draft, {int? id}) =>
      guardRequest(() => remote.save(draft, id: id));

  @override
  Future<Either<Failure, void>> delete(int id) =>
      guardRequest(() => remote.delete(id));

  @override
  Future<Either<Failure, void>> setDefault(int id) =>
      guardRequest(() => remote.setDefault(id));

  @override
  Future<Either<Failure, List<UbigeoOption>>> getDepartments() =>
      guardRequest(remote.getDepartments);

  @override
  Future<Either<Failure, List<UbigeoOption>>> getProvinces(String department) =>
      guardRequest(() => remote.getProvinces(department));

  @override
  Future<Either<Failure, List<UbigeoOption>>> getDistricts(
    String department,
    String province,
  ) =>
      guardRequest(() => remote.getDistricts(department, province));
}
