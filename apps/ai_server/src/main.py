import os
import requests
import time
import cv2
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, List

from src.graph import street_graph
from src.detection import simulate_yolo_detection, simulate_deepsort_tracking, simulate_vehicle_reid
from src.detection_real import RealYoloDetector, CentroidTracker
from src.spoofing import verify_image_authenticity, verify_audio_authenticity

app = FastAPI(title="Panggil-In AI Inference Server")

# Initialize global detector and tracker
detector = RealYoloDetector(model_path="models/yolov8n.onnx")
tracker = CentroidTracker()

class DetectRequest(BaseModel):
    cctv_id: str
    cctv_name: str

class SpoofRequest(BaseModel):
    media_url: str
    media_type: str # "IMAGE" or "AUDIO"

class EscapeRequest(BaseModel):
    start_node: str
    heading_node: str
    max_minutes: Optional[float] = 5.0

class TriggerAlertRequest(BaseModel):
    cctv_id: str
    confidence: Optional[float] = 0.85
    snapshot_url: Optional[str] = "https://storage.panggil.in/cctv_snapshots/alert_1.jpg"
    suspect_feature_vector: Optional[str] = "helm_merah_jaket_hitam_honda_beat"

@app.get("/health")
def health():
    return {"status": "healthy", "service": "ai_inference_server"}

@app.post("/cctv/detect")
def cctv_detect(req: DetectRequest):
    # Try to load frame from local video if it exists
    video_path = os.path.join(os.path.dirname(__file__), "../../backend/public/cctv_begal.mp4")
    if os.path.exists(video_path):
        try:
            cap = cv2.VideoCapture(video_path)
            if cap.isOpened():
                frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
                if frame_count > 0:
                    # Dynamically roll frame index based on current time
                    # Multiplier changes the speed of the animation simulation
                    frame_idx = int(time.time() * 8) % frame_count
                    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
                    ret, frame = cap.read()
                    if ret and frame is not None:
                        detections = detector.detect(frame)
                        
                        # Update Centroid Tracker with bounding boxes of persons/motorcycles
                        rects = [d["bbox"] for d in detections if d["class"] in ["person", "motorcycle"]]
                        tracker.update(rects)
                        
                        # Determine if weapon or combat is found
                        anomaly_detections = [d for d in detections if d["class"] in ["machete", "knife", "pistol", "aggressive_combat"]]
                        anomaly_detected = len(anomaly_detections) > 0
                        max_confidence = max([d["confidence"] for d in anomaly_detections]) if anomaly_detections else 0.0
                        
                        cap.release()
                        return {
                            "cctv_id": req.cctv_id,
                            "cctv_name": req.cctv_name,
                            "detections": detections,
                            "anomaly_detected": anomaly_detected,
                            "anomaly_confidence": max_confidence,
                            "fps_mode_recommendation": "HIGH" if anomaly_detected else "LOW",
                            "source": "opencv_onnx_frame"
                        }
            cap.release()
        except Exception as e:
            print(f"Error opening video frame, running fallback simulation: {e}")

    # Fallback to simulation
    return simulate_yolo_detection(req.cctv_id, req.cctv_name)

@app.post("/ai/anti-spoofing")
def anti_spoofing(req: SpoofRequest):
    if req.media_type.upper() == "IMAGE":
        return verify_image_authenticity(req.media_url)
    elif req.media_type.upper() == "AUDIO":
        return verify_audio_authenticity(req.media_url)
    else:
        raise HTTPException(status_code=400, detail="Invalid media_type. Must be IMAGE or AUDIO.")

@app.post("/ai/escape-prediction")
def escape_prediction(req: EscapeRequest):
    routes = street_graph.predict_escape_routes(req.start_node, req.heading_node, req.max_minutes)
    if not routes:
        raise HTTPException(status_code=404, detail="No escape route found between these nodes in heading direction.")
    return {
        "start_node": req.start_node,
        "heading_node": req.heading_node,
        "max_minutes": req.max_minutes,
        "predicted_routes": routes
    }

class ReidRequest(BaseModel):
    start_node: str
    suspect_features: str

@app.post("/ai/reid-tracking")
def reid_tracking(req: ReidRequest):
    result = street_graph.simulate_gnn_reid(req.start_node, req.suspect_features)
    if "status" in result and result["status"] == "error":
        raise HTTPException(status_code=404, detail=result["message"])
    return result

@app.post("/cctv/test-trigger-alert")
def test_trigger_alert(req: TriggerAlertRequest):
    # This endpoint simulates the AI Server identifying an anomaly and sending a request
    # to the Node.js backend's mock MQTT client.
    backend_url = os.environ.get("BACKEND_URL", "http://localhost:3001")
    topic = "panggil-in/cctv/alerts"
    payload = {
        "cctvId": req.cctv_id,
        "confidence": req.confidence,
        "snapshotUrl": req.snapshot_url,
        "videoClipUrl": "https://storage.panggil.in/cctv_clips/alert_clip_1.mp4",
        "suspectFeatureVector": req.suspect_feature_vector
    }
    
    try:
        response = requests.post(f"{backend_url}/api/reports/test/mock-mqtt", json={
            "topic": topic,
            "payload": payload
        })
        return {
            "status": "success",
            "message": "CCTV alert simulation triggered successfully",
            "backend_response": response.json()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to communicate with backend: {str(e)}")
