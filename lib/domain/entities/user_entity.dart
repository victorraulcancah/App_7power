/// Cliente de la tienda con sesión iniciada.
class UserEntity {
  final int id;
  final String fullName;
  final String email;
  final String? firstNames;
  final String? lastNames;
  final String? phone;
  final String? documentType;
  final String? documentNumber;
  final String? photoUrl;
  final bool emailVerified;

  /// Código del cliente en el ERP, si su cuenta está vinculada.
  final String? erpCode;

  /// Nombre y documento del cliente **del ERP** al que está vinculada la cuenta.
  /// Son los datos a nombre de quien se emiten los comprobantes, y pueden ser
  /// distintos de los que el cliente puso al registrarse. Null si no está
  /// vinculada (o si todavía no se leyeron).
  final String? holderName;
  final String? holderDocument;

  const UserEntity({
    required this.id,
    required this.fullName,
    required this.email,
    this.firstNames,
    this.lastNames,
    this.phone,
    this.documentType,
    this.documentNumber,
    this.photoUrl,
    this.emailVerified = false,
    this.erpCode,
    this.holderName,
    this.holderDocument,
  });

  /// Iniciales para el avatar cuando no hay foto.
  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  /// Con la cuenta vinculada, el nombre del cliente del ERP; si no, el del
  /// cliente registrado en la tienda.
  String get displayName =>
      (erpCode != null && (holderName?.trim().isNotEmpty ?? false))
          ? holderName!.trim()
          : fullName;

  /// Cómo se saluda al cliente ("Hola, …"):
  /// - empresa (RUC 20): la razón social sin "SAC", "EIRL", etc.
  ///   ("GRUPO GM IMPORTACIONES SAC" → "Grupo GM Importaciones");
  /// - persona: un nombre y un apellido ("Anthony Gustavo").
  String get greetingName {
    final document = displayDocument ?? '';
    if (RegExp(r'^20\d{9}$').hasMatch(document)) {
      return _companyName(displayName);
    }
    return _personName();
  }

  static final _legalSuffix = RegExp(
    r'[\s,.]+(S\.?\s?A\.?\s?C\.?|E\.?\s?I\.?\s?R\.?\s?L\.?|S\.?\s?R\.?\s?L\.?|'
    r'S\.?\s?C\.?\s?R\.?\s?L\.?|S\.?\s?A\.?\s?A\.?|S\.?\s?A\.?)\s*$',
    caseSensitive: false,
  );

  static String _companyName(String name) {
    var result = name.trim();
    // Por si lleva más de una forma legal seguida.
    for (var i = 0; i < 3; i++) {
      final next = result.replaceFirst(_legalSuffix, '').trim();
      if (next == result || next.isEmpty) break;
      result = next;
    }
    final words = result.split(RegExp(r'\s+'));
    return [
      for (final w in words)
        w.length <= 3 ? w : w[0].toUpperCase() + w.substring(1).toLowerCase(),
    ].join(' ');
  }

  String _personName() {
    String cap(String w) =>
        w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase();
    List<String> words(String? text) =>
        (text ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // Con el nombre y el apellido por separado, el primero de cada uno.
    final names = words(firstNames);
    final surnames = words(lastNames);
    if (names.isNotEmpty && surnames.isNotEmpty) {
      return '${cap(names.first)} ${cap(surnames.first)}';
    }
    // Si solo hay el nombre completo: el primer nombre y el primer apellido
    // (con cuatro palabras o más, el apellido es la tercera).
    final all = words(displayName);
    if (all.length < 2) return all.map(cap).join(' ');
    final surname = all.length >= 4 ? all[2] : all[1];
    return '${cap(all.first)} ${cap(surname)}';
  }

  /// El documento que corresponde a [displayName]: el del ERP si está vinculada,
  /// si no el del registro. Los provisionales de las cuentas creadas con Google
  /// (`GOOGLE_...`) no son un documento real y no se muestran.
  String? get displayDocument {
    final linked = erpCode != null && (holderDocument?.trim().isNotEmpty ?? false);
    final value = (linked ? holderDocument : documentNumber)?.trim();
    if (value == null || value.isEmpty || value.toUpperCase().startsWith('GOOGLE_')) {
      return null;
    }
    return value;
  }

  /// "RUC" para 11 dígitos, "DNI" para 8; si no, el tipo con que se registró.
  String get displayDocumentLabel {
    final value = displayDocument ?? '';
    if (RegExp(r'^\d{11}$').hasMatch(value)) return 'RUC';
    if (RegExp(r'^\d{8}$').hasMatch(value)) return 'DNI';
    return documentType ?? 'Documento';
  }

  /// Una copia con otro celular y/o otra foto. [removePhoto] la quita. Los datos
  /// del titular se cambian con [holderName] y [holderDocument]; [clearHolder]
  /// los borra (la cuenta ya no está vinculada).
  UserEntity copyWith({
    String? phone,
    String? photoUrl,
    bool removePhoto = false,
    String? holderName,
    String? holderDocument,
    bool clearHolder = false,
  }) =>
      UserEntity(
        id: id,
        fullName: fullName,
        email: email,
        firstNames: firstNames,
        lastNames: lastNames,
        phone: phone ?? this.phone,
        documentType: documentType,
        documentNumber: documentNumber,
        photoUrl: removePhoto ? null : (photoUrl ?? this.photoUrl),
        emailVerified: emailVerified,
        erpCode: erpCode,
        holderName: clearHolder ? null : (holderName ?? this.holderName),
        holderDocument: clearHolder ? null : (holderDocument ?? this.holderDocument),
      );
}
