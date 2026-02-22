import os
import json
import subprocess
from typing import Dict, Optional, Any
from mutagen import File
from mutagen.id3 import ID3, TIT2, TPE1, TALB, TCON, TDRC, TRCK, TPE2, APIC
from mutagen.mp4 import MP4, MP4Cover
from mutagen.flac import Picture
from initialization.bridge_logger import logger


class MetadataEmbedder:
    """Service for embedding metadata into downloaded media files using Mutagen and FFmpeg."""
    
    def __init__(self):
        self.ffmpeg_available = True  # FFmpegKit is always available via bridge
        
    def embed_metadata(self, file_path: str, metadata: Dict[str, Any]) -> Dict[str, Any]:
        """
        Embed metadata into a media file.
        """
        try:
            if not os.path.exists(file_path):
                return {"success": False, "error": "File not found"}
            
            file_ext = os.path.splitext(file_path)[1].lower()
            logger.info(f"[MetadataEmbedder] Embedding metadata for {file_ext} file: {os.path.basename(file_path)}")
            
            # Extract metadata from input
            embedded_metadata = self._extract_metadata_dict(metadata)
            
            # Use Mutagen for audio files
            if file_ext in ['.mp3', '.flac', '.m4a', '.ogg']:
                result = self._embed_audio_metadata(file_path, embedded_metadata)
            # Use FFmpeg for video files
            elif file_ext in ['.mp4', '.mkv', '.avi', '.mov', '.webm']:
                result = self._embed_video_metadata(file_path, embedded_metadata)
            else:
                logger.warning(f"[MetadataEmbedder] Unsupported file format: {file_ext}")
                return {"success": False, "error": f"Unsupported format: {file_ext}"}
            
            if result["success"]:
                # Verify embedded metadata
                verified = self._extract_embedded_metadata(file_path)
                result["embedded"] = verified
                logger.info(f"[MetadataEmbedder] Successfully embedded metadata for {os.path.basename(file_path)}")
            
            return result
            
        except Exception as e:
            logger.error(f"[MetadataEmbedder] Error embedding metadata: {str(e)}")
            return {"success": False, "error": str(e)}
            
    def _extract_metadata_dict(self, metadata: Dict[str, Any]) -> Dict[str, str]:
        """Extract and normalize metadata from yt-dlp output."""
        return {
            "title": metadata.get("title", ""),
            "artist": metadata.get("uploader", metadata.get("channel", metadata.get("artist", ""))),
            "album": metadata.get("album", "YouTube Download"),
            "genre": "YouTube",
            "date": metadata.get("upload_date", ""),
            "track": metadata.get("track", ""),
            "description": metadata.get("description", ""),
            "duration": str(metadata.get("duration", 0)),
            "url": metadata.get("webpage_url", metadata.get("url", "")),
            "channel_url": metadata.get("channel_url", ""),
            "thumbnail_url": metadata.get("thumbnail", ""),
        }
        
    def _embed_audio_metadata(self, file_path: str, metadata: Dict[str, str]) -> Dict[str, Any]:
        """Embed metadata into audio files using Mutagen."""
        try:
            audio_file = File(file_path)
            if audio_file is None:
                return {"success": False, "error": "Could not read audio file"}
            
            # Handle different audio formats
            if file_path.endswith('.mp3'):
                return self._embed_mp3_metadata(audio_file, metadata)
            elif file_path.endswith('.m4a'):
                return self._embed_mp4_metadata(audio_file, metadata)
            elif file_path.endswith('.flac'):
                return self._embed_flac_metadata(audio_file, metadata)
            else:
                return self._embed_generic_metadata(audio_file, metadata)
        except Exception as e:
            logger.error(f"[MetadataEmbedder] Audio embedding error: {str(e)}")
            return {"success": False, "error": str(e)}

    def _embed_mp3_metadata(self, audio_file: File, metadata: Dict[str, str]) -> Dict[str, Any]:
        """Embed metadata into MP3 files."""
        try:
            if audio_file.tags is None: audio_file.add_tags()
            if metadata["title"]: audio_file.tags["TIT2"] = TIT2(encoding=3, text=metadata["title"])
            if metadata["artist"]: audio_file.tags["TPE1"] = TPE1(encoding=3, text=metadata["artist"])
            if metadata["album"]: audio_file.tags["TALB"] = TALB(encoding=3, text=metadata["album"])
            if metadata["genre"]: audio_file.tags["TCON"] = TCON(encoding=3, text=metadata["genre"])
            if metadata["date"]: audio_file.tags["TDRC"] = TDRC(encoding=3, text=metadata["date"])
            if metadata["track"]: audio_file.tags["TRCK"] = TRCK(encoding=3, text=metadata["track"])
            if metadata["thumbnail_url"]: self._add_album_art(audio_file, metadata["thumbnail_url"])
            audio_file.save()
            return {"success": True, "format": "MP3"}
        except Exception as e:
            return {"success": False, "error": f"MP3 embedding failed: {str(e)}"}

    def _embed_mp4_metadata(self, audio_file: File, metadata: Dict[str, str]) -> Dict[str, Any]:
        """Embed metadata into M4A/MP4 files."""
        try:
            if not audio_file.tags: audio_file.add_tags()
            if metadata["title"]: audio_file.tags["\xa9nam"] = metadata["title"]
            if metadata["artist"]: audio_file.tags["\xa9ART"] = metadata["artist"]
            if metadata["album"]: audio_file.tags["\xa9alb"] = metadata["album"]
            if metadata["genre"]: audio_file.tags["\xa9gen"] = metadata["genre"]
            if metadata["date"]: audio_file.tags["\xa9day"] = metadata["date"]
            if metadata["track"]: audio_file.tags["trkn"] = [int(metadata["track"]), 0]
            audio_file.save()
            return {"success": True, "format": "M4A"}
        except Exception as e:
            return {"success": False, "error": f"M4A embedding failed: {str(e)}"}
            
    def _embed_flac_metadata(self, audio_file: File, metadata: Dict[str, str]) -> Dict[str, Any]:
        """Embed metadata into FLAC files."""
        try:
            if not audio_file.tags: audio_file.add_tags()
            if metadata["title"]: audio_file.tags["TITLE"] = metadata["title"]
            if metadata["artist"]: audio_file.tags["ARTIST"] = metadata["artist"]
            if metadata["album"]: audio_file.tags["ALBUM"] = metadata["album"]
            if metadata["genre"]: audio_file.tags["GENRE"] = metadata["genre"]
            if metadata["date"]: audio_file.tags["DATE"] = metadata["date"]
            if metadata["track"]: audio_file.tags["TRACKNUMBER"] = metadata["track"]
            audio_file.save()
            return {"success": True, "format": "FLAC"}
        except Exception as e:
            return {"success": False, "error": f"FLAC embedding failed: {str(e)}"}
            
    def _embed_generic_metadata(self, audio_file: File, metadata: Dict[str, str]) -> Dict[str, Any]:
        try:
            if not audio_file.tags: audio_file.add_tags()
            for key, value in metadata.items():
                if value and key.lower() in ["title", "artist", "album", "genre", "date"]:
                    audio_file.tags[key.upper()] = value
            audio_file.save()
            return {"success": True, "format": "Generic"}
        except Exception as e:
            return {"success": False, "error": f"Generic embedding failed: {str(e)}"}

    def _embed_video_metadata(self, file_path: str, metadata: Dict[str, str]) -> Dict[str, Any]:
        """Embed metadata into video files using FFmpegKit bridge."""
        try:
            from ffmpeg_bridge import execute_ffmpeg
            
            # Create temporary file for metadata
            temp_metadata_file = file_path + ".metadata.json"
            with open(temp_metadata_file, 'w', encoding='utf-8') as f:
                json.dump(metadata, f, ensure_ascii=False, indent=2)
            
            # FFmpeg command to embed metadata (no 'ffmpeg' prefix)
            output_file = file_path + ".temp"
            
            # Construct metadata arguments
            metadata_args = ""
            for k, v in metadata.items():
                if v:
                    # Escape quotes for shell/command string
                    v_safe = str(v).replace('"', '\\"')
                    metadata_args += f'-metadata {k}="{v_safe}" '
            
            cmd = f'-i "{file_path}" {metadata_args} -c copy -y "{output_file}"'
            
            result = execute_ffmpeg(cmd)
            
            # Clean up temp files
            try:
                if os.path.exists(temp_metadata_file):
                    os.remove(temp_metadata_file)
            except: pass
            
            if result['success']:
                # Replace original file with the metadata-embedded version
                os.replace(output_file, file_path)
                return {"success": True, "format": "Video"}
            else:
                # Clean up failed output file
                try:
                    if os.path.exists(output_file):
                        os.remove(output_file)
                except: pass
                return {"success": False, "error": f"FFmpeg bridge failed: {result['error']}"}
                
        except Exception as e:
            logger.error(f"[MetadataEmbedder] Video embedding failed: {str(e)}")
            return {"success": False, "error": f"Video embedding failed: {str(e)}"}
            
    def _add_album_art(self, audio_file: File, thumbnail_url: str):
        # ... (rest of the file stays same) ...
        try:
            import urllib.request
            with urllib.request.urlopen(thumbnail_url, timeout=10) as response:
                image_data = response.read()
            if isinstance(audio_file.tags, ID3):
                audio_file.tags["APIC"] = APIC(encoding=3, mime='image/jpeg', type=3, desc='Cover', data=image_data)
            elif hasattr(audio_file.tags, 'covr'):
                audio_file.tags['covr'] = [MP4Cover(image_data, MP4Cover.FORMAT_JPEG)]
        except Exception as e:
            logger.warning(f"[MetadataEmbedder] Failed to add album art: {str(e)}")
    
    def _extract_embedded_metadata(self, file_path: str) -> Dict[str, Any]:
        try:
            audio_file = File(file_path)
            if audio_file is None or audio_file.tags is None: return {}
            metadata = {}
            tag_mapping = {
                'TIT2': 'title', '\xa9nam': 'title', 'TITLE': 'title',
                'TPE1': 'artist', '\xa9ART': 'artist', 'ARTIST': 'artist',
                'TALB': 'album', '\xa9alb': 'album', 'ALBUM': 'album',
                'TCON': 'genre', '\xa9gen': 'genre', 'GENRE': 'genre',
                'TDRC': 'date', '\xa9day': 'date', 'DATE': 'date',
                'TRCK': 'track', 'trkn': 'track', 'TRACKNUMBER': 'track',
            }
            for tag_key, metadata_key in tag_mapping.items():
                if tag_key in audio_file.tags:
                    value = audio_file.tags[tag_key]
                    if hasattr(value, 'text'):
                        metadata[metadata_key] = str(value.text[0]) if value.text else ""
                    elif isinstance(value, list) and value:
                        metadata[metadata_key] = str(value[0])
                    else:
                        metadata[metadata_key] = str(value)
            return metadata
        except Exception as e:
            logger.warning(f"[MetadataEmbedder] Failed to extract embedded metadata: {str(e)}")
            return {}

# Global instance
metadata_embedder = MetadataEmbedder()
