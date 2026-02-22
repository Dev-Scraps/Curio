"""
Handlers module for Curio Python bridge.
Provides unified dispatch bridge for Flutter-Python communication.
"""

from .app_bridge import *

__all__ = [
    'extract_metadata',
    'getInfo', 
    'getEnhancedVideoInfo',
    'extract_user_playlists',
    'getUserPlaylists',
    'get_formats_categorized',
    'get_playlist_items',
    'start_download',
    'startDownload',
    'start_enhanced_download',
    'startEnhancedDownload',
    'get_download_status',
    'getDownloadStatus',
    'cancel_download',
    'cancelDownload',
    'pauseDownload',
    'resumeDownload',
    'get_ytdlp_version',
    'clear_cache'
]
