#!/usr/bin/env python3
"""
FFmpeg wrapper script that finds and executes the actual FFmpeg binary
extracted from app assets.
"""
import sys
import os
import subprocess

try:
    # Get command-line arguments (skip script name)
    args = sys.argv[1:]
    
    # The FFmpeg binaries are extracted to app's files directory:
    # /data/data/com.curio.app/files/ffmpeg
    # /data/data/com.curio.app/files/ffprobe
    
    possible_ffmpeg_paths = [
        "/data/data/com.curio.app/files/ffmpeg",
        "/data/data/com.curio.app/files/ffprobe",
        "/data/data/com.curio.app/cache/bin/ffmpeg",
        "/data/data/com.curio.app/cache/bin/ffprobe",
    ]
    
    # Determine if we're being called as ffmpeg or ffprobe
    script_name = os.path.basename(sys.argv[0])
    if script_name == "ffprobe":
        possible_ffmpeg_paths = [
            "/data/data/com.curio.app/files/ffprobe",
            "/data/data/com.curio.app/files/ffmpeg",
        ]
    
    ffmpeg_binary = None
    for path in possible_ffmpeg_paths:
        if os.path.exists(path):
            ffmpeg_binary = path
            break
    
    if not ffmpeg_binary:
        # Fallback: try to use the FFmpeg from PATH
        import shutil
        ffmpeg_binary = shutil.which("ffmpeg") or shutil.which("ffprobe")
    
    if not ffmpeg_binary:
        print("FFmpeg binary not found. Please ensure FFmpeg binaries are bundled in app assets.", file=sys.stderr)
        sys.exit(1)
    
    # Execute FFmpeg directly
    result = subprocess.run(
        [ffmpeg_binary] + args,
        capture_output=True,
        text=True
    )
    
    # Print output (yt-dlp expects stdout)
    if result.stdout:
        print(result.stdout, end='')
    
    # Print errors to stderr
    if result.stderr:
        print(result.stderr, file=sys.stderr, end='')
    
    # Exit with appropriate code
    sys.exit(result.returncode)
    
except Exception as e:
    print(f"FFmpeg wrapper error: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc(file=sys.stderr)
    sys.exit(1)
