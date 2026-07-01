# QA Test Plan: Panggil-In Emergency Response System

Dokumen Rencana Pengujian ini mendokumentasikan strategi pengujian, skenario kasus uji detail, kriteria kelulusan, dan setup lingkungan pengujian untuk Panggil-In.

---

## 1. Pendahuluan & Sasaran Pengujian

Sasaran rencana pengujian ini adalah memastikan keandalan, integritas, dan latensi rendah sistem respon darurat Panggil-In dalam mendeteksi dan merespon laporan pembegalan. Pengujian meliputi unit testing, integration testing, real-time messaging latency, serta penanganan kondisi kegagalan jaringan offline.

---

## 2. Lingkungan Pengujian (Testing Environment)

| Komponen | Lingkungan Dev / Staging | Alat / Driver Pengujian |
| :--- | :--- | :--- |
| **Backend API Gateway** | Node.js v20.11.0, PostgreSQL Container, Mosquitto MQTT broker | `node:test` runner, `ts-node`, Native Fetch client |
| **Citizen Mobile App** | Flutter SDK 3.22.0, Android API Level 34 Emulator, SQLite in-memory (drift) | `flutter test` runner, `TestWidgetsFlutterBinding` |
| **SIGAP Desktop App** | Flutter Windows Desktop Runtime, Windows 11 host environment | `flutter test` runner, Mock `DispatchService` sockets |
| **AI Inference Server** | FastAPI, Python 3.12, Virtual Environment | `pytest`, Mock REST API endpoints |

---

## 3. Skenario Pengujian & Kasus Uji (Test Cases)

### 3.1 Skenario 1: Riding Mode & SOS Countdown (F-01)

| Test ID | Skenario Pengujian | Langkah Pengujian | Hasil yang Diharapkan | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-F01-01** | Riding Mode memblokir sensor guncangan | 1. Aktifkan Riding Mode (`ridingMode = true`).<br>2. Simulasikan guncangan ekstrem (>30 m/s²). | Status SOS tetap `idle`, tidak memicu overlay hitung mundur. | **PASSED** |
| **TC-F01-02** | Hitung mundur SOS auto-cancel | 1. Picu overlay SOS countdown (60 detik).<br>2. Diamkan selama 60 detik tanpa interaksi. | SOS dibatalkan secara otomatis (status kembali ke `idle`). | **PASSED** |

### 3.2 Skenario 2: Deteksi Guncangan Sensor Akselerometer (F-02)

| Test ID | Skenario Pengujian | Langkah Pengujian | Hasil yang Diharapkan | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-F02-01** | Zero-Click SOS terpicu lewat akselerometer | 1. Pastikan app dalam keadaan `idle` dan Riding Mode nonaktif.<br>2. Emulasikan event guncangan akselerometer >30 m/s². | Aplikasi secara otomatis masuk ke status `confirming` dan memulai hitung mundur. | **PASSED** |

### 3.3 Skenario 3: Fake Shutdown & BLE Mesh Offline Relay (F-03)

| Test ID | Skenario Pengujian | Langkah Pengujian | Hasil yang Diharapkan | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-F03-01** | Fake Shutdown memicu SOS instan | 1. Aktifkan Fake Shutdown lewat BLoC event.<br>2. Amati siklus state SOS. | Layar HP menjadi hitam, sistem langsung mengirim request SOS ke backend di latar belakang. | **PASSED** |
| **TC-F03-02** | Estafet Pelacakan offline (BLE Mesh) | 1. Simulasikan korban mengirim suar UUID darurat via BLE.<br>2. Simulasikan warga menangkap suar, membaca GPS sendiri, dan mengirim ke `/api/reports/ble-relay`. | Koordinat korban di database diperbarui; polisi menerima posisi terbaru dengan flag `isBleRelay: true`. | **PASSED** |

### 3.4 Skenario 4: Deteksi CCTV Adaptif & Cooldown 2 Menit (F-07)

| Test ID | Skenario Pengujian | Langkah Pengujian | Hasil yang Diharapkan | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-F07-01** | Eskalasi FPS ke HIGH saat terdeteksi anomali | 1. Kirim pesan alert CCTV ke `panggil-in/cctv/alerts`. | `fps_mode` kamera berubah menjadi `HIGH` di database; polisi menerima event `cctv_fps_changed` (HIGH). | **PASSED** |
| **TC-F07-02** | Cooldown reset kamera ke LOW | 1. Biarkan kamera dalam mode `HIGH` selama 2 menit tanpa alert baru. | Kamera secara otomatis bertransisi kembali ke mode `LOW`; polisi menerima event `cctv_fps_changed` (LOW). | **PASSED** |

### 3.5 Skenario 5: Rate Limiting & Security (F-06 / Non-Fungsional)

| Test ID | Skenario Pengujian | Langkah Pengujian | Hasil yang Diharapkan | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-F06-01** | Pembatasan login brute force | 1. Kirim 5 request login berturut-turut dari IP yang sama (Sukes/Gagal).<br>2. Kirim request ke-6. | Request ke-6 ditolak dengan kode status HTTP 429 Too Many Requests. | **PASSED** |
| **TC-F06-02** | Pembatasan pemicuan SOS banjir | 1. Pengguna mengirim 3 sinyal SOS dalam 1 menit.<br>2. Kirim request ke-4. | Request ke-4 ditolak dengan status HTTP 429. | **PASSED** |

---

## 4. Kriteria Kelulusan (Pass/Fail Criteria)

Sistem dinyatakan lulus sensor dan siap dirilis jika memenuhi kondisi berikut:
1. **Keandalan Fungsional**: 100% kasus uji fungsional utama (Riding Mode, Shock Detection, BLE Mesh, Adaptive CCTV, Rate Limiter) bernilai **PASSED**.
2. **Cakupan Tes Kode (Code Coverage)**: Unit test untuk BLoC klien seluler, desktop, dan rute API backend memiliki cakupan kode minimal **85%**.
3. **Latensi Real-time**: Pengiriman koordinat GPS via WebSocket / MQTT memiliki waktu pengiriman & visualisasi di peta taktis desktop **di bawah 1 detik** (rata-rata < 300ms).
4. **Resiliensi Jaringan Offline**: Sinyal beacon BLE Mesh berhasil direlay oleh perangkat relayer dan memperbarui koordinat korban di dashboard polisi tanpa kegagalan transfer data.
