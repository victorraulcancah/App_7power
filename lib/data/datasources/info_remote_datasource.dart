import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../domain/entities/info_entity.dart';
import '../models/info_model.dart';

abstract class InfoRemoteDataSource {
  Future<AboutModel> getAbout();

  Future<List<ShippingStepEntity>> getShippingSteps();

  Future<void> sendContact(ContactMessage message);

  Future<ClaimReceipt> submitClaim(ClaimDraft claim);

  Future<ClaimStatus> findClaim(String number);

  Future<List<ClaimStatus>> getMyClaims();
}

class InfoRemoteDataSourceImpl implements InfoRemoteDataSource {
  final ApiClient client;

  InfoRemoteDataSourceImpl(this.client);

  Map<String, dynamic> _map(List<int> bytes) =>
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

  @override
  Future<AboutModel> getAbout() async {
    final response = await client.get(ApiConstants.aboutEndpoint);
    return AboutModel.fromJson(
      _map(response.bodyBytes)['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<ShippingStepEntity>> getShippingSteps() async {
    final response = await client.get(ApiConstants.shippingStepsEndpoint);
    final steps = (_map(response.bodyBytes)['data'] as List)
        .cast<Map<String, dynamic>>()
        .where((s) => s['activo'] != false)
        .map(shippingStepFromJson)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return steps;
  }

  @override
  Future<void> sendContact(ContactMessage m) async {
    await client.post(ApiConstants.contactEndpoint, body: {
      'nombre': m.name.trim(),
      'email': m.email.trim(),
      'telefono': m.phone,
      'asunto': m.subject.trim(),
      'mensaje': m.message.trim(),
    });
  }

  @override
  Future<ClaimReceipt> submitClaim(ClaimDraft c) async {
    String? optional(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();

    final response = await client.post(ApiConstants.claimCreateEndpoint, body: {
      'consumidor_nombre': c.consumerName.trim(),
      'tipo_documento': c.documentType,
      'consumidor_dni': c.documentNumber.trim(),
      'consumidor_direccion': c.address.trim(),
      'consumidor_telefono': c.phone.trim(),
      'consumidor_email': c.email.trim(),
      'es_menor_edad': c.isMinor,
      if (c.isMinor) ...{
        'apoderado_nombre': c.guardianName?.trim(),
        'apoderado_dni': c.guardianDocument?.trim(),
        'apoderado_direccion': c.guardianAddress?.trim(),
        'apoderado_telefono': c.guardianPhone?.trim(),
        'apoderado_email': c.guardianEmail?.trim(),
      },
      'tipo_bien': c.goodType,
      'monto_reclamado': c.amount,
      'descripcion_bien': c.goodDescription.trim(),
      'tipo_comprobante': optional(c.voucherType),
      'numero_comprobante': optional(c.voucherNumber),
      // El backend espera solo la fecha (AAAA-MM-DD).
      'fecha_compra': c.purchaseDate?.toIso8601String().substring(0, 10),
      'codigo_pedido': optional(c.orderCode),
      'nombre_producto': optional(c.productName),
      'marca': optional(c.brand),
      'modelo': optional(c.model),
      'tipo_solicitud': c.requestType,
      'detalle_reclamo': c.detail.trim(),
      'pedido_consumidor': c.consumerRequest.trim(),
      'solucion_esperada': optional(c.expectedSolution),
      'otra_solucion': optional(c.otherSolution),
    });

    return claimReceiptFromJson(
      _map(response.bodyBytes)['reclamo'] as Map<String, dynamic>,
    );
  }

  @override
  Future<ClaimStatus> findClaim(String number) async {
    final response = await client.get(
      '${ApiConstants.claimLookupEndpoint}/${Uri.encodeComponent(number)}',
    );
    return claimStatusFromJson(
      _map(response.bodyBytes)['reclamo'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<ClaimStatus>> getMyClaims() async {
    final response = await client.get(ApiConstants.myClaimsEndpoint);
    // La respuesta trae también un `debug` con datos del usuario: se ignora.
    return ((_map(response.bodyBytes)['reclamos'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(claimStatusFromJson)
        .toList();
  }
}
