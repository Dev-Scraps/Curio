"""
QuickJS Binary Setup for Android
Handles extracting and deploying the QuickJS executable for YouTube challenge solving.

QuickJS binary is bundled in APK assets and extracted at runtime.
"""

import os
import subprocess
import shutil
import sys
from pathlib import Path


class QuickJSSetup:
    """Manages QuickJS binary extraction and setup for Android"""
    
    # Runtime paths on Android device
    QUICKJS_BIN_PATHS = [
        '/data/data/com.curio.app/files/qjs',
        '/data/user/0/com.curio.app/files/qjs',
    ]
    
    # Assets path within the APK (extracted by Android)
    ASSETS_QJS_PATH = None  # Will be set by extract_from_assets
    
    @staticmethod
    def check_quickjs_available():
        """Check if QuickJS is already deployed and available"""
        for path in QuickJSSetup.QUICKJS_BIN_PATHS:
            if os.path.exists(path):
                try:
                    # Test if it's actually executable
                    result = subprocess.run(
                        [path],
                        input='console.log("test")',
                        capture_output=True,
                        text=True,
                        timeout=2
                    )
                    if result.returncode == 0:
                        return path
                except Exception as e:
                    print(f"[QuickJS] Found at {path} but not executable: {e}")
        return None
    
    @staticmethod
    def extract_from_assets():
        """Extract QuickJS from APK assets to app files directory"""
        try:
            from jnius import autoclass
            PythonActivity = autoclass('org.renpy.android.PythonActivity')
            Build = autoclass('android.os.Build')
            context = PythonActivity.mActivity

            abis = list(Build.SUPPORTED_ABIS)
            arch = abis[0] if abis else "arm64-v8a"
            asset_path = f"quickjs/{arch}/qjs"

            target_dir = '/data/data/com.curio.app/files'
            os.makedirs(target_dir, exist_ok=True)
            target_path = os.path.join(target_dir, 'qjs')

            try:
                asset_manager = context.getAssets()
                input_stream = asset_manager.open(asset_path)
                with open(target_path, 'wb') as output_stream:
                    output_stream.write(input_stream.read())
                input_stream.close()
                os.chmod(target_path, 0o755)
                print(f"[QuickJS] ✓ Extracted from assets: {target_path}")
                return target_path
            except Exception as e:
                print(f"[QuickJS] Failed to extract from assets ({asset_path}): {e}")
        except Exception as e:
            print(f"[QuickJS] Could not access Android assets: {e}")
        
        return None
    
    @staticmethod
    def deploy_bundled_binary():
        """Deploy bundled QuickJS binary to app files directory"""
        # Check standard bundled locations
        bundled_paths = [
            os.path.join(os.path.dirname(__file__), '..', '..', 'qjs'),
            os.path.join(os.path.dirname(__file__), '..', 'qjs'),
        ]
        
        for bundled_path in bundled_paths:
            if not os.path.exists(bundled_path):
                continue
            
            target_dir = '/data/data/com.curio.app/files'
            os.makedirs(target_dir, exist_ok=True)
            target_path = os.path.join(target_dir, 'qjs')
            
            try:
                shutil.copy2(bundled_path, target_path)
                os.chmod(target_path, 0o755)
                print(f"[QuickJS] ✓ Deployed bundled binary: {target_path}")
                return target_path
            except Exception as e:
                print(f"[QuickJS] Failed to deploy from {bundled_path}: {e}")
        
        return None
    
    @staticmethod
    def setup_symlink_from_python_package():
        """Create symlink to QuickJS from Python package if available (fallback)"""
        try:
            import quickjs
            pkg_dir = os.path.dirname(quickjs.__file__)
            
            potential_paths = [
                os.path.join(pkg_dir, 'qjs'),
                os.path.join(pkg_dir, 'bin', 'qjs'),
                os.path.join(os.path.dirname(pkg_dir), 'bin', 'qjs'),
            ]
            
            for python_qjs in potential_paths:
                if not (os.path.exists(python_qjs) and os.access(python_qjs, os.X_OK)):
                    continue
                
                target_dir = '/data/data/com.curio.app/files'
                os.makedirs(target_dir, exist_ok=True)
                target_path = os.path.join(target_dir, 'qjs')
                
                try:
                    # Remove old symlink/file if exists
                    if os.path.lexists(target_path):
                        os.unlink(target_path)
                    
                    # Create symlink
                    os.symlink(python_qjs, target_path)
                    os.chmod(target_path, 0o755)
                    
                    print(f"[QuickJS] ✓ Symlink created: {target_path} -> {python_qjs}")
                    return target_path
                except Exception as e:
                    print(f"[QuickJS] Failed to create symlink: {e}")
                    continue
        except ImportError:
            print("[QuickJS] Python quickjs package not installed")
        except Exception as e:
            print(f"[QuickJS] Error searching Python packages: {e}")
        
        return None
    
    @staticmethod
    def initialize():
        """Initialize QuickJS - extract from assets or deploy bundled"""
        print("[QuickJS] Initializing QuickJS setup...")
        
        # Step 1: Check if QuickJS already available and working
        existing = QuickJSSetup.check_quickjs_available()
        if existing:
            print(f"[QuickJS] ✓ QuickJS already available at: {existing}")
            return existing
        
        # Step 2: Try to extract from APK assets (preferred method)
        print("[QuickJS] Step 1: Checking APK assets...")
        assets = QuickJSSetup.extract_from_assets()
        if assets:
            return assets
        
        # Step 3: Try to deploy bundled binary
        print("[QuickJS] Step 2: Checking bundled binary...")
        deployed = QuickJSSetup.deploy_bundled_binary()
        if deployed:
            return deployed
        
        # Step 4: Try to symlink from Python quickjs package (fallback)
        print("[QuickJS] Step 3: Trying symlink fallback...")
        symlink = QuickJSSetup.setup_symlink_from_python_package()
        if symlink:
            return symlink
        
        # Step 5: No QuickJS found - will use fallback runtime
        print("[QuickJS] ❌ QuickJS not found - will fallback to deno/node")
        return None


# Auto-initialize on import
if __name__ != '__main__':
    try:
        QuickJSSetup.initialize()
    except Exception as e:
        print(f"[QuickJS] Setup error: {e}")
