import 'package:curio/core/services/content/sync.dart';
import 'package:curio/core/services/storage/storage.dart';
import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../nav/nav_screen.dart';

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  Future<void> _completeSetup(BuildContext context, WidgetRef ref) async {
    await ref.read(storageServiceProvider).setSetupCompleted(true);
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const NavScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncServiceProvider);
    final syncNotifier = ref.read(syncServiceProvider.notifier);

    // Listen for sync completion to navigate automatically
    ref.listen<SyncState>(syncServiceProvider, (previous, next) {
      if (next.syncProgress == 1.0 && !(previous?.isSyncing ?? false)) {
        _completeSetup(context, ref);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Initial Data Sync'),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCloudDownload,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const Gap(32),
              const Text(
                'Syncing Your Library',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const Gap(12),
              const Text(
                'We are fetching your playlists, liked videos, and subscriptions to personalize your experience.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const Gap(48),
              LinearPercentIndicator(
                percent: syncState.syncProgress.clamp(0.0, 1.0),
                lineHeight: 12,
                animation: true,
                animateFromLastPercent: true,
                alignment: MainAxisAlignment.center,
                barRadius: const Radius.circular(10),
                progressColor: Theme.of(context).primaryColor,
                backgroundColor: Theme.of(
                  context,
                ).dividerColor.withOpacity(0.2),
                trailing: Text(
                  '${(syncState.syncProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Gap(24),
              SizedBox(
                height: 40,
                child: Text(
                  syncState.syncStatus ?? 'Waiting to start...',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Gap(32),
              if (!syncState.isSyncing && syncState.syncProgress < 1.0)
                FilledButton.icon(
                  onPressed: () => syncNotifier.syncStructure(),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text('Start Sync'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              if (syncState.isSyncing)
                const SizedBox(
                  height: 48,
                  width: 48,
                  child: M3CircularProgressIndicator(strokeWidth: 3),
                ),
              if (!syncState.isSyncing && syncState.syncProgress == 1.0)
                FilledButton(
                  onPressed: () => _completeSetup(context, ref),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Continue to App'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
