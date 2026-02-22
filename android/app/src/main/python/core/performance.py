import time
from functools import wraps
from initialization.bridge_logger import logger

def time_it(func):
    """Decorator to measure execution time of bridge functions."""
    @wraps(func)
    def wrapper(*args, **kwargs):
        start = time.time()
        result = func(*args, **kwargs)
        end = time.time()
        logger.debug(f"{func.__name__} took {end - start:.4f}s")
        return result
    return wrapper
