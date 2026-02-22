import 'package:curio/core/services/yt_dlp/base.dart';

class AiPlatformService extends YtDlpBasePlatformService {
  static const String aiPath = 'com.curio.app.yt_dlp/ai';

  Future<String> initializeAI(String apiKey) async {
    final result = await invokeMethod<String>('initializeAI', {
      'apiKey': apiKey,
    });
    return result ?? '';
  }

  Future<String> generateSummary({
    required String transcript,
    String videoTitle = '',
    String playlistTitle = '',
    String language = 'en',
  }) async {
    final result = await invokeMethod<String>('generateSummary', {
      'transcript': transcript,
      'videoTitle': videoTitle,
      'playlistTitle': playlistTitle,
      'language': language,
    });
    return result ?? '';
  }
}
