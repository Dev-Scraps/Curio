import 'package:curio/presentation/common/sync_progress_bar.dart';
import 'package:curio/presentation/widgets/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../liked/liked_screen.dart';
import '../download/download_screen.dart';
import '../ai/dashboard_screen.dart';

class NavScreen extends ConsumerStatefulWidget {
  const NavScreen({super.key});

  @override
  ConsumerState<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends ConsumerState<NavScreen> {
  int _currentIndex = 0;

  // Tab screens
  List<Widget> get _screens => const [
    HomeScreen(),
    LikedScreen(),
    DashboardScreen(),
    DownloadScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          const SyncProgressBar(),
          Container(
            height: 80,
            padding: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / 5;

                  return Row(
                    children: [
                      _buildNavItem(itemWidth, Symbols.home_rounded, 'Home', 0),
                      _buildNavItem(
                        itemWidth,
                        Symbols.favorite_rounded,
                        'Liked',
                        1,
                      ),
                      _buildNavItem(
                        itemWidth,
                        Symbols.psychology_rounded,
                        'AI',
                        2,
                      ),
                      _buildNavItem(
                        itemWidth,
                        Symbols.download_rounded,
                        'Downloads',
                        3,
                      ),
                      _buildNavItem(
                        itemWidth,
                        Symbols.settings_rounded,
                        'Settings',
                        4,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(double width, IconData symbol, String label, int index) {
    return SizedBox(
      width: width,
      child: _NavIcon(
        symbol: symbol,
        label: label,
        isSelected: _currentIndex == index,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData symbol;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.symbol,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.onSecondaryContainer;
    final unselectedColor = theme.colorScheme.onSurfaceVariant;
    final selectedBg = theme.colorScheme.secondaryContainer;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: isSelected ? 60 : 0,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected ? selectedBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  // Fix: Using TweenAnimationBuilder with TextStyle variations
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
                    duration: const Duration(milliseconds: 250),
                    builder: (context, fillValue, child) {
                      return Text(
                        String.fromCharCode(symbol.codePoint),
                        style: TextStyle(
                          inherit: false,
                          color: isSelected ? selectedColor : unselectedColor,
                          fontSize: 26,
                          fontFamily: symbol.fontFamily,
                          package: symbol.fontPackage,
                          fontVariations: [
                            FontVariation('FILL', fillValue),
                            FontVariation('wght', isSelected ? 500 : 400),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? selectedColor : unselectedColor,
            ),
          ),
        ],
      ),
    );
  }
}
