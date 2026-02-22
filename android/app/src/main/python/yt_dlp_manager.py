"""
yt-dlp Download Manager for High-Resolution Video Downloads

This module provides a clean interface for downloading 1080p+ videos using yt-dlp
with FFmpeg for stream merging and QuickJS for YouTube signature validation.

2026 Critical Implementation Notes:
- YouTube's security frequently throttles download speeds without a JavaScript engine
- QuickJS is lightweight (~1MB) and solves signature challenges (n-challenge scrambling)  
- Downloads above 720p require FFmpeg to merge separate video/audio DASH/HLS streams
- Binaries must be copied to writable app storage before execution on Android
"""

import os
import json
import subprocess
from typing import Dict, Any, Optional, Callable
from yt_dlp import YoutubeDL
from initialization.bridge_logger import logger

# --- ANDROID COMPATIBILITY SHIM ---
# Bypasses W^X / noexec restrictions by running binaries via system linker
_original_Popen = subprocess.Popen


class PopenShim(_original_Popen):
    def __init__(self, args, **kwargs):
        if isinstance(args, list) and len(args) > 0:
            exe = args[0]
            if isinstance(exe, str):
                base = os.path.basename(exe)
                if base in ('ffmpeg', 'ffprobe', 'qjs', 'quickjs'):
                    linker = "/system/bin/linker64"
                    if not os.path.exists(linker):
                        linker = "/system/bin/linker"
                    if exe != linker:
                        args = [linker, exe] + args[1:]

        super().__init__(args, **kwargs)


subprocess.Popen = PopenShim
# ----------------------------------


class YtDlpManager:
    """
    Manages high-resolution video downloads with FFmpeg and QuickJS integration.
    
    Usage:
        manager = YtDlpManager(
            ffmpeg_path='/data/data/com.curio.app/files/ffmpeg',
            quickjs_path='/data/data/com.curio.app/files/qjs'
        )
        result = manager.download_high_res(
            url='https://youtube.com/watch?v=...',
            output_dir='/storage/emulated/0/Download/Curio'
        )
    """
    
    def __init__(
        self,
        ffmpeg_path: str,
        quickjs_path: str,
        ffprobe_path: Optional[str] = None
    ):
        """
        Initialize the download manager with binary paths.
        
        Args:
            ffmpeg_path: Absolute path to the FFmpeg executable
            quickjs_path: Absolute path to the QuickJS (qjs) executable
            ffprobe_path: Optional path to FFprobe (defaults to same dir as FFmpeg)
        """
        self.ffmpeg_path = ffmpeg_path
        self.quickjs_path = quickjs_path
        self.ffprobe_path = ffprobe_path or os.path.join(
            os.path.dirname(ffmpeg_path), 'ffprobe'
        )
        
        # Validate binary paths exist
        self._validate_binaries()

        # Ensure binaries are executable
        try:
            os.chmod(self.ffmpeg_path, 0o755)
            os.chmod(self.quickjs_path, 0o755)
            if self.ffprobe_path and os.path.exists(self.ffprobe_path):
                os.chmod(self.ffprobe_path, 0o755)
        except Exception as e:
            logger.warning(f"[YtDlpManager] Failed to chmod binaries: {e}")
        
        # Add QuickJS directory to PATH for yt-dlp to use during signature validation
        self._configure_environment()
        
        logger.info(f"[YtDlpManager] Initialized with FFmpeg: {ffmpeg_path}")
        logger.info(f"[YtDlpManager] QuickJS configured at: {quickjs_path}")
    
    def _validate_binaries(self) -> None:
        """Validate that all required binaries exist."""
        missing = []
        
        if not os.path.exists(self.ffmpeg_path):
            missing.append(f"FFmpeg not found at: {self.ffmpeg_path}")
        
        if not os.path.exists(self.quickjs_path):
            missing.append(f"QuickJS not found at: {self.quickjs_path}")
        
        if missing:
            error_msg = "; ".join(missing)
            logger.error(f"[YtDlpManager] Missing binaries: {error_msg}")
            raise FileNotFoundError(error_msg)
    
    def _verify_ffmpeg_functional(self) -> bool:
        """Verify FFmpeg can be executed and is functional."""
        try:
            import subprocess
            result = subprocess.run(
                [self.ffmpeg_path, '-version'],
                capture_output=True,
                timeout=5,
                text=True
            )
            if result.returncode == 0:
                version_line = result.stdout.split('\n')[0]
                logger.info(f"[YtDlpManager] FFmpeg verified: {version_line}")
                return True
            else:
                logger.error(f"[YtDlpManager] FFmpeg test failed with code {result.returncode}")
                return False
        except Exception as e:
            logger.error(f"[YtDlpManager] FFmpeg verification error: {e}")
            return False
    
    def _configure_environment(self) -> None:
        """Configure environment for yt-dlp to find QuickJS and FFmpeg."""
        quickjs_dir = os.path.dirname(self.quickjs_path)
        ffmpeg_dir = os.path.dirname(self.ffmpeg_path)
        current_path = os.environ.get("PATH", "")
        
        # Build new PATH with both binary directories
        new_path_dirs = [ffmpeg_dir, quickjs_dir]
        for path_dir in new_path_dirs:
            if path_dir not in current_path:
                current_path = f"{path_dir}:{current_path}"
        
        os.environ["PATH"] = current_path
        logger.info(f"[YtDlpManager] Updated PATH with binary directories")
        
        # Verify FFmpeg is functional
        if not self._verify_ffmpeg_functional():
            logger.warning("[YtDlpManager] FFmpeg verification failed - merging may not work")
    
    def _get_base_config(self) -> Dict[str, Any]:
        """Get base yt-dlp configuration."""
        return {
            # FFmpeg configuration
            'ffmpeg_location': self.ffmpeg_path,
            
            # Output settings
            'merge_output_format': 'mp4',
            'keepvideo': False,
            'overwrites': True,
            
            # Network settings
            'socket_timeout': 30,
            'retries': 10,
            'fragment_retries': 10,
            
            # HTTP headers (important for avoiding throttling)
            'http_headers': {
                'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.5',
            },
            
            # Quiet mode for cleaner output
            'quiet': False,
            'no_warnings': False,
            'ignoreerrors': False,
        }
    
    def _configure_quickjs_runtime(self, config: Dict[str, Any]) -> None:
        """Configure QuickJS as the JavaScript runtime for signature solving."""
        if os.path.exists(self.quickjs_path):
            # Ensure QuickJS is executable
            try:
                os.chmod(self.quickjs_path, 0o755)
                logger.info(f"[YtDlpManager] Set execute permissions for QuickJS: {self.quickjs_path}")
            except Exception as e:
                logger.warning(f"[YtDlpManager] Failed to chmod QuickJS: {e}")

            # yt-dlp API expects: js_runtimes = {runtime_name: {path: /path/to/executable}}
            # Reference: https://github.com/yt-dlp/yt-dlp/blob/main/yt_dlp/utils/_jsruntime.py#L125-L145
            config['js_runtimes'] = {"quickjs": {"path": self.quickjs_path}}
            logger.info(f"[YtDlpManager] QuickJS runtime configured at {self.quickjs_path}")
        else:
            logger.warning(f"[YtDlpManager] QuickJS not found at {self.quickjs_path} - signature solving may fail")
    
    def download_high_res(
        self,
        url: str,
        output_dir: str,
        progress_callback: Optional[Callable[[Dict], None]] = None,
        cookies: Optional[str] = None,
        min_height: int = 720,
        preferred_format: str = 'mp4'
    ) -> Dict[str, Any]:
        """
        Download a video in the highest available resolution above min_height.
        
        Args:
            url: Video URL to download
            output_dir: Directory to save the downloaded file
            progress_callback: Optional callback for progress updates
            cookies: Optional cookie string for authenticated downloads
            min_height: Minimum video height (default 720 for 1080p+)
            preferred_format: Output format (default 'mp4')
        
        Returns:
            Dict with download result including:
                - success: bool
                - file_path: str (if successful)
                - title: str
                - resolution: str
                - error: str (if failed)
        """
        # Ensure output directory exists
        os.makedirs(output_dir, exist_ok=True)
        
        # Build yt-dlp configuration
        config = self._get_base_config()
        
        # Format selector: best video above min_height + best audio, fallback to best combined
        # This is the key for 1080p+ downloads - YouTube serves these as separate streams
        # Format: best video above min_height + best audio, fallback to best combined
        # YouTube stores 1080p+ video and audio separately and requires FFmpeg to merge
        config['format'] = f'bv[height>{min_height}]+ba/b[height>{min_height}]/b'
        
        # Alternative format selectors for debugging:
        # 'bestvideo[height>=1080]+bestaudio/best' - Explicit 1080p+
        # 'bv*[height>=720]+ba/b' - 720p+ with more codec flexibility
        
        config['merge_output_format'] = preferred_format
        config['outtmpl'] = os.path.join(output_dir, '%(title)s.%(ext)s')
        
        # Critical: Post-processor settings for FFmpeg
        # https://github.com/yt-dlp/yt-dlp/blob/main/yt_dlp/postprocessor/ffmpeg.py#L88-L100
        config['postprocessors'] = [{
            'key': 'FFmpegMerger',  # Merge video+audio
            'prefer_ffmpeg': True,   # Use FFmpeg over other methods
            'args': ['-c', 'copy'],  # Copy streams (no re-encoding for speed)
        }]
        
        # Configure QuickJS for signature validation
        # This solves the n-parameter challenge that YouTube uses to prevent throttling
        self._configure_quickjs_runtime(config)
        
        # Handle cookies if provided
        if cookies:
            cookie_file = self._write_cookie_file(cookies)
            if cookie_file:
                config['cookiefile'] = cookie_file
        
        # Set up progress hook
        download_info = {'filename': None}
        
        def progress_hook(d):
            if d['status'] == 'downloading':
                if progress_callback:
                    progress_callback({
                        'status': 'downloading',
                        'progress': d.get('_percent_str', '0%'),
                        'speed': d.get('_speed_str', 'N/A'),
                        'eta': d.get('_eta_str', 'N/A'),
                        'downloaded': d.get('downloaded_bytes', 0),
                        'total': d.get('total_bytes') or d.get('total_bytes_estimate', 0),
                    })
            elif d['status'] == 'finished':
                download_info['filename'] = d.get('filename')
                if progress_callback:
                    progress_callback({
                        'status': 'finished',
                        'filename': d.get('filename'),
                    })
        
        config['progress_hooks'] = [progress_hook]
        
        # Execute download
        try:
            logger.info(f"[YtDlpManager] Starting high-res download: {url}")
            logger.info(f"[YtDlpManager] Format selector: {config['format']}")
            
            with YoutubeDL(config) as ydl:
                info = ydl.extract_info(url, download=True)
                
                if info:
                    # Get the final file path
                    file_path = None
                    if 'requested_downloads' in info and info['requested_downloads']:
                        file_path = info['requested_downloads'][0].get('filepath')
                    elif '_filename' in info:
                        file_path = info['_filename']
                    elif download_info['filename']:
                        file_path = download_info['filename']
                    
                    # Get resolution info
                    resolution = "Unknown"
                    if 'height' in info:
                        resolution = f"{info['height']}p"
                    elif 'format' in info:
                        resolution = info['format']
                    
                    result = {
                        'success': True,
                        'file_path': file_path,
                        'title': info.get('title', 'Unknown'),
                        'resolution': resolution,
                        'duration': info.get('duration'),
                        'uploader': info.get('uploader'),
                        'format_id': info.get('format_id'),
                    }
                    
                    logger.info(f"[YtDlpManager] Download completed: {file_path}")
                    return result
                else:
                    raise Exception("No download info returned from yt-dlp")
                    
        except Exception as e:
            error_msg = str(e)
            logger.error(f"[YtDlpManager] Download failed: {error_msg}")
            return {
                'success': False,
                'error': error_msg,
                'url': url,
            }
    
    def _write_cookie_file(self, cookies: str) -> Optional[str]:
        """Write cookies to a Netscape format file for yt-dlp."""
        try:
            from account.cookie_service import CookieService
            return CookieService.create_netscape_file(cookies)
        except Exception as e:
            logger.warning(f"[YtDlpManager] Failed to write cookie file: {e}")
            return None
    
    def get_video_info(
        self,
        url: str,
        cookies: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Get video information without downloading.
        
        Args:
            url: Video URL
            cookies: Optional cookie string
        
        Returns:
            Dict with video metadata including available formats
        """
        config = self._get_base_config()
        config['skip_download'] = True
        
        self._configure_quickjs_runtime(config)
        
        if cookies:
            cookie_file = self._write_cookie_file(cookies)
            if cookie_file:
                config['cookiefile'] = cookie_file
        
        try:
            with YoutubeDL(config) as ydl:
                info = ydl.extract_info(url, download=False)
                
                if info:
                    # Filter and categorize formats
                    formats = info.get('formats', [])
                    high_res_formats = [
                        f for f in formats 
                        if f.get('height') and f.get('height') > 720
                    ]
                    
                    return {
                        'success': True,
                        'id': info.get('id'),
                        'title': info.get('title'),
                        'duration': info.get('duration'),
                        'uploader': info.get('uploader'),
                        'thumbnail': info.get('thumbnail'),
                        'high_res_available': len(high_res_formats) > 0,
                        'max_resolution': max([f.get('height', 0) for f in formats], default=0),
                        'formats_count': len(formats),
                    }
                    
        except Exception as e:
            logger.error(f"[YtDlpManager] Failed to get video info: {e}")
            return {
                'success': False,
                'error': str(e),
            }


# Convenience function for direct use from Python bridge
def download_high_res(
    url: str,
    ffmpeg_path: str,
    quickjs_path: str,
    output_dir: str,
    cookies: str = None
) -> str:
    """
    Convenience function for downloading high-resolution video.
    
    This function is designed to be called from the Chaquopy bridge.
    
    Args:
        url: Video URL to download
        ffmpeg_path: Path to FFmpeg binary
        quickjs_path: Path to QuickJS binary  
        output_dir: Output directory for downloaded file
        cookies: Optional cookie string
    
    Returns:
        JSON string with download result
    """
    try:
        manager = YtDlpManager(
            ffmpeg_path=ffmpeg_path,
            quickjs_path=quickjs_path
        )
        
        result = manager.download_high_res(
            url=url,
            output_dir=output_dir,
            cookies=cookies
        )
        
        return json.dumps(result)
        
    except Exception as e:
        return json.dumps({
            'success': False,
            'error': str(e)
        })
