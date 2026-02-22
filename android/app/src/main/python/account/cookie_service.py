"""
Authentication cookie management for Curio Python Bridge.
"""

import tempfile
import os
from initialization.bridge_logger import logger

class CookieService:
    @staticmethod
    def create_netscape_file(cookie_str):
        if not cookie_str or not cookie_str.strip(): return None
        try:
            # Simple conversion if it's just raw name=value pairs
            content = "# Netscape HTTP Cookie File\n"
            if "Netscape" not in cookie_str:
                for line in cookie_str.split(';'):
                    if '=' in line:
                        k, v = line.strip().split('=', 1)
                        content += f".youtube.com\tTRUE\t/\tTRUE\t2147483647\t{k}\t{v}\n"
            else: content = cookie_str

            tmp = tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False)
            tmp.write(content)
            tmp.close()
            return tmp.name
        except Exception as e:
            logger.error(f"Cookie creation error: {e}")
            return None

    @staticmethod
    def cleanup(path):
        if path and os.path.exists(path):
            try: os.unlink(path)
            except: pass

class CookieManager:
    def __init__(self, cookies): self.cookies = cookies; self.path = None
    def __enter__(self):
        self.path = CookieService.create_netscape_file(self.cookies)
        return self.path
    def __exit__(self, *args):
        CookieService.cleanup(self.path)
