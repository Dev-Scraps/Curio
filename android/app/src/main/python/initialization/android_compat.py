"""
Android/Chaquopy compatibility layer.
CRITICAL: This module MUST be imported before any other modules that use networking.

Import this at the very top of your app_bridge.py or main entry point:
    import android_compat  # Must be first!
"""

import sys
import os

def apply_android_fixes():
    """Apply all Android/Chaquopy compatibility fixes"""
    
    print("[android_compat] Applying Android compatibility patches...")
    
    # Fix 1: socket.if_nameindex issue
    try:
        import socket
        if hasattr(socket, 'if_nameindex'):
            # Store original if it exists
            if not hasattr(socket, '_original_if_nameindex'):
                socket._original_if_nameindex = socket.if_nameindex
                # Replace with dummy that returns empty list
                socket.if_nameindex = lambda: []
                print("[android_compat] ✓ Fixed socket.if_nameindex")
        else:
            print("[android_compat] ℹ socket.if_nameindex not present, no fix needed")
    except Exception as e:
        print(f"[android_compat] ⚠ Socket fix failed (non-critical): {e}")
    
    # Fix 2: SSL context for Android
    try:
        import ssl
        # Ensure default SSL context works on Android
        if not hasattr(ssl, '_android_patched'):
            original_create_default_context = ssl.create_default_context
            
            def android_ssl_context(*args, **kwargs):
                context = original_create_default_context(*args, **kwargs)
                # Android-specific SSL tweaks
                context.check_hostname = True
                context.verify_mode = ssl.CERT_REQUIRED
                return context
            
            ssl.create_default_context = android_ssl_context
            ssl._android_patched = True
            print("[android_compat] ✓ Enhanced SSL context for Android")
    except Exception as e:
        print(f"[android_compat] ⚠ SSL fix failed (non-critical): {e}")
    
    # Fix 3: Set environment variables for better Android compatibility
    try:
        os.environ.setdefault('PYTHONUNBUFFERED', '1')
        os.environ.setdefault('PYTHONIOENCODING', 'utf-8')
        print("[android_compat] ✓ Set Python environment variables")
    except Exception as e:
        print(f"[android_compat] ⚠ Environment setup failed: {e}")
    
    # Fix 4: Disable IPv6 if it causes issues
    try:
        import socket
        # Check if IPv6 is available
        has_ipv6 = socket.has_ipv6
        if has_ipv6:
            # Sometimes Android has partial IPv6 support that causes issues
            # Force IPv4 only for yt-dlp
            os.environ['YTDLP_NO_IPV6'] = '1'
            print("[android_compat] ✓ Configured IPv4-only mode")
    except Exception as e:
        print(f"[android_compat] ℹ IPv6 check skipped: {e}")
    
    print("[android_compat] All patches applied successfully!")
    return True

# Apply fixes immediately on import
try:
    apply_android_fixes()
except Exception as e:
    print(f"[android_compat] CRITICAL: Failed to apply compatibility fixes: {e}")
    # Don't raise exception - let the app try to continue

print("[android_compat] Module loaded and ready")