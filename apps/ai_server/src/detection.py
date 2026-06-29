import random
from typing import Dict, Any, List

def simulate_yolo_detection(cctv_id: str, cctv_name: str) -> Dict[str, Any]:
    """
    Simulates running YOLOv9 object detection on a CCTV frame.
    Returns detected objects, bounding boxes, and anomaly state.
    """
    # 15% chance of finding a weapon / anomaly during general simulation,
    # or it can be triggered manually.
    has_anomaly = random.random() < 0.15
    
    detections = [
        {"class": "person", "confidence": round(random.uniform(0.8, 0.98), 2), "bbox": [100, 150, 50, 120]},
        {"class": "motorcycle", "confidence": round(random.uniform(0.75, 0.95), 2), "bbox": [120, 170, 80, 100]}
    ]
    
    if has_anomaly:
        # Detect sharp weapon (machete/sajam) or aggressive gesture
        anomaly_type = random.choice(["sharp_weapon", "physical_assault"])
        if anomaly_type == "sharp_weapon":
            detections.append({
                "class": "machete",
                "confidence": round(random.uniform(0.76, 0.93), 2),
                "bbox": [115, 155, 30, 40]
            })
        else:
            detections.append({
                "class": "aggressive_combat",
                "confidence": round(random.uniform(0.8, 0.95), 2),
                "bbox": [95, 140, 110, 130]
            })
            
    # Calculate overall max confidence for weapon/anomaly
    anomaly_detections = [d for d in detections if d["class"] in ["machete", "aggressive_combat"]]
    max_confidence = max([d["confidence"] for d in anomaly_detections]) if anomaly_detections else 0.0

    return {
        "cctv_id": cctv_id,
        "cctv_name": cctv_name,
        "detections": detections,
        "anomaly_detected": len(anomaly_detections) > 0,
        "anomaly_confidence": max_confidence,
        "fps_mode_recommendation": "HIGH" if len(anomaly_detections) > 0 else "LOW"
    }

def simulate_deepsort_tracking(cctv_id: str, suspect_id: str) -> List[Dict[str, Any]]:
    """
    Simulates DeepSORT visual frame-by-frame tracking.
    """
    # Return simulated trajectory coordinates
    trajectory = []
    base_x = random.randint(100, 300)
    base_y = random.randint(150, 400)
    for i in range(5):
        trajectory.append({
            "frame": i + 1,
            "suspect_id": suspect_id,
            "bbox": [base_x + (i * 15), base_y + (i * 8), 60, 120],
            "timestamp": i * 0.1
        })
    return trajectory

def simulate_vehicle_reid(feature_vector: str) -> Dict[str, Any]:
    """
    Simulates matching visual features of a vehicle across cameras (Vehicle Re-ID).
    """
    # Extract dummy attributes from features
    colors = ["black", "red", "blue", "white", "grey"]
    brands = ["Honda Beat", "Yamaha Mio", "Suzuki Satria", "Honda Vario"]
    
    # Generate match results
    matched_cctvs = [
        {
            "cctv_id": "cctv-dago-02",
            "cctv_name": "CCTV Simpang Dago 02",
            "confidence": 0.88,
            "timestamp": "2026-06-29T02:30:15Z"
        },
        {
            "cctv_id": "cctv-juanda-01",
            "cctv_name": "CCTV Dago Bawah 01",
            "confidence": 0.74,
            "timestamp": "2026-06-29T02:32:45Z"
        }
    ]
    
    return {
        "identified_vehicle": f"{random.choice(colors)} {random.choice(brands)}",
        "feature_vector_checksum": hash(feature_vector),
        "matches": matched_cctvs
    }
