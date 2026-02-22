import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:curio/core/services/content/downloader.dart';
import 'package:curio/domain/entities/download_task.dart';
import '../../common/frosted_container.dart';
import '../../common/bottom_sheet_helper.dart';
import 'widgets/download_task_card.dart';
import 'offline_player_screen.dart';

class DownloadManagerScreen extends ConsumerStatefulWidget {
  const DownloadManagerScreen({super.key});

  @override
  ConsumerState<DownloadManagerScreen> createState() =>
      _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends ConsumerState<DownloadManagerScreen> {
  final TextEditingController _urlController = TextEditingController();
  String _selectedQuality = 'best'; // Default

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _showQualitySelector() {
    BottomSheetHelper.show(
      context: context,
      title: 'Select Quality',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...['best', '1080p', '720p', '480p', 'audio only'].map((quality) {
              return ListTile(
                title: Text(quality == 'best' ? 'Best Available' : quality),
                leading: HugeIcon(
                  icon: quality == _selectedQuality
                      ? HugeIcons.strokeRoundedFavourite
                      : HugeIcons.strokeRoundedHome02,
                  color: quality == _selectedQuality
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  size: 20,
                ),
                onTap: () {
                  setState(() {
                    _selectedQuality = quality;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getFormatString(String quality) {
    switch (quality) {
      case '1080p':
        return 'bestvideo[height<=1080]+bestaudio/best[height<=1080]';
      case '720p':
        return 'bestvideo[height<=720]+bestaudio/best[height<=720]';
      case '480p':
        return 'bestvideo[height<=480]+bestaudio/best[height<=480]';
      case 'audio only':
        return 'bestaudio/best';
      case 'best':
      default:
        return 'bestvideo+bestaudio/best';
    }
  }

  void _openPlayer(String filePath, String title) {
    if (filePath.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OfflinePlayerScreen(filePath: filePath, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadTasks = ref.watch(downloadServiceProvider);
    final downloadService = ref.read(downloadServiceProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedFolderOpen,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {
              // Open download folder
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Add New Download Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FrostedContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            hintText: 'Paste YouTube URL',
                            border: InputBorder.none,
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedLink01,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const Gap(8),
                      IconButton.filled(
                        onPressed: () {
                          if (_urlController.text.isNotEmpty) {
                            downloadService.downloadVideo(
                              _urlController.text,
                              formatId: _getFormatString(_selectedQuality),
                            );
                            _urlController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Download started')),
                            );
                          }
                        },
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedAdd01,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const Gap(12),
                  Row(
                    children: [
                      ActionChip(
                        avatar: HugeIcon(
                          icon: HugeIcons.strokeRoundedSettings02,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 16,
                        ),
                        label: Text(
                          _selectedQuality == 'best'
                              ? 'Best Quality'
                              : _selectedQuality,
                        ),
                        onPressed: _showQualitySelector,
                      ),
                      const Gap(8),
                      ActionChip(
                        avatar: HugeIcon(
                          icon: HugeIcons.strokeRoundedFolderOpen,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 16,
                        ),
                        label: const Text('Default Folder'),
                        onPressed: () {
                          // Show folder chooser
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Active Downloads List
          Expanded(
            child: downloadTasks.isEmpty
                ? const Center(child: Text('No active downloads'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: downloadTasks.length,
                    itemBuilder: (context, index) {
                      // Show newest first
                      final task =
                          downloadTasks[downloadTasks.length - 1 - index];
                      return DownloadTaskCard(
                        task: task,
                        onPlay: () =>
                            _openPlayer(task.filePath ?? '', task.title),
                        onExternalPlay: () {
                          // T Implement external player
                        },
                        onRetry: () => downloadService.retryDownload(task.id),
                        onDelete: () =>
                            downloadService.deleteDownloadTask(task.id),
                        onCancel: () => downloadService.cancelDownload(task.id),
                        onPauseResume: () {
                          if (task.status == DownloadStatus.paused) {
                            downloadService.resumeDownload(task.id);
                          } else {
                            downloadService.pauseDownload(task.id);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
