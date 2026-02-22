"""
Metadata module for Curio Python bridge.
Provides video and playlist metadata extraction services.
"""

from .metadata_service import *
from .normalizer import *

__all__ = [
    'metadata_service',
    'normalize_metadata'
]
