import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'skeleton_loader.dart';

class PlaylistCardSkeleton extends StatelessWidget {
  const PlaylistCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 67.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              child: SkeletonLoader(),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    child: SkeletonLoader(),
                  ),
                ),
                const Gap(6),
                Container(
                  height: 14,
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    child: SkeletonLoader(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
