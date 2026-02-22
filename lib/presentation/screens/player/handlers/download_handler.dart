import 'package:curio/presentation/common/bottom_sheet_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import '../../../../core/services/content/downloader.dart';
import '../../../../core/services/storage/storage.dart';
import '../../download/widgets/download_configure_modal.dart';
import '../viewmodels/viewmodel.dart';

class PlayerDownloadHandler {
  static Future<void> handleDownload(
    BuildContext context,
    WidgetRef ref,
    PlayerState state,
  ) async {
    final videoId = state.metadata?.videoId;
    if (videoId == null) return;

    final url =
        state.metadata?.rawData['webpage_url'] ??
        'https://www.youtube.com/watch?v=$videoId';

    final result = await BottomSheetHelper.show<Map<String, dynamic>>(
      context: context,
      builder: (context, scrollController) {
        return DownloadConfigureModal(
          videoUrl: url,
          scrollController: scrollController,
        );
      },
    );

    if (result != null) {
      final downloadService = ref.read(downloadServiceProvider.notifier);
      downloadService.downloadVideo(
        url,
        formatId: result['formatId'],
        expectedSize: result['expectedSize'],
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download started...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
