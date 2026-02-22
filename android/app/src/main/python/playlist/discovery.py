from typing import Optional, List, Dict
from initialization.bridge_logger import logger
from formats.bridge_config import PLAYLIST_URLS, SPECIAL_PLAYLISTS, VALID_PLAYLIST_PREFIXES
from fetchers.yt_dlp_client import ytdlp_client

class PlaylistDiscovery:
    """Handles the discovery of user playlists from various YouTube feeds."""
    
    def discover(self, cookies: Optional[str] = None) -> Dict:
        all_playlists = []
        seen_ids = set()

        # 1. Add special playlists (Liked, Watch Later)
        for sid, title in SPECIAL_PLAYLISTS:
            all_playlists.append({
                "id": sid, 
                "title": title, 
                "type": "special",
                "url": f"https://www.youtube.com/playlist?list={sid}",
                "playlist_count": 0,
            })
            seen_ids.add(sid)
        
        if not cookies:
            return self._build_response(all_playlists, status="limited")

        # 2. Scrape YouTube library/playlists pages
        for url, desc in PLAYLIST_URLS:
            try:
                raw = ytdlp_client.extract(url, flat=True, cookies=cookies, is_playlist=True)
                if not raw: continue
                
                entries = self._extract_entries(raw)
                for entry in entries:
                    pid = self._get_playlist_id(entry)
                    if not pid or pid in seen_ids or not self._is_valid_pid(pid):
                        continue
                    
                    all_playlists.append(self._parse_playlist_info(entry, pid))
                    seen_ids.add(pid)
                    
            except Exception as e:
                logger.error(f"[PlaylistDiscovery] Error fetching {desc}: {e}")
                continue

        return self._build_response(all_playlists)

    def _extract_entries(self, raw: dict) -> list:
        if raw.get("_type") == "playlist":
            return raw.get("entries", [])
        return raw.get("entries", [])

    def _get_playlist_id(self, entry: dict) -> Optional[str]:
        pid = entry.get("id") or entry.get("playlist_id")
        if not pid:
            url = entry.get("url", "")
            if "list=" in url:
                pid = url.split("list=")[1].split("&")[0]
        return pid

    def _is_valid_pid(self, pid: str) -> bool:
        return any(pid.startswith(p) for p in VALID_PLAYLIST_PREFIXES)

    def _parse_playlist_info(self, entry: dict, pid: str) -> dict:
        return {
            "id": pid,
            "title": entry.get("title") or "Unknown Playlist",
            "playlist_count": entry.get("playlist_count") or entry.get("video_count") or 0,
            "thumbnail": entry.get("thumbnail") or entry.get("thumbnails", [{}])[0].get("url"),
            "url": entry.get("url") or f"https://www.youtube.com/playlist?list={pid}",
            "uploader": entry.get("uploader") or entry.get("channel") or "You",
        }

    def _build_response(self, playlists: list, status: str = "success") -> dict:
        return {
            "playlists": playlists,
            "count": len(playlists),
            "status": status,
            "message": f"Found {len(playlists)} playlists"
        }

playlist_discovery = PlaylistDiscovery()
