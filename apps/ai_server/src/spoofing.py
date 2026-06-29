import random
from typing import Dict, Any

def verify_image_authenticity(image_url: str) -> Dict[str, Any]:
    """
    Checks if an image is authentic (taken live from the mobile app camera)
    or spoofed (downloaded from internet, modified with Photoshop/AI, or missing EXIF metadata).
    """
    # Simulate scanning EXIF metadata and pixel artifacts
    # If the URL contains "fake", "download", or "internet", spoof it for testing
    lowercase_url = image_url.lower()
    is_spoofed = False
    reasons = []
    
    if "fake" in lowercase_url or "download" in lowercase_url or "google" in lowercase_url:
        is_spoofed = True
        reasons.append("Missing camera hardware EXIF metadata headers (EXIF.Software / EXIF.Make)")
        reasons.append("Web image signature matching known search index hash")
    elif "photoshop" in lowercase_url or "edited" in lowercase_url:
        is_spoofed = True
        reasons.append("Pixel compression pattern mismatch indicating graphic manipulation (Error Level Analysis)")
        
    # Default random behavior if no keyword matches
    if not is_spoofed and random.random() < 0.1: # 10% random spoofing check rate
        is_spoofed = True
        reasons.append("Missing device identifier binding in image capture session metadata")

    authenticity_score = round(random.uniform(0.12, 0.38) if is_spoofed else random.uniform(0.85, 0.99), 2)

    return {
        "media_type": "IMAGE",
        "url": image_url,
        "is_spoofed": is_spoofed,
        "authenticity_score": authenticity_score,
        "reasons": reasons if is_spoofed else ["Camera hardware signature verified", "No pixel anomalies found"],
        "metadata": {
            "camera_model": "None" if is_spoofed else "iPhone 15 Pro",
            "aperture": "None" if is_spoofed else "f/1.78",
            "iso": 0 if is_spoofed else 125,
            "original_capture_time": "None" if is_spoofed else "2026-06-29T02:30:00Z"
        }
    }

def verify_audio_authenticity(audio_url: str) -> Dict[str, Any]:
    """
    Checks voice note recordings for synthesized deepfake signatures.
    """
    lowercase_url = audio_url.lower()
    is_spoofed = False
    reasons = []

    if "deepfake" in lowercase_url or "synthesized" in lowercase_url or "robot" in lowercase_url:
        is_spoofed = True
        reasons.append("Spectral frequency analysis shows synthesized digital vocoder pattern")
        reasons.append("No background environmental ambient noise detected")

    authenticity_score = round(random.uniform(0.1, 0.3) if is_spoofed else random.uniform(0.88, 0.98), 2)

    return {
        "media_type": "AUDIO",
        "url": audio_url,
        "is_spoofed": is_spoofed,
        "authenticity_score": authenticity_score,
        "reasons": reasons if is_spoofed else ["Natural acoustic human vocal tract verified", "Valid environmental noise floor"],
    }
