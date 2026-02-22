"""
Unified dispatch bridge for Curio and Python services.
Refactored to use modular services for better distribution and maintenance.
"""

# CRITICAL: Import Android compatibility layer FIRST
from initialization import android_compat

from core.json_utils import safe_json, get_error_response
from initialization.bridge_logger import logger

def extract_metadata(url: str, cookies: str = None, flat: bool = False) -> str:
    """Extract metadata for video or playlist. (Matches MainActivity.kt)"""
    try:
        from metadata.metadata_service import metadata_service
        return safe_json(metadata_service.get_info(url, flat=flat, cookies=cookies))
    except Exception as e:
        logger.error(f"Bridge extract_metadata error: {e}")
        return safe_json(get_error_response(str(e)))

# Alias for getInfo
getInfo = extract_metadata

def getEnhancedVideoInfo(url: str) -> str:
    """Matches Dart invokeMethod."""
    return getInfo(url, flat=False)

def extract_user_playlists(cookies: str = None) -> str:
    """Fetch all user playlists. (Matches MainActivity.kt)"""
    try:
        from playlist.discovery import playlist_discovery
        return safe_json(playlist_discovery.discover(cookies))
    except Exception as e:
        logger.error(f"Bridge extract_user_playlists error: {e}")
        return safe_json(get_error_response(str(e)))

# Alias for getUserPlaylists
getUserPlaylists = extract_user_playlists

def get_formats_categorized(url: str, cookies: str = None) -> str:
    """Categorized formats for UI selection. (Matches format.dart)"""
    try:
        from metadata.metadata_service import metadata_service
        info = metadata_service.get_info(url, flat=False, cookies=cookies)
        
        formats = info.get("formats", [])
        combined = [f for f in formats if f.get("vcodec") != "none" and f.get("acodec") != "none"]
        video = [f for f in formats if f.get("vcodec") != "none" and f.get("acodec") == "none"]
        audio = [f for f in formats if f.get("vcodec") == "none" and f.get("acodec") != "none"]
        
        return safe_json({
            "combined": combined,
            "video": video,
            "audio": audio,
            "subtitles": info.get("subtitles", {}),
            "automatic_captions": info.get("automatic_captions", {}),
            "error": False
        })
    except Exception as e:
        logger.error(f"Bridge get_formats_categorized error: {e}")
        return safe_json(get_error_response(str(e)))
def get_playlist_items(playlist_id: str, cookies: str = None, flat: bool = True) -> str:
    """Fetch videos within a playlist."""
    try:
        from playlist.items import playlist_content
        return safe_json(playlist_content.get_items(playlist_id, cookies, flat))
    except Exception as e:
        logger.error(f"Bridge get_playlist_items error: {e}")
        return safe_json(get_error_response(str(e)))

def start_download(url: str, config: str, info: str = None) -> str:
    """Queue a download task. (Matches MainActivity.kt)"""
    try:
        import json
        from download.engine import download_engine
        
        # MainActivity sends info as a JSON string or null
        # config is a JSON string of the Map
        config_dict = json.loads(config) if isinstance(config, str) else config
        info_dict = json.loads(info) if isinstance(info, str) else None
        
        logger.info(f"[Bridge] Starting download - Native mode")
        
        return download_engine.add_task(url, config_dict, info_dict)
    except Exception as e:
        logger.error(f"Bridge start_download error: {e}")
        return ""

def start_enhanced_download(url: str, config: str = None, **kwargs) -> str:
    """Start enhanced download with all parameters. (Matches MainActivity.kt)"""
    try:
        import json
        from download.engine import download_engine
        
        # Parse config JSON if provided
        if config:
            config_dict = json.loads(config) if isinstance(config, str) else config
        else:
            # Use kwargs as fallback
            config_dict = {}
            for key, value in kwargs.items():
                if value is not None:
                    config_dict[key] = value
        
        logger.info(f"[Bridge] Starting enhanced download - Native mode")
        
        return download_engine.add_task(url, config_dict, None)
    except Exception as e:
        logger.error(f"Bridge start_enhanced_download error: {e}")
        return ""

# Alias for startDownload
startDownload = start_download

# Alias for startEnhancedDownload
startEnhancedDownload = start_enhanced_download

def get_download_status(taskId: str) -> str:
    """Get status of a task. (Matches MainActivity.kt)"""
    try:
        from download.engine import download_engine
        return safe_json(download_engine.get_status(taskId))
    except Exception as e:
        return "{}"

# Alias for getDownloadStatus
getDownloadStatus = get_download_status

def cancel_download(taskId: str) -> bool:
    """Request cancellation. (Matches MainActivity.kt)"""
    try:
        from download.engine import download_engine
        return download_engine.cancel_task(taskId)
    except:
        return False

# Alias for cancelDownload
cancelDownload = cancel_download

def pauseDownload(taskId: str) -> bool:
    """Placeholder for pause support."""
    return False

def resumeDownload(taskId: str) -> bool:
    """Placeholder for resume support."""
    return False

def get_ytdlp_version() -> str:
    """Return current yt-dlp and bridge version info."""
    try:
        from yt_dlp import version
        import sys
        return safe_json({
            "version": version.__version__, 
            "python_version": sys.version,
            "bridge_version": "3.1.2",
            "error": False
        })
    except Exception as e:
        return safe_json({"version": "unknown", "error": True, "message": str(e)})

def clear_cache():
    """Clear metadata cache."""
    try:
        from fetchers.yt_dlp_client import ytdlp_client
        ytdlp_client._cache.clear()
        logger.info("[Bridge] Cache cleared")
    except Exception as e:
        logger.error(f"Cache clear error: {e}")

def init_ffmpeg(path: str) -> None:
    """Initialize FFmpeg path from Android."""
    try:
        from fetchers.yt_dlp_client import ytdlp_client
        logger.info(f"[Bridge] Setting FFmpeg path to: {path}")
        ytdlp_client.set_ffmpeg_location(path)
    except Exception as e:
        logger.error(f"Failed to set FFmpeg path: {e}")

def set_po_token(token: str = None) -> str:
    """Configure YouTube PO token for Android client requests."""
    try:
        import os
        if token:
            os.environ["CURIO_PO_TOKEN"] = token
            logger.info("[Bridge] PO token configured")
        else:
            os.environ.pop("CURIO_PO_TOKEN", None)
            logger.info("[Bridge] PO token cleared")
        return safe_json({"success": True})
    except Exception as e:
        logger.error(f"Failed to set PO token: {e}")
        return safe_json(get_error_response(str(e)))