import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../domain/entities/address_entity.dart';
import '../models/address_model.dart';

abstract class AddressesRemoteDataSource {
  Future<List<AddressModel>> getAddresses();

  Future<void> save(AddressDraft draft, {int? id});

  Future<void> delete(int id);

  Future<void> setDefault(int id);

  Future<List<UbigeoOption>> getDepartments();

  Future<List<UbigeoOption>> getProvinces(String department);

  Future<List<UbigeoOption>> getDistricts(String department, String province);
}

class AddressesRemoteDataSourceImpl implements AddressesRemoteDataSource {
  final ApiClient client;

  AddressesRemoteDataSourceImpl(this.client);

  dynamic _json(List<int> bytes) => jsonDecode(utf8.decode(bytes));

  @override
  Future<List<AddressModel>> getAddresses() async {
    final response = await client.get(ApiConstants.addressesEndpoint);
    return ((_json(response.bodyBytes) as Map<String, dynamic>)['direcciones']
            as List)
        .cast<Map<String, dynamic>>()
        .map(AddressModel.fromJson)
        .toList();
  }

  @override
  Future<void> save(AddressDraft draft, {int? id}) async {
    final body = {
      'direccion_completa': draft.fullAddress,
      // Debe ir como texto: con un número el servidor responde 422.
      'id_ubigeo': draft.ubigeoId,
      'referencia': draft.reference,
      // También al editar: el servidor pone `false` si no se envía y la
      // dirección dejaría de ser la predeterminada sin querer.
      'predeterminada': draft.isDefault,
    };

    if (id == null) {
      await client.post(ApiConstants.addressesEndpoint, body: body);
    } else {
      await client.put('${ApiConstants.addressesEndpoint}/$id', body: body);
    }
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('${ApiConstants.addressesEndpoint}/$id');
  }

  @override
  Future<void> setDefault(int id) async {
    await client.patch('${ApiConstants.addressesEndpoint}/$id/predeterminada');
  }

  Future<List<UbigeoOption>> _options(String endpoint) async {
    final response = await client.get(endpoint);
    return (_json(response.bodyBytes) as List)
        .cast<Map<String, dynamic>>()
        .map(ubigeoOptionFromJson)
        .toList();
  }

  @override
  Future<List<UbigeoOption>> getDepartments() =>
      _options(ApiConstants.departmentsEndpoint);

  @override
  Future<List<UbigeoOption>> getProvinces(String department) =>
      _options('${ApiConstants.provincesEndpoint}/$department');

  @override
  Future<List<UbigeoOption>> getDistricts(String department, String province) =>
      _options('${ApiConstants.districtsEndpoint}/$department/$province');
}
