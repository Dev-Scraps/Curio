from typing import Dict, Optional
from initialization.bridge_logger import logger
from fetchers.yt_dlp_client import ytdlp_client
from metadata.normalizer import metadata_normalizer

class MetadataService:
    """Entry point for metadata extraction and normalization."""
    
    def get_info(self, url: str, flat: bool = False, cookies: Optional[str] = None) -> Dict:
        try:
            logger.info(f"[MetadataService] Extracting info for {url[:50]}...")
            
            raw = ytdlp_client.extract(url, flat=flat, cookies=cookies)
            
            if not raw:
                error_msg = "Extraction failed - no data returned from yt-dlp"
                logger.error(f"[MetadataService] ❌ {error_msg}")
                return {
                    "error": True, 
                    "message": error_msg,
                    "type": "extraction_failed"
                }
            
            # Determine if it's a playlist or single video
            if raw.get("entries") is not None:
                logger.info(f"[MetadataService] Detected playlist with {len(raw.get('entries', []))} entries")
                return metadata_normalizer.normalize_playlist(raw)
            
            logger.info(f"[MetadataService] ✓ Extracted video: {raw.get('title', 'Unknown')}")
            return metadata_normalizer.normalize_video(raw)
            
        except Exception as e:
            error_msg = str(e)
            logger.error(f"[MetadataService] ❌ Error during extraction: {error_msg}")
            
            # Provide specific error messages
            if "sign" in error_msg.lower() or "403" in error_msg:
                error_type = "signature_error"
            elif "n-" in error_msg.lower() or "challenge" in error_msg.lower():
                error_type = "challenge_error"
            elif "http" in error_msg.lower() or "connection" in error_msg.lower():
                error_type = "network_error"
            else:
                error_type = "unknown_error"
            
            return {
                "error": True,
                "message": error_msg,
                "type": error_type
            }

metadata_service = MetadataService()
