import 'package:flutter/foundation.dart';

import '../../domain/entities/info_entity.dart';
import '../../domain/usecases/info_usecases.dart';
import 'load_status.dart';

/// "Nosotros", cómo funciona el envío, contacto y libro de reclamaciones.
class InfoProvider extends ChangeNotifier {
  final GetAboutUseCase getAboutUseCase;
  final GetShippingStepsUseCase getShippingStepsUseCase;
  final SendContactUseCase sendContactUseCase;
  final SubmitClaimUseCase submitClaimUseCase;
  final FindClaimUseCase findClaimUseCase;

  InfoProvider({
    required this.getAboutUseCase,
    required this.getShippingStepsUseCase,
    required this.sendContactUseCase,
    required this.submitClaimUseCase,
    required this.findClaimUseCase,
  });

  LoadStatus _aboutStatus = LoadStatus.initial;
  AboutEntity? _about;
  String _aboutError = '';

  LoadStatus _stepsStatus = LoadStatus.initial;
  List<ShippingStepEntity> _steps = const [];
  String _stepsError = '';

  LoadStatus get aboutStatus => _aboutStatus;
  AboutEntity? get about => _about;
  String get aboutError => _aboutError;

  LoadStatus get stepsStatus => _stepsStatus;
  List<ShippingStepEntity> get steps => _steps;
  String get stepsError => _stepsError;

  Future<void> loadAbout() async {
    _aboutStatus = LoadStatus.loading;
    notifyListeners();

    final result = await getAboutUseCase();
    result.fold(
      (f) {
        _aboutError = f.message;
        _aboutStatus = LoadStatus.error;
      },
      (about) {
        _about = about;
        _aboutStatus = LoadStatus.loaded;
      },
    );
    notifyListeners();
  }

  Future<void> loadSteps() async {
    _stepsStatus = LoadStatus.loading;
    notifyListeners();

    final result = await getShippingStepsUseCase();
    result.fold(
      (f) {
        _stepsError = f.message;
        _stepsStatus = LoadStatus.error;
      },
      (steps) {
        _steps = steps;
        _stepsStatus = LoadStatus.loaded;
      },
    );
    notifyListeners();
  }

  /// Devuelve null si se envió, o el motivo por el que no.
  Future<String?> sendContact(ContactMessage message) async {
    final result = await sendContactUseCase(message);
    return result.fold((f) => f.message, (_) => null);
  }

  /// Devuelve la constancia, o el motivo del error en `error`.
  Future<({ClaimReceipt? receipt, String? error})> submitClaim(
    ClaimDraft claim,
  ) async {
    final result = await submitClaimUseCase(claim);
    return result.fold(
      (f) => (receipt: null, error: f.message),
      (r) => (receipt: r, error: null),
    );
  }

  Future<({ClaimStatus? status, String? error})> findClaim(String number) async {
    final result = await findClaimUseCase(number);
    return result.fold(
      (f) => (status: null, error: f.message),
      (s) => (status: s, error: null),
    );
  }
}
