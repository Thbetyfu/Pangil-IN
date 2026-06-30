"""
Unit tests untuk modul graph.py — Prediksi Rute Pelarian & Re-ID GNN Tersangka.

Alasan Arsitektural (Why):
Pengujian unit ini memvalidasi dua fungsi kritis tanpa memerlukan server FastAPI aktif:
1. predict_escape_routes — memastikan algoritma DFS menghasilkan rute valid dalam batas waktu.
2. simulate_gnn_reid    — memastikan message passing memberikan skor tertinggi ke node awal
   dan mendistribusikan kepercayaan dengan benar ke tetangga layer 1 dan layer 2.
"""

import sys
import os

# Tambahkan path root agar import from src.graph dapat ditemukan
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.graph import StreetGraph


def make_graph() -> StreetGraph:
    """Membuat instance StreetGraph baru untuk setiap pengujian (isolated state)."""
    return StreetGraph()


# ────────────────────────────────────────────────
# TEST: predict_escape_routes
# ────────────────────────────────────────────────

def test_escape_route_valid_nodes_returns_routes():
    """Rute pelarian harus ditemukan antara dua node yang valid dan terhubung."""
    g = make_graph()
    routes = g.predict_escape_routes("simpang_dago", "dago_bawah", max_minutes=5.0)
    assert len(routes) > 0, "Harus ada setidaknya satu rute pelarian yang ditemukan"


def test_escape_route_starts_with_correct_path():
    """Rute pertama harus selalu dimulai dari start_node dan melewati heading_node."""
    g = make_graph()
    routes = g.predict_escape_routes("simpang_dago", "dago_bawah", max_minutes=5.0)
    first_path = routes[0]["path"]
    assert first_path[0] == "simpang_dago"
    assert first_path[1] == "dago_bawah"


def test_escape_route_sorted_by_time_ascending():
    """Rute harus diurutkan berdasarkan total_time_minutes dari terkecil ke terbesar."""
    g = make_graph()
    routes = g.predict_escape_routes("simpang_dago", "dago_bawah", max_minutes=8.0)
    times = [r["total_time_minutes"] for r in routes]
    assert times == sorted(times), "Rute harus terurut ascending berdasarkan waktu"


def test_escape_route_respects_max_minutes_with_buffer():
    """Tidak ada rute yang melebihi batas waktu + 20% buffer yang diberikan."""
    g = make_graph()
    max_minutes = 5.0
    routes = g.predict_escape_routes("simpang_dago", "dipatiukur", max_minutes=max_minutes)
    for route in routes:
        assert route["total_time_minutes"] <= max_minutes * 1.2, (
            f"Rute {route['path']} melebihi batas waktu: {route['total_time_minutes']} menit"
        )


def test_escape_route_invalid_start_node_returns_empty():
    """Node awal yang tidak ada di graph harus mengembalikan list kosong."""
    g = make_graph()
    routes = g.predict_escape_routes("node_tidak_ada", "dago_bawah", max_minutes=5.0)
    assert routes == [], "Node tidak valid harus mengembalikan list kosong"


def test_escape_route_invalid_heading_node_returns_empty():
    """Heading node yang tidak ada di adjacency list start_node harus mengembalikan kosong."""
    g = make_graph()
    # dago_atas tidak terhubung langsung ke flyover_pasupati
    routes = g.predict_escape_routes("dago_atas", "flyover_pasupati", max_minutes=5.0)
    assert routes == [], "Edge yang tidak ada harus mengembalikan list kosong"


def test_escape_route_no_cycles_in_path():
    """Setiap rute tidak boleh mengunjungi node yang sama lebih dari sekali."""
    g = make_graph()
    routes = g.predict_escape_routes("simpang_dago", "dago_bawah", max_minutes=10.0)
    for route in routes:
        path = route["path"]
        assert len(path) == len(set(path)), f"Rute mengandung cycle: {path}"


def test_escape_route_confidence_score_range():
    """Skor kepercayaan rute harus berada antara 0.1 dan 1.0."""
    g = make_graph()
    routes = g.predict_escape_routes("simpang_dago", "dago_bawah", max_minutes=6.0)
    for route in routes:
        score = route["confidence_score"]
        assert 0.1 <= score <= 1.0, f"Confidence score di luar range: {score}"


# ────────────────────────────────────────────────
# TEST: simulate_gnn_reid
# ────────────────────────────────────────────────

def test_gnn_reid_valid_start_returns_predictions():
    """GNN Re-ID harus mengembalikan prediksi untuk node awal yang valid."""
    g = make_graph()
    result = g.simulate_gnn_reid("simpang_dago", "helm_merah_jaket_hitam")
    assert "reid_predictions" in result
    assert len(result["reid_predictions"]) > 0


def test_gnn_reid_start_node_has_highest_score():
    """Node awal harus memiliki skor Re-ID tertinggi (0.95) karena itu titik insiden."""
    g = make_graph()
    result = g.simulate_gnn_reid("simpang_dago", "helm_merah_jaket_hitam")
    predictions = result["reid_predictions"]
    # Node pertama setelah sorting (descending) harus adalah simpang_dago
    top_node = predictions[0]
    assert top_node["node_id"] == "simpang_dago"
    assert top_node["reid_probability"] == 0.95


def test_gnn_reid_invalid_start_node_returns_error():
    """Node awal yang tidak dikenal harus mengembalikan status error."""
    g = make_graph()
    result = g.simulate_gnn_reid("node_hantu", "fitur_tersangka")
    assert result["status"] == "error"


def test_gnn_reid_predictions_have_coordinates():
    """Setiap prediksi harus menyertakan koordinat latitude dan longitude yang valid."""
    g = make_graph()
    result = g.simulate_gnn_reid("simpang_dago", "jaket_hitam")
    for pred in result["reid_predictions"]:
        assert "latitude" in pred
        assert "longitude" in pred
        assert isinstance(pred["latitude"], float)
        assert isinstance(pred["longitude"], float)


def test_gnn_reid_sorted_by_probability_descending():
    """Prediksi harus diurutkan berdasarkan reid_probability dari tertinggi ke terendah."""
    g = make_graph()
    result = g.simulate_gnn_reid("simpang_dago", "fitur_motor_merah")
    probs = [p["reid_probability"] for p in result["reid_predictions"]]
    assert probs == sorted(probs, reverse=True), "Prediksi harus terurut descending"


def test_gnn_reid_matched_features_propagated():
    """Fitur tersangka yang diberikan harus diteruskan ke seluruh prediksi node."""
    g = make_graph()
    features = "helm_biru_jaket_putih_honda_beat"
    result = g.simulate_gnn_reid("dago_bawah", features)
    for pred in result["reid_predictions"]:
        assert pred["matched_features"] == features


if __name__ == "__main__":
    # Jalankan semua test secara manual untuk debugging
    tests = [
        test_escape_route_valid_nodes_returns_routes,
        test_escape_route_starts_with_correct_path,
        test_escape_route_sorted_by_time_ascending,
        test_escape_route_respects_max_minutes_with_buffer,
        test_escape_route_invalid_start_node_returns_empty,
        test_escape_route_invalid_heading_node_returns_empty,
        test_escape_route_no_cycles_in_path,
        test_escape_route_confidence_score_range,
        test_gnn_reid_valid_start_returns_predictions,
        test_gnn_reid_start_node_has_highest_score,
        test_gnn_reid_invalid_start_node_returns_error,
        test_gnn_reid_predictions_have_coordinates,
        test_gnn_reid_sorted_by_probability_descending,
        test_gnn_reid_matched_features_propagated,
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
