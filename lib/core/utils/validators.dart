import '../constants/app_constants.dart';

class Validators {
  /// [field] va precedido de su artículo ("tu correo", "tu contraseña") para
  /// que el mensaje concuerde en género: "Ingresa tu correo".
  static String? required(String? value, [String field = 'este dato']) {
    if (value == null || value.trim().isEmpty) return 'Ingresa $field';
    return null;
  }

  static String? email(String? value) {
    final empty = required(value, 'tu correo');
    if (empty != null) return empty;
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value!.trim())) return 'Correo no válido';
    return null;
  }

  static String? password(String? value) {
    final empty = required(value, 'tu contraseña');
    if (empty != null) return empty;
    if (value!.length < AppConstants.minPasswordLength) {
      return 'Mínimo ${AppConstants.minPasswordLength} caracteres';
    }
    if (value.length > AppConstants.maxPasswordLength) {
      return 'Máximo ${AppConstants.maxPasswordLength} caracteres';
    }
    return null;
  }
}
