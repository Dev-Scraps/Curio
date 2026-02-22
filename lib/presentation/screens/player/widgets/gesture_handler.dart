import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import '../viewmodels/viewmodel.dart';

class PlayerGestureHandler extends ConsumerWidget {
  final Widget child;
  final PlayerState state;
  final PlayerViewModel viewModel;
  final VoidCallback onToggleControls;

  const PlayerGestureHandler({
    super.key,
    required this.child,
    required this.state,
    required this.viewModel,
    required this.onToggleControls,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onToggleControls,
      onDoubleTapDown: (details) => _handleDoubleTap(context, details),
      child: Container(
        color: Colors.transparent,
        child: Center(child: child),
      ),
    );
  }

  void _handleDoubleTap(BuildContext context, TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;

    if (tapPosition < screenWidth / 2) {
      // Left side - seek backward 10s
      final newPos = state.position - const Duration(seconds: 10);
      viewModel.seekTo(newPos.isNegative ? Duration.zero : newPos);
      _showSeekFeedback(context, isForward: false);
    } else {
      // Right side - seek forward 10s
      final newPos = state.position + const Duration(seconds: 10);
      viewModel.seekTo(newPos);
      _showSeekFeedback(context, isForward: true);
    }
  }

  void _showSeekFeedback(BuildContext context, {required bool isForward}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Center(
        child:
            Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: isForward
                            ? HugeIcons.strokeRoundedGoForward10Sec
                            : HugeIcons.strokeRoundedGoBackward10Sec,
                        color: Colors.white,
                        size: 48,
                      ),
                      const Gap(8),
                      Text(
                        isForward ? '+10s' : '-10s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
                .animate()
                .scale(
                  duration: 200.ms,
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  curve: Curves.easeOut,
                )
                .then()
                .fadeOut(duration: 300.ms, delay: 200.ms),
      ),
    );

    overlay.insert(overlayEntry);

    // Remove after animation completes
    Future.delayed(const Duration(milliseconds: 700), () {
      overlayEntry.remove();
    });
  }
}
