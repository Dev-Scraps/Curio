import 'package:curio/core/services/storage/database.dart';
import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/video.dart';
import '../player/player_screen.dart';

class OfflineScreen extends ConsumerWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final databaseService = ref.watch(databaseServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Library'), centerTitle: false),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: databaseService.getVideos(isDownloaded: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: M3CircularProgressIndicator());
          }

          final videosData = snapshot.data ?? [];

          if (videosData.isEmpty) {
            return const Center(child: Text('No downloaded videos'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: videosData.length,
            itemBuilder: (context, index) {
              final video = Video.fromJson(videosData[index]);
              return Card(
                child: ListTile(
                  leading: video.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          video.thumbnailUrl,
                          width: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const HugeIcon(
                                icon: HugeIcons.strokeRoundedPlay,
                                color: Colors.grey,
                                size: 24,
                              ),
                        )
                      : const HugeIcon(
                          icon: HugeIcons.strokeRoundedPlay,
                          color: Colors.grey,
                          size: 24,
                        ),
                  title: Text(video.title),
                  subtitle: Text(video.channelName),
                  trailing: const HugeIcon(
                    icon: HugeIcons.strokeRoundedPlay,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(video: video),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
