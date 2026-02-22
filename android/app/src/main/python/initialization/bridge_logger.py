"""
Enhanced logging configuration for the bridge.
Provides detailed logs visible in Android logcat.
"""

import sys
import logging
from datetime import datetime

# Configure root logger
logging.basicConfig(
    level=logging.DEBUG,
    format='[%(asctime)s] [%(levelname)s] [%(name)s]: %(message)s',
    datefmt='%H:%M:%S',
    stream=sys.stdout,
    force=True
)

# Create main logger
logger = logging.getLogger('bridge')
logger.setLevel(logging.DEBUG)

# Create yt-dlp logger that integrates with our logging
class YTDLPLogger:
    """Custom logger for yt-dlp that routes to our logger"""
    
    def debug(self, msg):
        # Filter out overly verbose yt-dlp messages
        if msg.startswith('[debug]'):
            return
        logger.debug(f"[yt-dlp] {msg}")
    
    def info(self, msg):
        logger.info(f"[yt-dlp] {msg}")
    
    def warning(self, msg):
        logger.warning(f"[yt-dlp] {msg}")
    
    def error(self, msg):
        logger.error(f"[yt-dlp] {msg}")

ytdlp_logger = YTDLPLogger()

# Log startup
logger.info("=" * 60)
logger.info("Bridge Logger Initialized")
logger.info(f"Python version: {sys.version}")
logger.info(f"Platform: {sys.platform}")
logger.info("=" * 60)