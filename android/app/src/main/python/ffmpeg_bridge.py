"""
FFmpeg bridge for Python to call Kotlin FFmpegHandler
Allows yt-dlp and other Python code to use FFmpeg for post-processing
"""
import json
from typing import Dict, Any
from initialization.bridge_logger import logger

try:
    from java import jclass
    # Import the Kotlin FFmpegHandler class
    FFmpegHandler = jclass("com.curio.app.handlers.FFmpegHandler")
    FFMPEG_AVAILABLE = True
except Exception as e:
    logger.warning(f"FFmpegHandler not available: {e}")
    FFMPEG_AVAILABLE = False
    FFmpegHandler = None

def execute_ffmpeg(command: str) -> Dict[str, Any]:
    """
    Execute FFmpeg command via Kotlin FFmpegHandler
    
    Args:
        command: FFmpeg command string (without 'ffmpeg' prefix)
        
    Returns:
        dict with keys: success, returnCode, output, error
    """
    if not FFMPEG_AVAILABLE or FFmpegHandler is None:
        return {
            'success': False,
            'error': 'FFmpeg not available - FFmpegHandler not initialized'
        }
    
    try:
        result = FFmpegHandler.executeFFmpegCommand(command)
        return {
            'success': bool(result.get('success', False)),
            'returnCode': int(result.get('returnCode', -1)),
            'output': str(result.get('output', '')),
            'error': str(result.get('error', ''))
        }
    except Exception as e:
        logger.error(f"FFmpeg execution error: {e}")
        return {
            'success': False,
            'error': str(e)
        }

def get_media_info(file_path: str) -> Dict[str, Any]:
    """
    Get media file information using FFprobe
    
    Args:
        file_path: Path to media file
        
    Returns:
        dict with media information or error
    """
    if not FFMPEG_AVAILABLE or FFmpegHandler is None:
        return {'error': 'FFmpeg not available'}
    
    try:
        info_json = FFmpegHandler.getMediaInfo(file_path)
        return json.loads(info_json) if info_json else {}
    except Exception as e:
        logger.error(f"FFprobe error: {e}")
        return {'error': str(e)}

def merge_video_audio(video_path: str, audio_path: str, output_path: str) -> Dict[str, Any]:
    """
    Merge video and audio files using FFmpeg
    
    Args:
        video_path: Path to video file
        audio_path: Path to audio file
        output_path: Path for output file
        
    Returns:
        dict with success status and error if any
    """
    command = f'-i "{video_path}" -i "{audio_path}" -c copy "{output_path}"'
    return execute_ffmpeg(command)

def convert_format(input_path: str, output_path: str, codec_options: str = "") -> Dict[str, Any]:
    """
    Convert media file to different format
    
    Args:
        input_path: Input file path
        output_path: Output file path
        codec_options: Optional FFmpeg codec/format options
        
    Returns:
        dict with success status
    """
    command = f'-i "{input_path}" {codec_options} "{output_path}"'
    return execute_ffmpeg(command)

def extract_audio(video_path: str, audio_output_path: str, format: str = "mp3") -> Dict[str, Any]:
    """
    Extract audio from video file
    
    Args:
        video_path: Input video file
        audio_output_path: Output audio file path
        format: Audio format (mp3, aac, opus, etc.)
        
    Returns:
        dict with success status
    """
    command = f'-i "{video_path}" -vn -acodec copy "{audio_output_path}"'
    return execute_ffmpeg(command)

def is_ffmpeg_available() -> bool:
    """Check if FFmpeg is available"""
    return FFMPEG_AVAILABLE and FFmpegHandler is not None

def get_ffmpeg_version() -> str:
    """Get FFmpeg version string"""
    if not is_ffmpeg_available():
        return "unavailable"
    
    result = execute_ffmpeg("-version")
    if result.get('success'):
        output = result.get('output', '')
        # Extract first line which contains version
        version_line = output.split('\n')[0] if output else 'unknown'
        return version_line
    return "error"
