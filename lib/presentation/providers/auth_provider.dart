import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

enum AuthStatus { initial, unauthenticated, loading, authenticated }

class AuthProvider extends ChangeNotifier {
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final RestoreSessionUseCase restoreSessionUseCase;
  final AuthRepository repository;

  StreamSubscription<void>? _expiredSub;

  AuthProvider({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.restoreSessionUseCase,
    required this.repository,
  }) {
    _expiredSub = repository.onSessionExpired.listen((_) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Tu sesión expiró. Inicia sesión de nuevo.';
      notifyListeners();
    });
  }

  AuthStatus _status = AuthStatus.initial;
  UserEntity? _user;
  String _errorMessage = '';

  AuthStatus get status => _status;
  UserEntity? get user => _user;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  Future<void> restore() async {
    final result = await restoreSessionUseCase();
    result.fold(
      (_) => _status = AuthStatus.unauthenticated,
      (user) {
        _user = user;
        _status =
            user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
      },
    );
    notifyListeners();
  }

  /// Devuelve true si el inicio de sesión fue correcto; si no, el motivo queda
  /// en [errorMessage].
  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = '';
    notifyListeners();

    final result = await loginUseCase(email, password);
    final ok = result.fold(
      (failure) {
        _errorMessage = failure.message;
        _status = AuthStatus.unauthenticated;
        return false;
      },
      (user) {
        _user = user;
        _status = AuthStatus.authenticated;
        return true;
      },
    );
    notifyListeners();
    return ok;
  }

  Future<void> logout() async {
    await logoutUseCase();
    _user = null;
    _errorMessage = '';
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    _expiredSub?.cancel();
    super.dispose();
  }
}
