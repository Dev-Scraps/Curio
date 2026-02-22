import os
import subprocess
import json
import re
import time
from typing import Dict, Any, Optional, List, Tuple, Callable
from initialization.bridge_logger import logger


class FFmpegService:
    """Service for FFmpeg audio/video stream merging with yt-dlp downloads."""
    
    def __init__(self):
        self.ffmpeg_path = self._get_ffmpeg_path()
        self.ffprobe_path = self._get_ffprobe_path()
        
    def _get_ffmpeg_path(self) -> str:
        """Get the path to FFmpeg executable (creating wrapper if needed)."""
        # Always use our custom wrapper in cache/bin to use FFmpegKit
        bin_dir = "/data/data/com.curio.app/cache/bin"
        ffmpeg_wrapper_path = os.path.join(bin_dir, "ffmpeg")
        
        # Ensure bin dir exists
        if not os.path.exists(bin_dir):
            try:
                os.makedirs(bin_dir, exist_ok=True)
            except Exception as e:
                logger.error(f"[FFmpegService] Failed to create bin dir: {e}")
                return ""

        # Create wrapper if it doesn't exist or if we want to be sure
        # We check existence to avoid writing on every init, but successful existence
        # check is faster than failing system calls
        try:
            if not os.path.exists(ffmpeg_wrapper_path):
                import sys
                python_path = sys.executable
                script_dir = os.path.join(os.path.dirname(__file__), "..", "bin")
                wrapper_script = os.path.join(script_dir, "ffmpeg_wrapper.py")
                wrapper_script = os.path.normpath(wrapper_script)
                
                with open(ffmpeg_wrapper_path, "w") as f:
                    f.write(f"#!/bin/sh\n{python_path} {wrapper_script} \"$@\"\n")
                os.chmod(ffmpeg_wrapper_path, 0o755)
                logger.info(f"[FFmpegService] Created FFmpeg wrapper at: {ffmpeg_wrapper_path}")
            else:
                logger.debug(f"[FFmpegService] Found existing FFmpeg wrapper")
                
            return ffmpeg_wrapper_path
            
        except Exception as e:
            logger.error(f"[FFmpegService] Failed to setup FFmpeg wrapper: {e}")
            # Even if creation failed, return path hoping it exists or will exist
            return ffmpeg_wrapper_path
    
    def _get_ffprobe_path(self) -> str:
        """Get path to FFprobe executable (creating wrapper if needed)."""
        bin_dir = "/data/data/com.curio.app/cache/bin"
        ffprobe_wrapper_path = os.path.join(bin_dir, "ffprobe")
        
        try:
            if not os.path.exists(ffprobe_wrapper_path):
                import sys
                python_path = sys.executable
                script_dir = os.path.join(os.path.dirname(__file__), "..", "bin")
                wrapper_script = os.path.join(script_dir, "ffmpeg_wrapper.py")
                wrapper_script = os.path.normpath(wrapper_script)
                
                with open(ffprobe_wrapper_path, "w") as f:
                    f.write(f"#!/bin/sh\n{python_path} {wrapper_script} \"$@\"\n")
                os.chmod(ffprobe_wrapper_path, 0o755)
                logger.info(f"[FFmpegService] Created FFprobe wrapper at: {ffprobe_wrapper_path}")
            
            return ffprobe_wrapper_path
            
        except Exception as e:
            logger.warning(f"[FFmpegService] Failed to setup FFprobe wrapper: {e}")
            return ffprobe_wrapper_path
    
    def merge_audio_video_streams(self, video_file: str, audio_file: str, output_file: str,
                                 video_codec: str = "copy", audio_codec: str = "aac",
                                 progress_callback: Optional[Callable[[float], None]] = None) -> Dict[str, Any]:
        """
        Merge separate audio and video streams using FFmpegKit bridge.
        """
        try:
            # Import bridge here to avoid circular imports during init
            from ffmpeg_bridge import execute_ffmpeg
            
            logger.info(f"[FFmpegService] Merging streams: {os.path.basename(video_file)} + {os.path.basename(audio_file)}")
            
            # Build FFmpeg command (no 'ffmpeg' prefix)
            # Add -movflags +faststart to fix seeking/corrupt file issues
            cmd = f'-i "{video_file}" -i "{audio_file}" -c:v {video_codec} -c:a {audio_codec} -movflags +faststart -y "{output_file}"'
            
            # Execute synchronously via bridge
            # Note: Progress callbacks not supported in synchronous bridge mode currently
            if progress_callback:
                progress_callback(0.5)
                
            result = execute_ffmpeg(cmd)
            
            if result['success']:
                if progress_callback:
                    progress_callback(1.0)
                    
                file_size = os.path.getsize(output_file) if os.path.exists(output_file) else 0
                logger.info(f"[FFmpegService] Stream merging completed: {os.path.basename(output_file)}")
                return {
                    "success": True,
                    "output_file": output_file,
                    "video_file": video_file,
                    "audio_file": audio_file,
                    "file_size": file_size
                }
            else:
                return {
                    "success": False, 
                    "error": f"FFmpeg failed with code {result['returnCode']}: {result['error']}"
                }
                
        except Exception as e:
            logger.error(f"[FFmpegService] Stream merging failed: {str(e)}")
            return {"success": False, "error": str(e)}

    def detect_separate_streams(self, downloaded_files: List[str]) -> Tuple[List[str], List[str], List[str]]:
        # ... (keep existing implementation but check ffprobe via bridge) ...
        # For simplicity, we can rely on filename patterns and extension checks
        # or implement _is_video_only via bridge
        
        video_files = []
        audio_files = []
        other_files = []
        
        for file_path in downloaded_files:
            if not os.path.exists(file_path):
                continue
                
            file_ext = os.path.splitext(file_path)[1].lower()
            file_name = os.path.basename(file_path).lower()
            
            # Simple extension/name heuristics first
            if file_ext in ['.mp4', '.mkv', '.webm']:
                if 'video' in file_name or 'drc' in file_name or '+' in file_name: # yt-dlp typical naming
                    video_files.append(file_path)
                else: 
                     # Use bridge for accurate detection if needed
                     if self._is_video_only_bridge(file_path):
                         video_files.append(file_path)
                     elif self._is_audio_only_bridge(file_path):
                         audio_files.append(file_path)
                     else:
                         other_files.append(file_path) # Likely muxed
            elif file_ext in ['.mp3', '.aac', '.m4a', '.wav', '.opus']:
                audio_files.append(file_path)
            else:
                other_files.append(file_path)
                
        logger.info(f"[FFmpegService] Stream detection: {len(video_files)} video, {len(audio_files)} audio")
        return video_files, audio_files, other_files

    def _is_video_only_bridge(self, file_path: str) -> bool:
        """Check if file is video-only using FFmpegKit bridge."""
        try:
            from ffmpeg_bridge import get_media_info
            info = get_media_info(file_path)
            if not info: return False
            
            # Parse FFprobe output (JSON or text depending on bridge implementation)
            # FFmpegHandler.getMediaInfo returns JSON string usually
            # But get_media_info in bridge parses it
            
            streams = info.get('streams', [])
            has_video = any(s.get('type') == 'video' for s in streams)
            has_audio = any(s.get('type') == 'audio' for s in streams)
            
            return has_video and not has_audio
        except:
            return False

    def _is_audio_only_bridge(self, file_path: str) -> bool:
        try:
            from ffmpeg_bridge import get_media_info
            info = get_media_info(file_path)
            if not info: return False
            
            streams = info.get('streams', [])
            has_video = any(s.get('type') == 'video' for s in streams)
            has_audio = any(s.get('type') == 'audio' for s in streams)
            
            return has_audio and not has_video
        except:
            return False

    def get_optimal_stream_pair(self, video_files: List[str], audio_files: List[str]) -> Tuple[Optional[str], Optional[str]]:
        if not video_files or not audio_files:
            return None, None
        best_video = max(video_files, key=lambda f: os.path.getsize(f) if os.path.exists(f) else 0)
        best_audio = max(audio_files, key=lambda f: os.path.getsize(f) if os.path.exists(f) else 0)
        return best_video, best_audio
    
    def cleanup_temporary_files(self, files_to_remove: List[str]) -> None:
        for file_path in files_to_remove:
            try:
                if os.path.exists(file_path):
                    os.remove(file_path)
            except: pass

    def is_available(self) -> bool:
        return True # Bridge is always available
        
    def get_version(self) -> str:
        try:
            from ffmpeg_bridge import get_ffmpeg_version
            return get_ffmpeg_version()
        except:
            return "Unknown"

# Global instance
ffmpeg_service = FFmpegService()
