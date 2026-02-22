import time
from typing import Dict, Any, Optional

class DownloadTask:
    """Model representing a single download task and its state."""
    
    def __init__(self, tid: str, url: str, info: Optional[Dict] = None):
        self.id = tid
        self.url = url
        self.info = info or {"title": "Loading..."}
        self.status = "queued"  # queued, downloading, processing, embedding, finished, cancelled, error
        self.progress = 0.0
        self.speed = "0 B/s"
        self.eta = "N/A"
        self.cancel_flag = False
        self.last_update = time.time()
        self.filename = ""
        self.final_filename = ""  # Final file path after post-processing
        self.error = None
        self.total_bytes = 0
        self.downloaded_bytes = 0
        self.embed_metadata = True  # Whether to embed metadata
        self.download_type = "video"  # "video", "audio", or "separate_streams"
        self.use_ffmpeg = True  # Whether to use FFmpeg for stream merging
        
        # FFmpeg processing options
        self.extract_audio = False  # Extract audio from video
        self.audio_format = "mp3"  # Audio format for extraction (mp3, aac, opus, etc.)
        self.audio_quality = "192k"  # Audio quality (128k, 192k, 320k, etc.)
        
        self.convert_video = False  # Convert video format
        self.target_format = "mp4"  # Target video format
        self.video_codec = "libx264"  # Video codec
        self.resolution = None  # Target resolution (e.g., "1280x720")
        
        self.optimize_mobile = False  # Optimize for mobile playback
        self.target_size_mb = None  # Target file size in MB
        
        self.embed_subtitles = False  # Embed subtitles
        self.subtitle_file = None  # Path to subtitle file
        self.subtitle_language = "eng"  # Subtitle language code
        self.output_dir = None  # Output directory for downloads
        self.format_ids = None  # Format IDs for download

    def to_dict(self) -> Dict[str, Any]:
        """Convert task state to a dictionary for JSON bridge."""
        return {
            **self.info,
            "id": self.id,
            "status": self.status,
            "progress": self.progress,
            "speed": self.speed,
            "eta": self.eta,
            "filename": self.filename,
            "final_filename": self.final_filename,  # Include final file path
            "error": self.error,
            "total_bytes": self.total_bytes,
            "downloaded_bytes": self.downloaded_bytes,
            "embed_metadata": self.embed_metadata,
            "download_type": self.download_type,
            "use_ffmpeg": self.use_ffmpeg,
            # FFmpeg processing options
            "extract_audio": self.extract_audio,
            "audio_format": self.audio_format,
            "audio_quality": self.audio_quality,
            "convert_video": self.convert_video,
            "target_format": self.target_format,
            "video_codec": self.video_codec,
            "resolution": self.resolution,
            "optimize_mobile": self.optimize_mobile,
            "target_size_mb": self.target_size_mb,
            "embed_subtitles": self.embed_subtitles,
            "subtitle_file": self.subtitle_file,
            "subtitle_language": self.subtitle_language,
            "output_dir": self.output_dir,
            "format_ids": self.format_ids,
        }
