import json
from typing import Any, Dict
from initialization.bridge_logger import logger

def safe_json(data: Any) -> str:
    """Safely convert any data to a JSON string."""
    try:
        if isinstance(data, str):
            # Already JSON or a string
            return data
        return json.dumps(data, ensure_ascii=False)
    except Exception as e:
        logger.error(f"[json_utils] Serialization error: {e}")
        return json.dumps({"error": True, "message": f"Serialization error: {str(e)}"})

def get_error_response(message: str) -> Dict[str, Any]:
    """Build a standard error response object."""
    return {
        "error": True,
        "message": message,
        "status": "error"
    }
