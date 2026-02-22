"""
Cookie validation and testing utility.
Helps diagnose authentication issues.
"""

from initialization.bridge_logger import logger

def validate_cookie_format(cookies: str) -> dict:
    """
    Validate that cookies are in correct Netscape format.
    
    Returns:
        dict with validation results
    """
    if not cookies or not isinstance(cookies, str):
        return {
            "valid": False,
            "error": "Cookies are empty or not a string",
            "cookie_count": 0
        }
    
    lines = cookies.strip().split('\n')
    valid_cookies = []
    errors = []
    
    for i, line in enumerate(lines):
        line = line.strip()
        
        # Skip comments and empty lines
        if not line or line.startswith('#'):
            continue
        
        # Netscape format: domain, flag, path, secure, expiration, name, value
        parts = line.split('\t')
        
        if len(parts) < 7:
            errors.append(f"Line {i+1}: Invalid format (expected 7 tab-separated fields, got {len(parts)})")
            continue
        
        domain, flag, path, secure, expiration, name, value = parts[:7]
        
        # Validate essential fields
        if not domain:
            errors.append(f"Line {i+1}: Missing domain")
            continue
        
        if not name:
            errors.append(f"Line {i+1}: Missing cookie name")
            continue
        
        valid_cookies.append({
            "name": name,
            "domain": domain,
            "path": path,
            "secure": secure == "TRUE"
        })
    
    # Check for essential YouTube cookies
    cookie_names = {c["name"] for c in valid_cookies}
    youtube_domains = {c["domain"] for c in valid_cookies if "youtube.com" in c["domain"]}
    
    essential_cookies = ["SID", "HSID", "SSID", "APISID", "SAPISID"]
    missing_essential = [c for c in essential_cookies if c not in cookie_names]
    
    return {
        "valid": len(valid_cookies) > 0 and len(missing_essential) == 0,
        "cookie_count": len(valid_cookies),
        "youtube_domains": list(youtube_domains),
        "has_essential_cookies": len(missing_essential) == 0,
        "missing_essential": missing_essential,
        "errors": errors,
        "warning": "Missing essential YouTube auth cookies" if missing_essential else None
    }

def test_cookies(cookies: str) -> dict:
    """
    Test if cookies work by making a simple authenticated request.
    
    Returns:
        dict with test results
    """
    try:
        from fetchers.yt_dlp_client import ytdlp_client
        
        logger.info("[cookie_validator] Testing cookies with YouTube...")
        
        # Try to fetch user's liked videos playlist (requires auth)
        result = ytdlp_client.extract(
            "https://www.youtube.com/playlist?list=LL",
            flat=True,
            cookies=cookies,
            is_playlist=True
        )
        
        if result and not result.get("error"):
            return {
                "working": True,
                "message": "Cookies are valid and working",
                "test_url": "https://www.youtube.com/playlist?list=LL",
                "entries_found": len(result.get("entries", []))
            }
        else:
            return {
                "working": False,
                "message": "Cookies failed authentication test",
                "error": result.get("message") if result else "No data returned"
            }
            
    except Exception as e:
        logger.error(f"[cookie_validator] Test failed: {e}")
        return {
            "working": False,
            "message": "Exception during cookie test",
            "error": str(e)
        }

def diagnose_cookies(cookies: str) -> dict:
    """
    Complete cookie diagnostics.
    
    Returns:
        dict with all diagnostic info
    """
    logger.info("[cookie_validator] Starting cookie diagnostics...")
    
    # Step 1: Format validation
    format_check = validate_cookie_format(cookies)
    
    # Step 2: Authentication test (only if format is valid)
    auth_check = None
    if format_check["valid"]:
        auth_check = test_cookies(cookies)
    
    # Compile report
    report = {
        "format_validation": format_check,
        "authentication_test": auth_check,
        "overall_status": "PASS" if (format_check["valid"] and auth_check and auth_check["working"]) else "FAIL",
        "recommendations": []
    }
    
    # Add recommendations
    if not format_check["valid"]:
        report["recommendations"].append(
            "Export fresh cookies using a browser extension like 'Get cookies.txt LOCALLY'"
        )
    
    if format_check["missing_essential"]:
        report["recommendations"].append(
            f"Missing essential cookies: {', '.join(format_check['missing_essential'])}. "
            "Make sure you're logged into YouTube when exporting cookies."
        )
    
    if auth_check and not auth_check["working"]:
        report["recommendations"].append(
            "Cookies may be expired. Try logging out and back into YouTube, then export fresh cookies."
        )
    
    logger.info(f"[cookie_validator] Diagnostics complete: {report['overall_status']}")
    return report

# Expose for bridge
def validate_cookies_bridge(cookies: str) -> str:
    """Bridge-compatible cookie validation"""
    import json
    result = diagnose_cookies(cookies)
    return json.dumps(result, indent=2)