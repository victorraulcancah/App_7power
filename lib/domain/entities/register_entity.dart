/// Tipo de documento del registro (`/document-types`).
class DocumentTypeEntity {
  final int id;
  final String name;

  const DocumentTypeEntity({required this.id, required this.name});
}

/// Rompecabezas del registro. El servidor reparte una imagen en piezas y
/// devuelve el orden en que se muestran; el cliente debe dejar cada pieza en
/// su hueco (la pieza 0 en el hueco 0, y así).
class CaptchaChallenge {
  final String token;

  /// Ruta de la imagen relativa al dominio ("storage/captcha/a.png").
  final String imagePath;

  /// Índice de pieza que hay en cada hueco, tal como se muestra al empezar.
  final List<int> order;
  final int columns;
  final int rows;

  const CaptchaChallenge({
    required this.token,
    required this.imagePath,
    required this.order,
    required this.columns,
    required this.rows,
  });
}

/// Datos del formulario de registro.
class RegisterDraft {
  final String firstNames;
  final String lastNames;
  final String email;
  final String password;
  final String passwordConfirmation;
  final String? phone;
  final int documentTypeId;
  final String documentNumber;

  const RegisterDraft({
    required this.firstNames,
    required this.lastNames,
    required this.email,
    required this.password,
    required this.passwordConfirmation,
    required this.documentTypeId,
    required this.documentNumber,
    this.phone,
  });
}
