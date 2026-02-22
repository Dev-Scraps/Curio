"""
Enhanced yt-dlp client with full extractor support (1700+ websites).
Improved caching, error handling, and concurrent processing.
Fixed for Android/Chaquopy compatibility.
"""

# CRITICAL: Apply Android socket fix BEFORE any other imports
import sys
try:
    import socket
    # Fix for Android/Chaquopy: socket.if_nameindex exists but doesn't work
    if not hasattr(socket, '_original_if_nameindex'):
        socket._original_if_nameindex = getattr(socket, 'if_nameindex', None)
        if socket._original_if_nameindex is not None:
            socket.if_nameindex = lambda: []
            print("[yt_dlp_client] Applied Android socket.if_nameindex workaround")
except Exception as e:
    print(f"[yt_dlp_client] Socket patch warning (non-critical): {e}")

import hashlib
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Any
from concurrent.futures import ThreadPoolExecutor, as_completed
from yt_dlp import YoutubeDL
from formats.bridge_config import (
    YTDLP_FLAT_CONFIG,
    YTDLP_FULL_CONFIG,
    YTDLP_PLAYLIST_CONFIG,
    HTTP_HEADERS,
    CACHE_ENABLED,
    CACHE_TTL_MINUTES,
)
from initialization.bridge_logger import logger, ytdlp_logger
from account.cookie_service import CookieManager

class CacheEntry:
    def __init__(self, data: Dict, ttl: int):
        self.data = data
        self.expires_at = datetime.now() + timedelta(minutes=ttl)

    def is_expired(self):
        return datetime.now() > self.expires_at

import os
import subprocess

# --- ANDROID COMPATIBILITY SHIM ---
# Bypasses W^X / noexec restrictions by running binaries via system linker
_original_Popen = subprocess.Popen

class PopenShim(_original_Popen):
    def __init__(self, args, **kwargs):
        if isinstance(args, list) and len(args) > 0:
            exe = args[0]
            # Check if execution target is one of our binaries
            if isinstance(exe, str):
                base = os.path.basename(exe)
                if base in ('ffmpeg', 'ffprobe', 'qjs', 'quickjs'):
                    # Determine correct linker
                    linker = "/system/bin/linker64"
                    if not os.path.exists(linker):
                        linker = "/system/bin/linker"
                    
                    # Only inject if not already injected
                    if exe != linker:
                        # Log the injection for debugging
                        # print(f"[Shim] Redirecting {base} via {linker}")
                        args = [linker, exe] + args[1:]
        
        super().__init__(args, **kwargs)

# Apply patch
subprocess.Popen = PopenShim
# ----------------------------------

class YTDLPClient:
    def __init__(self, use_cache=CACHE_ENABLED, workers=8):
        self.use_cache = use_cache
        self._cache: Dict[str, CacheEntry] = {}
        self.workers = workers
        
        # Paths
        python_path = sys.executable
        base_dir = os.path.dirname(__file__)
        self.js_runtime_py = os.path.join(base_dir, "..", "js_wrapper.py")
        
        # Direct paths to raw binaries
        # We rely on PopenShim to execute them
        self.bin_dir = "/data/data/com.curio.app/files"
            
        logger.info(f"✓ YTDLPClient initialized. Python: {python_path}")
        
        # Check FFmpeg availability
        self.ffmpeg_location = None
        ffmpeg_paths = [
            os.path.join(self.bin_dir, "ffmpeg"),
            "/data/user/0/com.curio.app/files/ffmpeg",
        ]
        
        for path in ffmpeg_paths:
            if os.path.exists(path):
                self.ffmpeg_location = path
                try:
                    os.chmod(path, 0o755)
                    # Also chmod ffprobe
                    ffprobe = os.path.join(os.path.dirname(path), "ffprobe")
                    if os.path.exists(ffprobe): 
                        os.chmod(ffprobe, 0o755)
                except:
                    pass
                break
                
        logger.info(f"✓ FFmpeg available: {self.ffmpeg_location is not None}")
        
        # Add bin dir to PATH for good measure
        path = os.environ.get("PATH", "")
        if self.bin_dir not in path:
            os.environ["PATH"] = f"{self.bin_dir}:{path}"

    def set_ffmpeg_location(self, path: str):
        """Set FFmpeg location from Android library."""
        if path and os.path.exists(path):
             self.ffmpeg_location = os.path.dirname(path) # yt-dlp often prefers directory
             # But if it's a file, we might needed to ensure we pass the dir or key it differently?
             # yt-dlp 'ffmpeg_location' option handles both usually.
             # However, if we pass a directory, it looks for ffmpeg/ffprobe inside.
             # The library might give us ".../libffmpeg.so".
             # If we pass that file path, yt-dlp should use it.
             self.ffmpeg_location = path
             logger.info(f"✓ FFmpeg location updated to: {self.ffmpeg_location}")
        else:
             logger.warning(f"⚠ Invalid FFmpeg path provided: {path}")

    def _get_key(self, url, flat, cookies):
        """Generate cache key from URL, mode, and cookies"""
        cookie_hash = hashlib.md5(str(cookies).encode()).hexdigest()[:8] if cookies else "none"
        return hashlib.md5(f"{url}{flat}{cookie_hash}".encode()).hexdigest()

    def _get_opts(self, flat, is_playlist):
        """Get appropriate yt-dlp options based on extraction mode"""
        if is_playlist:
            opts = YTDLP_PLAYLIST_CONFIG.copy()
        elif flat:
            opts = YTDLP_FLAT_CONFIG.copy()
        else:
            opts = YTDLP_FULL_CONFIG.copy()
        
        opts.update({
            "http_headers": HTTP_HEADERS,
            "logger": ytdlp_logger,
            # Android/Chaquopy compatibility fixes
            "socket_timeout": 30,
            "source_address": None,  # Disable source address binding
            "nocheckcertificate": False,
            "prefer_insecure": False,
        })

        # Keep remote_components enabled for EJS fallback
        # Don't disable it - it provides fallback JavaScript execution

        # Optional PO token support (for Android client/GVS access)
        po_token = os.environ.get("CURIO_PO_TOKEN")
        youtube_args = opts.get("extractor_args", {}).get("youtube", {})
        if po_token:
            # With PO token, can use Android client
            youtube_args = {**youtube_args, "po_token": po_token, "player_client": ["android", "web"]}
        else:
            # Without PO token, use web first then iOS for better format availability
            youtube_args = {**youtube_args, "player_client": ["web", "ios", "web_safari"]}
        opts.setdefault("extractor_args", {})["youtube"] = youtube_args
        
        # Configure QuickJS runtime for JavaScript signature solving
        # Check both common locations (files/ and no_backup/bin/)
        quickjs_paths = [
            "/data/data/com.curio.app/files/qjs",
            "/data/user/0/com.curio.app/files/qjs",
            "/data/data/com.curio.app/no_backup/bin/qjs",
            "/data/user/0/com.curio.app/no_backup/bin/qjs"
        ]
        quickjs_path = next((p for p in quickjs_paths if os.path.exists(p)), None)

        if not quickjs_path:
            try:
                from initialization.quickjs_setup import QuickJSSetup
                quickjs_path = QuickJSSetup.initialize()
            except Exception as e:
                logger.warning(f"⚠ QuickJS auto-initialize failed: {e}")
        
        if quickjs_path:
            logger.info(f"✓ QuickJS used for opts: {quickjs_path}")
            # Ensure QuickJS is executable
            try:
                os.chmod(quickjs_path, 0o755)
                logger.info(f"Set execute permissions for QuickJS: {quickjs_path}")
            except Exception as e:
                logger.warning(f"Failed to chmod QuickJS: {e}")

            # yt-dlp API expects: js_runtimes = {runtime_name: {path: /path/to/executable}}
            # Reference: https://github.com/yt-dlp/yt-dlp/blob/main/yt_dlp/utils/_jsruntime.py#L125-L145
            opts["js_runtimes"] = {"quickjs": {"path": quickjs_path}}
        else:
            logger.warning("⚠ QuickJS not found in known locations - signature solving may fail")
        
        # Configure FFmpeg location
        ffmpeg_paths = [
            "/data/data/com.curio.app/files/ffmpeg",
            "/data/user/0/com.curio.app/files/ffmpeg",
            "/data/data/com.curio.app/no_backup/bin/ffmpeg",
            "/data/user/0/com.curio.app/no_backup/bin/ffmpeg"
        ]
        ffmpeg_path = next((p for p in ffmpeg_paths if os.path.exists(p)), None)
        
        if ffmpeg_path:
            # Ensure binaries are executable
            try:
                os.chmod(ffmpeg_path, 0o755)
                ffprobe_path = os.path.join(os.path.dirname(ffmpeg_path), "ffprobe")
                if os.path.exists(ffprobe_path):
                    os.chmod(ffprobe_path, 0o755)
            except Exception as e:
                logger.warning(f"Failed to chmod ffmpeg/ffprobe: {e}")

            opts["ffmpeg_location"] = ffmpeg_path
            logger.info(f"✓ FFmpeg configured for metadata extraction: {ffmpeg_path}")
        else:
            logger.warning("⚠ FFmpeg not found in known locations")
        
        return opts

    def extract(self, url, flat=False, cookies=None, is_playlist=False):
        """
        Extract metadata from any supported URL (1700+ websites).
        
        Args:
            url: Video/playlist URL from any supported site
            flat: If True, fast extraction with basic info only
            cookies: Cookie string for authentication
            is_playlist: If True, optimize for playlist extraction
        
        Returns:
            Dict with extracted metadata or None on error
        """
        key = self._get_key(url, flat, cookies)
        
        if self.use_cache and key in self._cache:
            entry = self._cache[key]
            if not entry.is_expired():
                logger.debug(f" Cache hit for {url[:50]}...")
                return entry.data
            del self._cache[key]

        try:
            opts = self._get_opts(flat, is_playlist)
            
            logger.info(f" Extracting info from {url[:50]}... (flat={flat})")
            logger.debug(f" Using player clients: {opts.get('extractor_args', {}).get('youtube', {}).get('player_client', [])}")
            logger.debug(f" JS runtimes: {opts.get('js_runtimes', {})}")
            
            with CookieManager(cookies) as c_file:
                if c_file:
                    opts["cookiefile"] = c_file
                    logger.debug(" Using cookies for authentication")
                
                with YoutubeDL(opts) as ydl:
                    info = ydl.extract_info(url, download=False)
                    
                    if info and self.use_cache:
                        self._cache[key] = CacheEntry(info, CACHE_TTL_MINUTES)
                        logger.debug(f" Cached metadata for {url[:50]}...")
                    
                    logger.info(f" ✓ Extraction successful for {url[:50]}")
                    return info
                    
        except Exception as e:
            error_msg = str(e)
            logger.error(f" ❌ Extraction failed for {url}: {error_msg[:200]}")
            
            # Log specific YouTube issues
            if "sign" in error_msg.lower() or "403" in error_msg:
                logger.error(" Issue: YouTube signature/access error - may need player update or authentication")
            elif "n-" in error_msg.lower() or "challenge" in error_msg.lower():
                logger.error(" Issue: YouTube n-parameter challenge - check QuickJS/EJS setup")
            elif "http" in error_msg.lower() or "connection" in error_msg.lower():
                logger.error(" Issue: Network connectivity problem - check internet connection")
            
            return None

    def extract_batch(self, urls, flat=True, cookies=None):
        """
        Extract metadata from multiple URLs concurrently.
        
        Args:
            urls: List of URLs to extract
            flat: If True, use fast extraction
            cookies: Cookie string for authentication
        
        Returns:
            Dict mapping URL to extracted metadata
        """
        results = {}
        logger.info(f" Batch extracting {len(urls)} URLs")
        
        with ThreadPoolExecutor(max_workers=self.workers) as exe:
            futures = {exe.submit(self.extract, u, flat, cookies): u for u in urls}
            
            for f in as_completed(futures):
                url = futures[f]
                try:
                    results[url] = f.result()
                except Exception as e:
                    logger.error(f" Batch extraction failed for {url}: {e}")
                    results[url] = None
        
        return results

ytdlp_client = YTDLPClient()