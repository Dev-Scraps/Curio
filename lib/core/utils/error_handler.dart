/// Error handling utility for transforming technical errors into user-friendly messages
class ErrorHandler {
  /// Convert an error into a user-friendly message
  static String getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // No cookies / authentication errors
    if (errorString.contains('no active account') ||
        errorString.contains('no cookies')) {
      return 'Please login with your YouTube account first.\nGo to Settings → Add Account.';
    }

    // Cookie/authentication expired
    if (errorString.contains('sign in') ||
        errorString.contains('login') ||
        errorString.contains('authentication') ||
        errorString.contains('unauthorized') ||
        errorString.contains('401')) {
      return 'Your session has expired.\nPlease login again in Settings.';
    }

    // Network errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket') ||
        errorString.contains('timeout')) {
      return 'Network connection failed.\nCheck your internet connection and try again.';
    }

    // Format availability errors
    if (errorString.contains('requested format is not available')) {
      return 'Selected video quality is not available.\nPlease try a different quality option.';
    }

    if (errorString.contains('signature solving failed')) {
      return 'Video format extraction failed.\nPlease try a different quality or try again later.';
    }

    // Instagram specific errors
    if (errorString.contains('there is no video in this post')) {
      return 'This Instagram post doesn\'t contain a video.\nOnly video posts can be downloaded.';
    }

    if (errorString.contains('instagram') &&
        errorString.contains('not found')) {
      return 'Instagram post not found.\nIt may have been deleted or made private.';
    }

    // yt-dlp specific errors
    if (errorString.contains('unable to extract') ||
        errorString.contains('video unavailable') ||
        errorString.contains('this video is not available')) {
      return 'This video is not available.\nIt may be private or deleted.';
    }

    if (errorString.contains('private video')) {
      return 'This is a private video.\nYou don\'t have permission to access it.';
    }

    if (errorString.contains('age') && errorString.contains('restricted')) {
      return 'This video is age-restricted.\nPlease verify your account on YouTube.';
    }

    // Rate limiting
    if (errorString.contains('rate limit') ||
        errorString.contains('too many requests') ||
        errorString.contains('429')) {
      return 'Too many requests.\nPlease wait a few minutes and try again.';
    }

    // Playlist errors
    if (errorString.contains('playlist') && errorString.contains('not found')) {
      return 'Playlist not found.\nIt may have been deleted or made private.';
    }

    // Generic yt-dlp error
    if (errorString.contains('yt-dlp') || errorString.contains('youtube')) {
      return 'YouTube service error.\nPlease try again later.';
    }

    // File system errors
    if (errorString.contains('permission denied') ||
        errorString.contains('access denied')) {
      return 'Storage permission required.\nPlease grant storage permission in Settings.';
    }

    if (errorString.contains('no space') || errorString.contains('disk full')) {
      return 'Not enough storage space.\nFree up some space and try again.';
    }

    // Generic fallback
    return 'Something went wrong.\nPlease try again later.';
  }

  /// Get a short error title for the error
  static String getErrorTitle(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('no active account') ||
        errorString.contains('no cookies')) {
      return 'Not Logged In';
    }

    if (errorString.contains('sign in') ||
        errorString.contains('authentication')) {
      return 'Session Expired';
    }

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Connection Error';
    }

    if (errorString.contains('requested format is not available')) {
      return 'Format Unavailable';
    }

    if (errorString.contains('signature solving failed')) {
      return 'Format Extraction Failed';
    }

    if (errorString.contains('there is no video in this post')) {
      return 'No Video in Post';
    }

    if (errorString.contains('instagram')) {
      return 'Instagram Error';
    }

    if (errorString.contains('rate limit')) {
      return 'Rate Limited';
    }

    if (errorString.contains('permission')) {
      return 'Permission Required';
    }

    return 'Error';
  }

  /// Check if the error is recoverable (user can retry)
  static bool isRecoverable(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Not recoverable: authentication issues (need user action in settings)
    if (errorString.contains('no active account') ||
        errorString.contains('no cookies')) {
      return false;
    }

    // Not recoverable: permission issues
    if (errorString.contains('permission denied')) {
      return false;
    }

    // Not recoverable: Instagram posts without videos
    if (errorString.contains('there is no video in this post')) {
      return false;
    }

    // Recoverable: format availability issues (user can choose different quality)
    if (errorString.contains('requested format is not available') ||
        errorString.contains('signature solving failed')) {
      return true;
    }

    // Recoverable: network, rate limit, temporary issues
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('rate limit')) {
      return true;
    }

    // Default: recoverable
    return true;
  }

  /// Get suggested action for the error
  static String? getSuggestedAction(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('no active account') ||
        errorString.contains('no cookies')) {
      return 'Go to Settings';
    }

    if (errorString.contains('sign in') ||
        errorString.contains('authentication')) {
      return 'Re-login';
    }

    if (errorString.contains('there is no video in this post')) {
      return 'Choose Video Post';
    }

    if (errorString.contains('instagram')) {
      return 'Check Post';
    }

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Check Connection';
    }

    if (errorString.contains('requested format is not available')) {
      return 'Choose Different Quality';
    }

    if (errorString.contains('signature solving failed')) {
      return 'Try Different Quality';
    }

    if (errorString.contains('permission')) {
      return 'Grant Permission';
    }

    if (isRecoverable(error)) {
      return 'Retry';
    }

    return null;
  }
}
