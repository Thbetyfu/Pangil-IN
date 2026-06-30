"""
Unit tests untuk modul detection_real.py — RealYoloDetector & CentroidTracker.

Alasan Arsitektural (Why):
Pengujian didesain untuk berjalan tanpa file model ONNX (yolov8n.onnx) yang bersifat binary besar.
Strategi: inisialisasi detector dengan path palsu agar session=None (mode simulasi),
sehingga kita dapat memvalidasi logika fallback, pre/postprocessing, dan Centroid Tracker
tanpa bergantung pada aset GPU/ONNX yang tidak tersedia di CI pipeline.
"""

import sys
import os
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.detection_real import RealYoloDetector, CentroidTracker


# ────────────────────────────────────────────────
# TEST: RealYoloDetector — fallback mode
# ────────────────────────────────────────────────

def test_detector_initializes_without_model():
    """Detector harus dapat diinisialisasi dengan path model yang tidak ada tanpa crash."""
    detector = RealYoloDetector(model_path="path/yang/tidak/ada.onnx")
    assert detector.session is None, "Session harus None jika model tidak ditemukan"


def test_detector_fallback_returns_list():
    """detect() harus mengembalikan list meskipun model tidak ada (mode simulasi)."""
    detector = RealYoloDetector(model_path="tidak_ada.onnx")
    dummy_frame = np.zeros((480, 640, 3), dtype=np.uint8)
    results = detector.detect(dummy_frame)
    assert isinstance(results, list), "Hasil deteksi harus berupa list"


def test_detector_fallback_returns_non_empty():
    """Fallback simulation harus mengembalikan setidaknya 1 deteksi (person/motorcycle)."""
    detector = RealYoloDetector(model_path="tidak_ada.onnx")
    dummy_frame = np.zeros((480, 640, 3), dtype=np.uint8)
    results = detector.detect(dummy_frame)
    assert len(results) > 0, "Fallback harus mengembalikan minimal 1 deteksi"


def test_detector_fallback_detection_structure():
    """Setiap item deteksi harus memiliki key 'class', 'confidence', dan 'bbox'."""
    detector = RealYoloDetector(model_path="tidak_ada.onnx")
    dummy_frame = np.zeros((480, 640, 3), dtype=np.uint8)
    results = detector.detect(dummy_frame)
    for item in results:
        assert "class" in item, "Harus ada field 'class'"
        assert "confidence" in item, "Harus ada field 'confidence'"
        assert "bbox" in item, "Harus ada field 'bbox'"


def test_detector_fallback_confidence_range():
    """Confidence score harus berada di antara 0.0 dan 1.0."""
    detector = RealYoloDetector(model_path="tidak_ada.onnx")
    dummy_frame = np.zeros((480, 640, 3), dtype=np.uint8)
    results = detector.detect(dummy_frame)
    for item in results:
        assert 0.0 <= item["confidence"] <= 1.0, (
            f"Confidence {item['confidence']} di luar range [0.0, 1.0]"
        )


def test_detector_fallback_bbox_has_four_values():
    """Bounding box harus berupa list dengan tepat 4 nilai [x, y, w, h]."""
    detector = RealYoloDetector(model_path="tidak_ada.onnx")
    dummy_frame = np.zeros((480, 640, 3), dtype=np.uint8)
    results = detector.detect(dummy_frame)
    for item in results:
        assert len(item["bbox"]) == 4, f"Bounding box harus 4 nilai: {item['bbox']}"


def test_detector_labels_include_threat_classes():
    """Label detector harus mencakup kelas ancaman kritis (machete, knife, pistol)."""
    detector = RealYoloDetector(model_path="tidak_ada.onnx")
    threat_classes = {"machete", "knife", "pistol"}
    assert threat_classes.issubset(set(detector.labels)), (
        f"Label tidak mencakup semua kelas ancaman: {detector.labels}"
    )


def test_preprocess_output_shape():
    """Preprocess harus menghasilkan tensor dengan shape (1, 3, 640, 640)."""
    detector = RealYoloDetector(model_path="tidak_ada.onnx")
    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    blob, rx, ry = detector.preprocess(frame, target_size=640)
    assert blob.shape == (1, 3, 640, 640), f"Shape tidak sesuai: {blob.shape}"


def test_preprocess_normalized_to_zero_one():
    """Nilai piksel setelah preprocessing harus dinormalisasi ke rentang [0.0, 1.0]."""
    detector = RealYoloDetector(model_path="tidak_ada.onnx")
    # Buat frame dengan piksel nilai 255 (putih penuh)
    frame = np.full((100, 100, 3), 255, dtype=np.uint8)
    blob, _, _ = detector.preprocess(frame, target_size=64)
    assert blob.max() <= 1.0, f"Nilai maksimal setelah normalisasi: {blob.max()}"
    assert blob.min() >= 0.0, f"Nilai minimum setelah normalisasi: {blob.min()}"


def test_preprocess_scale_factors_returned():
    """Fungsi preprocess harus mengembalikan dua faktor skala (rx, ry)."""
    detector = RealYoloDetector(model_path="tidak_ada.onnx")
    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    _, rx, ry = detector.preprocess(frame, target_size=640)
    assert isinstance(rx, float), "Faktor skala rx harus berupa float"
    assert isinstance(ry, float), "Faktor skala ry harus berupa float"


# ────────────────────────────────────────────────
# TEST: CentroidTracker
# ────────────────────────────────────────────────

def test_centroid_tracker_registers_new_objects():
    """Tracker harus mendaftarkan objek baru saat menerima bounding box pertama kali."""
    tracker = CentroidTracker(max_disappeared=5)
    rects = [[100, 100, 50, 80], [200, 150, 60, 90]]
    objects = tracker.update(rects)
    assert len(objects) == 2, f"Harus ada 2 objek terdaftar, ditemukan: {len(objects)}"


def test_centroid_tracker_no_input_increments_disappeared():
    """Jika tidak ada bounding box baru, counter 'disappeared' harus bertambah."""
    tracker = CentroidTracker(max_disappeared=5)
    tracker.update([[100, 100, 50, 80]])  # Daftarkan 1 objek
    tracker.update([])                   # Tidak ada deteksi baru
    assert tracker.disappeared[0] == 1, "Counter disappeared harus bernilai 1"


def test_centroid_tracker_deregisters_after_max_disappeared():
    """Objek harus dihapus dari tracker setelah melampaui batas max_disappeared."""
    tracker = CentroidTracker(max_disappeared=2)
    tracker.update([[100, 100, 50, 80]])  # Register objek ID 0
    tracker.update([])                    # Disappeared = 1
    tracker.update([])                    # Disappeared = 2
    tracker.update([])                    # Disappeared = 3 → deregister
    assert 0 not in tracker.objects, "Objek harus dihapus setelah melewati max_disappeared"


def test_centroid_tracker_returns_dict():
    """update() harus mengembalikan dictionary dengan key berupa integer ID objek."""
    tracker = CentroidTracker()
    result = tracker.update([[50, 50, 30, 60]])
    assert isinstance(result, dict), "Hasil tracker harus berupa dict"
    for k in result.keys():
        assert isinstance(k, int), f"Key tracker harus integer, bukan: {type(k)}"


def test_centroid_tracker_centroid_calculation():
    """Centroid harus dihitung sebagai titik tengah dari bounding box [x, y, w, h]."""
    tracker = CentroidTracker()
    # bbox [x=100, y=100, w=50, h=80] → centroid (125, 140)
    tracker.update([[100, 100, 50, 80]])
    centroid = tracker.objects[0]
    assert centroid == (125, 140), f"Centroid salah: {centroid}"


if __name__ == "__main__":
    tests = [
        test_detector_initializes_without_model,
        test_detector_fallback_returns_list,
        test_detector_fallback_returns_non_empty,
        test_detector_fallback_detection_structure,
        test_detector_fallback_confidence_range,
        test_detector_fallback_bbox_has_four_values,
        test_detector_labels_include_threat_classes,
        test_preprocess_output_shape,
        test_preprocess_normalized_to_zero_one,
        test_preprocess_scale_factors_returned,
        test_centroid_tracker_registers_new_objects,
        test_centroid_tracker_no_input_increments_disappeared,
        test_centroid_tracker_deregisters_after_max_disappeared,
        test_centroid_tracker_returns_dict,
        test_centroid_tracker_centroid_calculation,
    ]
    passed = 0
    for t in tests:
        try:
            t()
            print(f"  PASS: {t.__name__}")
            passed += 1
        except AssertionError as e:
            print(f"  FAIL: {t.__name__} -> {e}")
    print(f"\n{passed}/{len(tests)} tests passed.")
