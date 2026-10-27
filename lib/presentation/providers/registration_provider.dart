import 'package:flutter/foundation.dart';

import '../../domain/entities/register_entity.dart';
import '../../domain/usecases/registration_usecases.dart';

/// Registro de clientes y recuperación de contraseña.
class RegistrationProvider extends ChangeNotifier {
  final GetDocumentTypesUseCase getDocumentTypesUseCase;
  final GetCaptchaUseCase getCaptchaUseCase;
  final VerifyCaptchaUseCase verifyCaptchaUseCase;
  final RegisterUseCase registerUseCase;
  final ForgotPasswordUseCase forgotPasswordUseCase;

  RegistrationProvider({
    required this.getDocumentTypesUseCase,
    required this.getCaptchaUseCase,
    required this.verifyCaptchaUseCase,
    required this.registerUseCase,
    required this.forgotPasswordUseCase,
  });

  List<DocumentTypeEntity> _documentTypes = const [];
  bool _loadingTypes = false;

  List<DocumentTypeEntity> get documentTypes => _documentTypes;
  bool get loadingTypes => _loadingTypes;

  /// Tipos de documento. Si no cargan se usan los de la web de siempre, para
  /// que el formulario no quede bloqueado.
  Future<void> loadDocumentTypes() async {
    if (_documentTypes.isNotEmpty) return;
    _loadingTypes = true;
    notifyListeners();

    final result = await getDocumentTypesUseCase();
    _documentTypes = result.fold(
      (_) => const [
        DocumentTypeEntity(id: 1, name: 'DNI'),
        DocumentTypeEntity(id: 6, name: 'RUC'),
        DocumentTypeEntity(id: 3, name: 'Carnet de Extranjería'),
        DocumentTypeEntity(id: 2, name: 'Pasaporte'),
      ],
      (types) => types,
    );
    _loadingTypes = false;
    notifyListeners();
  }

  Future<({CaptchaChallenge? challenge, String? error})> newCaptcha() async {
    final result = await getCaptchaUseCase();
    return result.fold(
      (f) => (challenge: null, error: f.message),
      (c) => (challenge: c, error: null),
    );
  }

  /// null si el orden es correcto, o el motivo (incluido "caducó").
  Future<String?> verifyCaptcha(String token, List<int> order) async {
    final result = await verifyCaptchaUseCase(token, order);
    return result.fold((f) => f.message, (_) => null);
  }

  /// Devuelve el mensaje de éxito en `message`, o el motivo en `error`.
  Future<({String? message, String? error})> register(
    RegisterDraft draft,
    String captchaToken,
  ) async {
    final result = await registerUseCase(draft, captchaToken);
    return result.fold(
      (f) => (message: null, error: f.message),
      (m) => (message: m, error: null),
    );
  }

  Future<({String? message, String? error})> forgotPassword(String email) async {
    final result = await forgotPasswordUseCase(email);
    return result.fold(
      (f) => (message: null, error: f.message),
      (m) => (message: m, error: null),
    );
  }
}
