import '../models/user_session.dart';
import '../services/subsonic_api_service.dart';
import '../services/offline_storage_service.dart';
import '../../core/utils/md5_hasher.dart';

class AuthRepository {
  final SubsonicApiService _apiService;
  final OfflineStorageService _storageService;

  AuthRepository({
    required SubsonicApiService apiService,
    required OfflineStorageService storageService,
  })  : _apiService = apiService,
        _storageService = storageService;

  UserSession? get currentSession => _apiService.session;

  UserSession? getSavedSession() {
    final saved = _storageService.getSavedSession();
    if (saved != null && saved.serverUrl.isNotEmpty && saved.username.isNotEmpty) {
      _apiService.updateSession(saved);
      return saved;
    }
    return null;
  }

  Future<UserSession?> tryAutoLogin() async {
    return getSavedSession();
  }

  Future<UserSession> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final ok = await _apiService.ping(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );

    if (!ok) {
      throw Exception('Could not connect to Subsonic server. Check URL and credentials.');
    }

    final salt = Md5Hasher.generateSalt();
    final token = Md5Hasher.hashToken(password, salt);

    var cleanUrl = serverUrl.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }
    while (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    final session = UserSession(
      serverUrl: cleanUrl,
      username: username,
      token: token,
      salt: salt,
    );

    _apiService.updateSession(session);
    await _storageService.saveSession(session);
    return session;
  }

  Future<void> logout() async {
    _apiService.clearSession();
    await _storageService.clearSession();
  }
}
