class BridgeError(Exception):
    """Base exception for all bridge-related errors."""
    pass

class ExtractionError(BridgeError):
    """Raised when yt-dlp extraction fails."""
    pass

class DownloadError(BridgeError):
    """Raised when a download task fails."""
    pass

class AuthError(BridgeError):
    """Raised when there are issues with cookies or authentication."""
    pass
