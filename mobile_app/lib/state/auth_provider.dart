import 'package:flutter/foundation.dart';
import '../data/models/user_session.dart';
import '../data/repositories/auth_repository.dart';

enum AuthStatus { initial, checking, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthStatus _status = AuthStatus.initial;
  UserSession? _session;
  String? _errorMessage;

  AuthProvider({required AuthRepository authRepository})
      : _authRepository = authRepository {
    checkSavedSession();
  }

  AuthStatus get status => _status;
  UserSession? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _session != null;

  Future<void> checkSavedSession() async {
    _status = AuthStatus.checking;
    notifyListeners();

    try {
      final saved = await _authRepository.tryAutoLogin();
      if (saved != null) {
        _session = saved;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    _status = AuthStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _authRepository.login(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _session = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
