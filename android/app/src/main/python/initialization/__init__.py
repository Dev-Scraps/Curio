"""
Initialization module for Curio Python bridge.
Provides Android compatibility and logging setup.
"""

from .android_compat import *
from .bridge_logger import *

__all__ = [
    'apply_android_fixes',
    'logger'
]
