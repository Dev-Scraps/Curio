import 'dart:io';

/// Utility to extract YouTube channel ID from Netscape cookies
class CookieParser {
  /// Extract channel ID from YouTube cookies file
  /// Returns null if channel ID cannot be determined
  static Future<String?> extractChannelId(String cookiePath) async {
    try {
      final file = File(cookiePath);
      if (!await file.exists()) {
        print('CookieParser: Cookie file not found at $cookiePath');
        return null;
      }

      final content = await file.readAsString();
      
      // Look for SAPISID which typically contains user identity info
      // Format: domain \t flag \t path \t secure \t expiration \t name \t value
      final lines = content.split('\n');
      
      for (final line in lines) {
        if (line.trim().isEmpty || line.startsWith('#')) continue;
        
        final parts = line.split('\t');
        if (parts.length >= 7) {
          final cookieName = parts[5];
          final cookieValue = parts[6];
          
          // SAPISID or __Secure-3PAPISID often contain channel-related data
          if (cookieName == 'SAPISID' || cookieName == '__Secure-1PAPISID') {
            print('CookieParser: Found auth cookie: $cookieName');
          }
        }
      }
      
      // Alternative: Use yt-dlp to extract channel ID from a known endpoint
      // This is more reliable than parsing cookies directly
      print('CookieParser: Will use yt-dlp to determine channel ID');
      return null; // Let yt-dlp handle the extraction via a /feed/library call
      
    } catch (e) {
      print('CookieParser: Error reading cookies: $e');
      return null;
    }
  }
  
  /// Extract channel ID by making a yt-dlp call to a known authenticated endpoint
  /// Returns the channel ID or null
  static Future<String?> extractChannelIdViaYtDlp(
    String cookiePath,
    Future<Map<String, dynamic>> Function(String, {String? cookiePath}) ytDlpFetch,
  ) async {
    try {
      // Use /feed/library which requires auth and contains channel info
      final result = await ytDlpFetch(
        'https://www.youtube.com/feed/library',
        cookiePath: cookiePath,
      );
      
      // Extract channel ID from uploader_id or channel_id field
      final channelId = result['channel_id'] as String? ?? 
                       result['uploader_id'] as String? ??
                       result['channel'] as String?;
      
      if (channelId != null && channelId.isNotEmpty) {
        print('CookieParser: Extracted channel ID: $channelId');
        return channelId;
      }
      
      print('CookieParser: Could not extract channel ID from library feed');
      return null;
    } catch (e) {
      print('CookieParser: Error extracting channel ID via yt-dlp: $e');
      return null;
    }
  }
}
