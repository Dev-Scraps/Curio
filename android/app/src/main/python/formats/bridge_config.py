"""
Configuration for yt-dlp bridge with optimized settings for Android/Chaquopy.
Includes all YouTube library feed URLs for comprehensive playlist discovery.
"""

# HTTP Headers for requests
HTTP_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

# Cache settings
CACHE_ENABLED = True
CACHE_TTL_MINUTES = 60

# Base yt-dlp configuration (Android-compatible)
YTDLP_BASE_CONFIG = {
    "quiet": False,  # Show warnings for debugging
    "no_warnings": False,
    "extract_flat": False,
    "socket_timeout": 30,
    "source_address": None,
    "nocheckcertificate": False,
    "prefer_insecure": False,
    "ignoreerrors": False,
    "no_color": True,
    "call_home": False,
}

# Fast extraction mode (basic info only)
YTDLP_FLAT_CONFIG = {
    **YTDLP_BASE_CONFIG,
    "extract_flat": "in_playlist",
    "skip_download": True,
    "getcomments": False,
    "getsubtitles": False,
    "writesubtitles": False,
    "extractor_args": {
        "youtube": {
            "player_client": ["web", "ios"],  # Web first for availability, iOS as fallback
        }
    },
    # Keep remote components for fallback
    "remote_components": ["ejs:npm"],
}

# Full extraction mode (complete metadata)
YTDLP_FULL_CONFIG = {
    **YTDLP_BASE_CONFIG,
    "extract_flat": False,
    "skip_download": True,
    "getcomments": False,
    "getsubtitles": False,
    "writesubtitles": False,
    # List all available formats without selecting one
    "listformats": "all",
    "extractor_args": {
        "youtube": {
            "player_client": ["web", "ios"],  # Web first, iOS fallback for format availability
        }
    },
    # Enable remote components for EJS challenge solver scripts
    "remote_components": ["ejs:npm"],
}

# Default download configuration (Single-format mode with optimized player clients)
YTDLP_DOWNLOAD_CONFIG = {
    **YTDLP_BASE_CONFIG,
    "skip_download": False,
    "progress": True,
    # JavaScript runtime (QuickJS) configured dynamically in worker.py
    "extractor_args": {
        "youtube": {
            "player_client": ["web", "ios"],  # Web first for format availability, iOS as fallback
        }
    },
    # Enable remote components for EJS challenge solver
    "remote_components": ["ejs:npm"],
    # FFmpeg post-processors for stream merging (configured by worker based on format)
    "postprocessors": [],  # Set dynamically in worker.py
    # Flexible format selection - try best qualities with various fallbacks
    "format": "(bestvideo[ext=mp4]+bestaudio[ext=m4a])/bestvideo+bestaudio/best[ext=mp4]/best",
    "merge_output_format": "mp4",  # Merge to MP4
    "audioformat": "mp3",  # Audio extraction format
    "audioquality": "192",  # Audio quality
    "embed_subs": False,  # Disable subtitle embedding
    "writeinfojson": False,
    "writethumbnail": False,
    # Post-processing options
    "keep_video": False,
    "no_post_overwrites": True,
    "embed_chapters": False,
    "embed_metadata": False,
    # Format merging
    "check_formats": True,  # Validate formats before download
    "allow_unplayable_formats": False,
    # Playlist options
    "noplaylist": False,
    "extract_flat": False,
}

# Audio-only download configuration (Native mode)
YTDLP_AUDIO_ONLY_CONFIG = {
    **YTDLP_BASE_CONFIG,
    "skip_download": False,
    "progress": True,
    # JavaScript runtime (QuickJS) configured dynamically in worker.py
    "extractor_args": {
        "youtube": {
            "player_client": ["web", "ios"],  # Web client for broader audio format availability
        }
    },
    # Enable remote components for EJS challenge solver
    "remote_components": ["ejs:npm"],
    # FFmpeg post-processing for audio extraction
    "postprocessors": [
        {
            "key": "FFmpegExtractAudio",
            "preferredcodec": "mp3",
            "preferredquality": "192",
        }
    ],
    # Audio-only format selection with fallbacks
    "format": "bestaudio[ext=m4a]/bestaudio/best",  # Prefer M4A audio, then any audio format
    "extractaudio": True,
    "audioformat": "mp3",
    "audioquality": "192",
    "embed_subs": False,
    "writeinfojson": False,
    "writethumbnail": False,
    # Post-processing options
    "keep_video": False,
    "no_post_overwrites": True,
    "embed_chapters": False,
    "embed_metadata": False,
}

# Separate stream download configuration for FFmpeg merging
YTDLP_SEPARATE_STREAMS_CONFIG = {
    **YTDLP_BASE_CONFIG,
    "skip_download": False,
    "progress": True,
    # JavaScript runtime (QuickJS) configured dynamically in worker.py
    "extractor_args": {
        "youtube": {
            "player_client": ["web", "ios"],  # Web client for best format availability
        }
    },
    # Enable remote components for EJS challenge solver
    "remote_components": ["ejs:npm"],
    # Post-processors for FFmpeg merging (will be set by worker)
    "postprocessors": [],
    # Download separate video and audio streams with flexible fallbacks
    "format": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best",  # Separate streams with fallbacks
    "merge_output_format": None,  # Don't merge with yt-dlp, use FFmpeg instead
    "keep_video": True,  # Keep video stream for FFmpeg merging
    "keep_audio": True,  # Keep audio stream for FFmpeg merging
    "embed_subs": False,
    "writeinfojson": False,
    "writethumbnail": False,
    "no_post_overwrites": True,
    "embed_chapters": False,
    "embed_metadata": False,
}

# Optimized for playlist extraction
YTDLP_PLAYLIST_CONFIG = {
    **YTDLP_BASE_CONFIG,
    "extract_flat": "in_playlist",
    "skip_download": True,
    "playlistend": None,  # Get all items
    "ignoreerrors": True,  # Continue on errors
    "getcomments": False,
    "getsubtitles": False,
    "extractor_args": {
        "youtube": {
            "player_client": ["web", "ios"],  # Web first, iOS fallback for playlist discovery
        }
    },
    "remote_components": ["ejs:npm"],  # Keep for fallback
}

# YouTube special playlist IDs
SPECIAL_PLAYLISTS = [
    ("LL", "Liked Videos"),
    ("WL", "Watch Later"),
]

# Valid YouTube playlist ID prefixes
VALID_PLAYLIST_PREFIXES = [
    "PL",  # Standard playlists
    # "UU",  # Uploads
    "LL",  # Liked videos
    "WL",  # Watch later
    # "FL",  # Favorites (legacy)
    # "RD",  # Radio/Mix
    # "OL",  # Offline (YouTube Premium)
    # "UL",  # User uploads (legacy)
]

# YouTube library feed URLs for playlist discovery
# These URLs require authentication (cookies) to work
PLAYLIST_URLS = [
    # Primary library feed - contains all user playlists
    ("https://www.youtube.com/feed/library", "Library Feed"),
    
    # # Direct playlists page
    ("https://www.youtube.com/feed/playlists", "Playlists Page"),
    
    # Channel playlists (user's own channel)
    # ("https://www.youtube.com/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw/playlists", "My Channel Playlists"),
    
    # # Alternative: Use @me handle
    # ("https://www.youtube.com/@me/playlists", "@me Playlists"),
    
    # History (for Watch Later detection)
    # ("https://www.youtube.com/feed/history", "History Feed"),
    
    # Liked videos direct
    ("https://www.youtube.com/playlist?list=LL", "Liked Videos Playlist"),
    
    # Watch Later direct
    ("https://www.youtube.com/playlist?list=WL", "Watch Later Playlist"),
]

# Retry configuration
MAX_RETRIES = 5
RETRY_DELAY = 2  # seconds

# Logging configuration
LOG_LEVEL = "INFO"  # DEBUG, INFO, WARNING, ERROR
LOG_FORMAT = "[%(levelname)s] [%(name)s]: %(message)s"