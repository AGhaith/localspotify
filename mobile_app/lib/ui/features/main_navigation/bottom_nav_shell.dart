import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../offline/offline_screen.dart';
import '../player/mini_player_bar.dart';
import '../search/search_screen.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    OfflineScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final player = context.watch<AudioPlayerProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Docked Mini-Player + Custom Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (player.hasTrack) const MiniPlayerBar(),
                Container(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset > 0 ? bottomInset : 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF08080C),
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        offset: Offset(0, -4),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, 'Home', Icons.home_rounded, Icons.home_outlined),
                      _buildNavItem(1, 'Search', Icons.search_rounded, Icons.search_outlined),
                      _buildNavItem(2, 'Library', Icons.library_music_rounded, Icons.library_music_outlined),
                      _buildNavItem(3, 'Offline', Icons.download_for_offline_rounded, Icons.download_for_offline_outlined),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData activeIcon, IconData inactiveIcon) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? AppColors.primary : AppColors.textMuted,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isActive ? AppColors.primary : AppColors.textMuted,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
