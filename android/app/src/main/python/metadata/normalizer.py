from typing import Dict, List

class MetadataNormalizer:
    """Transforms raw yt-dlp data into standard formats."""
    
    def normalize_video(self, info: dict) -> dict:
        return {
            "id": info.get("id"),
            "title": info.get("title"),
            "thumbnail": info.get("thumbnail") or (info.get("thumbnails")[-1]["url"] if info.get("thumbnails") else ""),
            "duration": info.get("duration", 0),
            "uploader": info.get("uploader"),
            "view_count": info.get("view_count"),
            "formats": info.get("formats", []),
            "description": info.get("description", ""),
        }

    def normalize_playlist(self, info: dict) -> dict:
        entries = []
        for e in info.get("entries", []):
            if not e: continue
            entries.append({
                "id": e.get("id"),
                "title": e.get("title"),
                "url": e.get("url") or e.get("webpage_url") or f"https://www.youtube.com/watch?v={e.get('id')}",
                "uploader": e.get("uploader"),
                "duration": e.get("duration", 0),
            })
        return {
            "id": info.get("id"),
            "title": info.get("title"),
            "entries": entries,
            "count": len(entries),
            "type": "playlist"
        }

metadata_normalizer = MetadataNormalizer()
