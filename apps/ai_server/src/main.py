import os
import requests
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, List

from src.graph import street_graph
from src.detection import simulate_yolo_detection, simulate_deepsort_tracking, simulate_vehicle_reid
from src.spoofing import verify_image_authenticity, verify_audio_authenticity

app = FastAPI(title="Panggil-In AI Inference Server")

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
