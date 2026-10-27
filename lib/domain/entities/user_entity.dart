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
  });

  /// Iniciales para el avatar cuando no hay foto.
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}
