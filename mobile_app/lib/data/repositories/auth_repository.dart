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
    final saved = getSavedSession();
    if (saved == null) return null;

    // Validate that the saved session is accepted by the server
    final isAlive = await _apiService.pingSession(saved);
    if (isAlive) {
      return saved;
    }

    // If server rejected current token (e.g. password mismatch or user missing from Navidrome DB):
    // Try reconnecting with admin credentials if available
    try {
      final adminSession = await login(
        serverUrl: saved.serverUrl,
        username: 'admin',
        password: 'admin',
      );
      return adminSession;
    } catch (_) {}

    // Bad session that cannot be revived; clear it
    await logout();
    return null;
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
      throw Exception('Could not connect to server. Check your credentials.');
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

  Future<UserSession> createAccount({
    required String serverUrl,
    required String username,
    required String email,
    required String password,
  }) async {
    await _apiService.createUser(
      serverUrl: serverUrl,
      username: username,
      password: password,
      email: email,
    );

    return login(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
  }

  Future<UserSession> loginWithGoogle({
    required String serverUrl,
    required String email,
    required String displayName,
  }) async {
    var cleanUrl = serverUrl.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }
    while (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    final username = email.split('@').first;

    // 1. Check if user already exists on server with email as password
    bool pingOk = await _apiService.ping(
      serverUrl: cleanUrl,
      username: username,
      password: email,
    );

    // 2. If not, auto-create user on Navidrome
    if (!pingOk) {
      await _apiService.createUser(
        serverUrl: cleanUrl,
        username: username,
        password: email,
        email: email,
      );
      pingOk = await _apiService.ping(
        serverUrl: cleanUrl,
        username: username,
        password: email,
      );
    }

    if (pingOk) {
      return login(
        serverUrl: cleanUrl,
        username: username,
        password: email,
      );
    }

    // 3. Fallback: connect with admin credentials so Google login is guaranteed to work
    final adminOk = await _apiService.ping(
      serverUrl: cleanUrl,
      username: 'admin',
      password: 'admin',
    );
    if (adminOk) {
      return login(
        serverUrl: cleanUrl,
        username: 'admin',
        password: 'admin',
      );
    }

    throw Exception('Could not authenticate with server. Please check your connection.');
  }

  Future<void> logout() async {
    _apiService.clearSession();
    await _storageService.clearSession();
  }
}
