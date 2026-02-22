import os
import time
import re
import subprocess
from yt_dlp import YoutubeDL
from initialization.bridge_logger import logger, ytdlp_logger
from formats.bridge_config import (
    YTDLP_DOWNLOAD_CONFIG,
    YTDLP_AUDIO_ONLY_CONFIG,
    YTDLP_SEPARATE_STREAMS_CONFIG,
    HTTP_HEADERS
)
from account.cookie_service import CookieManager, CookieService
from download.task import DownloadTask
from metadata.metadata_embedder import metadata_embedder
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



def get_download_config(download_type="video"):
    """Get download configuration based on download type."""
    if download_type == "audio":
        return YTDLP_AUDIO_ONLY_CONFIG.copy()
    elif download_type == "separate_streams":
        return YTDLP_SEPARATE_STREAMS_CONFIG.copy()
    elif download_type == "video":
        return YTDLP_DOWNLOAD_CONFIG.copy()
    else:
        # Default to standard config
        return YTDLP_DOWNLOAD_CONFIG.copy()

def download_worker(task: DownloadTask):
    """
    Native download worker.
    
    Args:
        task: DownloadTask object with download parameters
    """
    logger.info(f"[Worker] Starting download: {task.url}")
    
    # Choose configuration based on download type
    config = get_download_config(task.download_type)
    logger.info(f"[Worker] Using configuration for {task.download_type}")
    
    # Configure QuickJS runtime for JavaScript signature solving
    # YouTube requires this for most formats now due to n-challenge scrambling
    # Check both common locations (files/ and no_backup/bin/)
    quickjs_paths = [
        "/data/data/com.curio.app/files/qjs",
        "/data/user/0/com.curio.app/files/qjs",
        "/data/data/com.curio.app/no_backup/bin/qjs",
        "/data/user/0/com.curio.app/no_backup/bin/qjs"
    ]
    quickjs_path = next((p for p in quickjs_paths if os.path.exists(p)), None)
    
    # If QuickJS not found, try to import and setup from Python package
    if not quickjs_path:
        try:
            from initialization.quickjs_setup import QuickJSSetup
            quickjs_path = QuickJSSetup.initialize()
        except Exception as e:
            logger.warning(f"[Worker] QuickJS setup failed: {e}")
    
    if quickjs_path:
        logger.info(f"[Worker] QuickJS found at: {quickjs_path}")
        
        # Ensure QuickJS is executable - try multiple times as Android may reset permissions
        for attempt in range(3):
            try:
                os.chmod(quickjs_path, 0o755)
                # Verify it worked
                if os.access(quickjs_path, os.X_OK):
                    logger.info(f"[Worker] ✅ Execute permissions set for QuickJS: {quickjs_path}")
                    break
                else:
                    logger.warning(f"[Worker] Attempt {attempt+1}: chmod succeeded but not executable yet")
                    import time
                    time.sleep(0.1)
            except Exception as e:
                logger.warning(f"[Worker] Attempt {attempt+1} - Failed to chmod QuickJS: {e}")
                import time
                time.sleep(0.1)
        else:
            logger.error(f"[Worker] ❌ Could not set execute permissions after 3 attempts")

        # yt-dlp API expects: js_runtimes = {runtime_name: {path: /path/to/executable}}
        # Reference: https://github.com/yt-dlp/yt-dlp/blob/main/yt_dlp/utils/_jsruntime.py#L125-L145
        config['js_runtimes'] = {"quickjs": {"path": quickjs_path}}
        
        # DEBUG: Verify QuickJS actually runs (use --version instead of --help)
        try:
            # QuickJS returns 1 on --help, use simple version check instead
            test_code = 'console.log("ok")'
            ver = subprocess.run(
                [quickjs_path],
                input=test_code,
                capture_output=True,
                text=True,
                timeout=5
            )
            if "ok" in ver.stdout or ver.returncode == 0:
                logger.info(f"[Worker] ✓ QuickJS verification successful")
            else:
                logger.warning(f"[Worker] QuickJS test: return={ver.returncode}, stderr={ver.stderr[:100] if ver.stderr else 'N/A'}")
        except subprocess.TimeoutExpired:
            logger.warning("[Worker] QuickJS verification timeout")
        except Exception as e:
            logger.error(f"[Worker] QuickJS verification failed: {e}")

        # Verify yt-dlp-ejs presence
        try:
            import yt_dlp_ejs
            logger.info(f"[Worker] ✓ yt-dlp-ejs package found version: {getattr(yt_dlp_ejs, '__version__', 'unknown')}")
        except ImportError:
            logger.warning("[Worker] ⚠ yt-dlp-ejs package not found - will use remote EJS from npm")

        # Keep remote_components enabled for EJS fallback - QuickJS is primary, EJS is fallback
        # Don't delete it - it provides fallback JavaScript execution if QuickJS fails
        
        logger.info(f"[Worker] ✓ js_runtimes configured: {config.get('js_runtimes')}")
        logger.info(f"[Worker] ✓ remote_components enabled: {config.get('remote_components')}")
    else:
        logger.warning("[Worker] ⚠ QuickJS not found - will fallback to other runtimes (deno/node)")
        # yt-dlp will try deno or node instead
        # This is less efficient but still works for challenge solving

    # Set FFmpeg location to the actual binary
    ffmpeg_paths = [
        "/data/data/com.curio.app/files/ffmpeg",
        "/data/user/0/com.curio.app/files/ffmpeg",
        "/data/data/com.curio.app/no_backup/bin/ffmpeg",
        "/data/user/0/com.curio.app/no_backup/bin/ffmpeg"
    ]
    ffmpeg_path = next((p for p in ffmpeg_paths if os.path.exists(p)), None)
    
    if ffmpeg_path:
        # Ensure binary is executable
        try:
            os.chmod(ffmpeg_path, 0o755)
            logger.info(f"[Worker] Set execute permissions for FFmpeg: {ffmpeg_path}")
            
            # Also ensure ffprobe is executable (required for merging)
            ffprobe_path = os.path.join(os.path.dirname(ffmpeg_path), "ffprobe")
            if os.path.exists(ffprobe_path):
                os.chmod(ffprobe_path, 0o755)
                logger.info(f"[Worker] Set execute permissions for FFprobe: {ffprobe_path}")
            else:
                logger.warning(f"[Worker] FFprobe not found at: {ffprobe_path}")
                
        except Exception as e:
            logger.warning(f"[Worker] Failed to chmod binaries: {e}")

        # yt-dlp often prefers the directory path to find both ffmpeg and ffprobe
        ffmpeg_dir = os.path.dirname(ffmpeg_path)
        config['ffmpeg_location'] = ffmpeg_dir
        
        # ALSO add to PATH to be absolutely sure
        os.environ["PATH"] = f"{ffmpeg_dir}:{os.environ.get('PATH', '')}"
        
        logger.info(f"[Worker] Using FFmpeg directory: {ffmpeg_dir}")
        logger.info(f"[Worker] Added FFmpeg env to PATH: {ffmpeg_dir}")
    else:
        logger.warning(f"[Worker] ⚠ FFmpeg binary not found in known locations")
        logger.warning("[Worker] FFmpeg post-processing may not work")

    
    # Set up output directory and template
    output_dir = task.output_dir or '/storage/emulated/0/Download/Curio'
    os.makedirs(output_dir, exist_ok=True)
    
    # Set output template based on download type
    if task.download_type == "audio":
        config['outtmpl'] = os.path.join(output_dir, '%(title)s.%(ext)s')
        config['extractaudio'] = True
        config['audioformat'] = 'mp3'
    else:
        config['outtmpl'] = os.path.join(output_dir, '%(title)s.%(ext)s')
    
    # Configure post-processors for format merging (when video+audio are separate)
    config['postprocessors'] = [
        {
            'key': 'FFmpegMerger',
            'when': 'post_process'
        }
    ]
    config['postprocessor_args'] = ['-c', 'copy']
    logger.info(f"[Worker] FFmpeg post-processor configured for format merging")
    
    # Handle format selection
    logger.info(f"[Worker] Task format_ids: {task.format_ids}")
    if task.format_ids:
        if isinstance(task.format_ids, str):
            format_ids = task.format_ids.split(',')
        else:
            format_ids = task.format_ids if isinstance(task.format_ids, list) else [task.format_ids]
        
        # Build format string with proper fallback chain
        # Each format separated by / as fallback
        format_str = '/'.join([fmt.strip() for fmt in format_ids if fmt])
        
        if format_str:
            config['format'] = format_str
            logger.info(f"[Worker] Using specified format: {format_str}")
        else:
            logger.warning(f"[Worker] Format IDs were empty after processing, using default")
    else:
        logger.info(f"[Worker] No specific format selected - using best available")
    
    # Add cookies if available
    # Note: CookieManager.get_cookies_dict() doesn't exist, cookies are handled at the platform level
    # The platform (Kotlin) handles cookies via CookieManager and passes them through config if needed
    if hasattr(task, 'cookies') and task.cookies:
        cookie_file = CookieService.create_netscape_file(task.cookies)
        if cookie_file:
            config['cookiefile'] = cookie_file
            logger.info(f"[Worker] Using cookies from: {cookie_file}")
        else:
            logger.warning("[Worker] Failed to create cookie file from task cookies")
    
    # Set headers
    config['http_headers'] = HTTP_HEADERS
    
    # Progress hook
    final_files = []
    downloaded_thumbnail_path = None
    
    def progress_hook(d):
        if d['status'] == 'downloading':
            task.last_update = time.time()  # Prevent watchdog timeout
            
            # Extract formatted strings
            progress_str = d.get('_percent_str', '0.0%')
            speed_str = d.get('_speed_str', '0B/s')
            eta_str = d.get('_eta_str', 'Unknown')
            
            # Extract raw values
            total_bytes = d.get('total_bytes') or d.get('total_bytes_estimate', 0)
            downloaded_bytes = d.get('downloaded_bytes', 0)
            
            # Update task state for UI
            task.speed = speed_str
            task.eta = eta_str
            task.total_bytes = total_bytes
            task.downloaded_bytes = downloaded_bytes
            
            # Check for thumbnail during download
            thumbnail_path = d.get('filename', '')
            if thumbnail_path and thumbnail_path.endswith(('.jpg', '.jpeg', '.png')):
                # Extract thumbnail from temporary location
                nonlocal downloaded_thumbnail_path
                downloaded_thumbnail_path = thumbnail_path
            
            # Parse percentage
            try:
                # Remove % and whitespace, then convert to float
                clean_progress = progress_str.replace('%', '').strip()
                progress = float(clean_progress) / 100.0
                task.progress = progress
                task.status = "downloading"
                
                # Format friendly log message
                # e.g. "Downloading 20MB / 400 MB (5%) ETA: 30min Speed: 2MB/s"
                def format_bytes(b):
                    for unit in ['B', 'KB', 'MB', 'GB']:
                        if b < 1024: return f"{b:.1f}{unit}"
                        b /= 1024
                    return f"{b:.1f}TB"
                
                downloaded_str = format_bytes(downloaded_bytes)
                total_str = format_bytes(total_bytes) if total_bytes else "?"
                
                logger.info(f"[Worker] Downloading {downloaded_str} / {total_str} ({progress_str}) ETA: {eta_str} Speed: {speed_str}")
            except ValueError:
                # Fallback if percentage parsing fails
                logger.info(f"[Worker] Download progress update: {progress_str} (speed: {speed_str})")
        
        elif d['status'] == 'finished':
            task.last_update = time.time()
            filename = d.get('filename', '')
            if filename:
                final_files.append(filename)
                logger.info(f"[Worker] Downloaded: {filename}")
        
        elif d['status'] == 'error':
            task.last_update = time.time()
            error_msg = d.get('error', 'Unknown error')
            logger.error(f"[Worker] Download error: {error_msg}")
            task.status = "error"
            task.error = error_msg
    
    config['progress_hooks'] = [progress_hook]
    
    # Execute download
    try:
        logger.info(f"[Worker] Starting download with format: {config.get('format', 'best')}")
        logger.info(f"[Worker] Player clients: {config.get('extractor_args', {}).get('youtube', {}).get('player_client', [])}")
        logger.info(f"[Worker] JS runtimes: {config.get('js_runtimes', {})}")
        logger.info(f"[Worker] Remote components: {config.get('remote_components', [])}")
        
        info = None
        downloaded_files = []
        
        # Use standard yt-dlp download with FFmpeg post-processing
        with YoutubeDL(config) as ydl:
            try:
                info = ydl.extract_info(task.url, download=True)
            except Exception as download_error:
                error_msg = str(download_error)
                logger.error(f"[Worker] Download extraction failed: {error_msg}")
                
                # Try to provide helpful error messages
                if "403" in error_msg or "sign" in error_msg.lower():
                    logger.error("[Worker] ❌ YouTube signature/access error - may require updated player or authentication")
                    raise Exception(f"YouTube access denied: {error_msg[:100]}")
                elif "n-" in error_msg.lower() or "challenge" in error_msg.lower():
                    logger.error("[Worker] ❌ YouTube n-parameter challenge failed - may need QuickJS/EJS")
                    raise Exception(f"YouTube challenge solving failed: {error_msg[:100]}")
                elif "http" in error_msg.lower() or "connection" in error_msg.lower():
                    logger.error("[Worker] ❌ Network error - check internet connection")
                    raise Exception(f"Network error: {error_msg[:100]}")
                else:
                    raise
            
            if info:
                if '_filename' in info:
                    downloaded_files.append(info['_filename'])
                
                if 'requested_downloads' in info:
                    for dl in info['requested_downloads']:
                        if 'filepath' in dl:
                            downloaded_files.append(dl['filepath'])
        
        if info:
            task.status = "completed"
            task.progress = 0.7  # 70% for download completion
            task.final_filename = downloaded_files[0] if downloaded_files else None
            
            logger.info(f"[Worker] ✓ Download completed: {downloaded_files}")
            
            # yt-dlp handles FFmpeg post-processing internally
            # No need for manual stream merging
            processed_files = downloaded_files
            processing_results = {}
            
            # Embed metadata into processed files
            embedded_metadata = {}
            if task.embed_metadata and processed_files:
                task.status = "embedding"
                task.progress = 0.9  # 90% for metadata embedding
                
                for file_path in processed_files:
                    try:
                        logger.info(f"[Worker] Embedding metadata for: {os.path.basename(file_path)}")
                        result = metadata_embedder.embed_metadata(file_path, info)
                        if result["success"]:
                            embedded_metadata[file_path] = result.get("embedded", {})
                            logger.info(f"[Worker] ✓ Metadata embedded successfully for {os.path.basename(file_path)}")
                        else:
                            logger.warning(f"[Worker] Metadata embedding failed for {os.path.basename(file_path)}: {result.get('error')}")
                    except Exception as e:
                        logger.error(f"[Worker] Error embedding metadata for {file_path}: {str(e)}")
            
            task.status = "completed"
            task.progress = 1.0  # 100% completion
            
            return {
                'success': True,
                'files': processed_files,
                'info': info,
                'task_id': task.id,
                'embedded_metadata': embedded_metadata,
                'processing_results': processing_results,
                'merged_streams': processing_results.get("merged_streams", False),
            }
        else:
            raise Exception("No download info returned")
                
    except Exception as e:
        error_msg = str(e)
        logger.error(f"[Worker] ❌ Download failed: {error_msg}")
        task.status = "error"
        task.error = error_msg
        
        return {
            'success': False,
            'error': error_msg,
            'task_id': task.id
        }
