import '../constants/app_constants.dart';

class Validators {
  static String? required(String? value, [String field = 'Este campo']) {
    if (value == null || value.trim().isEmpty) return '$field es requerido';
    return null;
  }

  static String? email(String? value) {
    final empty = required(value, 'El correo');
    if (empty != null) return empty;
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value!.trim())) return 'Correo no válido';
    return null;
  }

  static String? password(String? value) {
    final empty = required(value, 'La contraseña');
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
