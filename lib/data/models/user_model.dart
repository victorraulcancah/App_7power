import 'dart:convert';

import '../../domain/entities/user_entity.dart';

/// Cliente tal como lo devuelve `POST /login` (campo `user`).
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
        photoUrl: json['foto_url']?.toString(),
        emailVerified: json['email_verified_at'] != null,
      );

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
      };

  String encode() => jsonEncode(toJson());

  factory UserModel.decode(String source) =>
      UserModel.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
