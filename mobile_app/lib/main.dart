import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/music_repository.dart';
import 'data/services/audio_handler.dart';
import 'data/services/offline_storage_service.dart';
import 'data/services/subsonic_api_service.dart';
import 'state/audio_player_provider.dart';
import 'state/auth_provider.dart';
import 'state/music_provider.dart';
import 'ui/features/auth/login_screen.dart';
import 'ui/features/main_navigation/bottom_nav_shell.dart';

late final LocalSpotifyAudioHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge to edge immersive system bars
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // 1. Initialize Android MediaSession Audio Handler safely
  try {
    _audioHandler = await AudioService.init(
      builder: () => LocalSpotifyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.localspotify.app.channel.audio',
        androidNotificationChannelName: 'LocalSpotify Music Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'drawable/ic_stat_music',
      ),
    );
  } catch (e) {
    debugPrint('[AudioService] Init error, falling back to direct handler: $e');
    _audioHandler = LocalSpotifyAudioHandler();
  }

  // 2. Initialize Offline Storage & API Services
  final storageService = await OfflineStorageService.init();
  final apiService = SubsonicApiService();

  // 3. Initialize Repositories
  final authRepository = AuthRepository(
    apiService: apiService,
    storageService: storageService,
  );
  final musicRepository = MusicRepository(
    apiService: apiService,
    storageService: storageService,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authRepository: authRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => MusicProvider(musicRepository: musicRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => AudioPlayerProvider(
            audioHandler: _audioHandler,
            musicRepository: musicRepository,
          ),
        ),
      ],
      child: const LocalSpotifyApp(),
    ),
  );
}

class LocalSpotifyApp extends StatelessWidget {
  const LocalSpotifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'LocalSpotify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: auth.status == AuthStatus.checking || auth.status == AuthStatus.initial
          ? const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : auth.isAuthenticated
              ? const BottomNavShell()
              : const LoginScreen(),
    );
  }
}
