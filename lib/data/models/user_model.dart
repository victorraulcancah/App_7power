import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../domain/entities/user_entity.dart';

/// Cliente tal como lo devuelve `POST /login` (campo `user`) o `GET /user`.
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.fullName,
    required super.email,
    super.firstNames,
    super.lastNames,
    super.phone,
    super.documentType,
    super.documentNumber,
    super.photoUrl,
    super.emailVerified,
    super.erpCode,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: (json['id'] as num).toInt(),
        fullName: json['nombre_completo']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        firstNames: json['nombres']?.toString(),
        lastNames: json['apellidos']?.toString(),
        phone: json['telefono']?.toString(),
        documentType: json['tipo_documento']?.toString(),
        documentNumber: json['numero_documento']?.toString(),
        photoUrl: _photoUrl(json['foto_url'] ?? json['foto']),
        emailVerified: json['email_verified_at'] != null,
        erpCode: json['codigo_erp']?.toString(),
      );

  /// La foto llega como ruta ("/storage/clientes/a.jpg") o como URL, y el login
  /// la deja duplicada ("/storage/clientes//storage/clientes/a.jpg"): se
  /// normaliza a una URL absoluta.
  static String? _photoUrl(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;

    var url = value.replaceFirst(
      '/storage/clientes//storage/clientes/',
      '/storage/clientes/',
    );
    if (!url.startsWith('http')) {
      url = '${ApiConstants.baseDomain}${url.startsWith('/') ? '' : '/'}$url';
    }
    return url;
  }

  /// Para guardarlo en el dispositivo y recuperarlo al abrir la app.
  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre_completo': fullName,
        'email': email,
        'nombres': firstNames,
        'apellidos': lastNames,
        'telefono': phone,
        'tipo_documento': documentType,
        'numero_documento': documentNumber,
        'foto_url': photoUrl,
        'email_verified_at': emailVerified ? 'verificado' : null,
        'codigo_erp': erpCode,
      };

  String encode() => jsonEncode(toJson());

  factory UserModel.decode(String source) =>
      UserModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  factory UserModel.fromEntity(UserEntity e) => UserModel(
        id: e.id,
        fullName: e.fullName,
        email: e.email,
        firstNames: e.firstNames,
        lastNames: e.lastNames,
        phone: e.phone,
        documentType: e.documentType,
        documentNumber: e.documentNumber,
        photoUrl: e.photoUrl,
        emailVerified: e.emailVerified,
        erpCode: e.erpCode,
      );
}
