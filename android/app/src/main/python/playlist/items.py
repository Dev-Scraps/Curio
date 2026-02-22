from typing import Optional, Dict
from initialization.bridge_logger import logger
from fetchers.yt_dlp_client import ytdlp_client

class PlaylistContent:
    """Handles fetching items within a playlist."""
    
    def get_items(self, playlist_id: str, cookies: Optional[str] = None, flat: bool = True) -> Dict:
        try:
            url = f"https://www.youtube.com/playlist?list={playlist_id}"
            logger.info(f"[PlaylistContent] Fetching items for {playlist_id}")
            
            result = ytdlp_client.extract(url, flat=flat, cookies=cookies, is_playlist=True)
            if not result:
                return {"error": True, "message": "Failed to fetch playlist items"}
            
            entries = result.get("entries", [])
            return {
                "playlist_id": playlist_id,
                "title": result.get("title", "Unknown Playlist"),
                "uploader": result.get("uploader") or result.get("channel"),
                "playlist_count": len(entries),
                "entries": entries,
                "error": False
            }
        except Exception as e:
            logger.error(f"[PlaylistContent] Error: {e}")
            return {"error": True, "message": str(e), "playlist_id": playlist_id}

playlist_content = PlaylistContent()
