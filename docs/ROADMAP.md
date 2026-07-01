# ROADMAP & SPRINT PLANNING - PANGGIL-IN

Dokumen ini mendefinisikan fase pengembangan, backlog sprint, dan prioritas implementasi untuk ekosistem keamanan cerdas Panggil-In.

## Fase Pengembangan (Phased Roadmap)

### Fase 1: Fondasi Monorepo & Backend API (Sprint 1)
- Inisialisasi struktur folder monorepo.
- Konfigurasi Docker Compose untuk PostgreSQL, Redis, dan MQTT Broker.
- Pembuatan skema database PostgreSQL menggunakan Prisma ORM.
- Implementasi API Gateway (Node.js/Express/TypeScript) untuk Autentikasi dan Manajemen Pengguna.
- Implementasi sistem pelaporan (Report API) dan pengiriman alert real-time via Socket.io/MQTT.

### Fase 2: AI Inference Server & Pelacakan Pintar (Sprint 2)
- Inisialisasi AI Inference Server (FastAPI + Python).
- Integrasi model YOLOv9 untuk deteksi objek (sajam/begal) dan DeepSORT untuk visual tracking.
- Pembuatan detektor anomali visual (Behavior Classifier) dan estimasi pose.
- Implementasi Graph Escape Route Prediction untuk memproyeksikan rute pelarian pelaku.
- Integrasi modul filter AI Anti-Spoofing & Fake Report.

### Fase 3: Aplikasi Mobile Citizen (Sprint 3)
- Inisialisasi Flutter Mobile Project.
- Implementasi BLoC State Management dan Drift ORM (SQLite local cache).
- Pembuatan halaman Onboarding, Login, dan Register.
- Implementasi pemicu SOS (Zero-Click): High-G Gesture, hardware button remapping, dan Stealth Voice Command.
- Integrasi BLE Mesh Beaconing untuk pengiriman lokasi offline/tanpa kartu SIM.
- Integrasi Peta Pantau! berbasis OpenStreetMap (Heatmap & Marker Detail).

### Fase 4: Aplikasi Desktop SIGAP Police (Sprint 4)
- Inisialisasi Flutter Desktop Project (Windows target).
- Implementasi BLoC State Management dan plugin rendering live video C++.
- Pembuatan Dashboard Taktis (Peta real-time, statistik darurat, alert feed).
- Integrasi panel live CCTV dengan bounding box YOLOv9 overlay.
- Visualisasi estafet tracking (Multi-Camera Vehicle Re-ID) dan rekomendasi blokade di peta.

### Fase 5: Integrasi Akhir & QA E2E Testing (Sprint 5)
- Pengujian E2E integrasi seluruh komponen (Mobile, Desktop, Backend, AI).
- Pengujian skenario kegagalan jaringan (offline sync, SMS backup, BLE mesh).
- Audit keamanan, rate limiting, enkripsi AES-256 payload, dan optimasi performa desktop.
- Deployment simulasi lapangan.

---

## Sprint 1 Backlog: Inisialisasi & Backend API Gateway

### Tugas 1: Inisialisasi Monorepo
- Membuat file konseptual dan konfigurasi monorepo root.
- Mengatur docker-compose.yml untuk database PostgreSQL, Redis, dan EMQX/Mosquitto.

### Tugas 2: Database Setup
- Inisialisasi Prisma ORM di folder apps/backend.
- Membuat file schema.prisma berdasarkan model data PRD.
- Menjalankan migrasi awal database.

### Tugas 3: Backend API Gateway Setup
- Membuat boilerplate server menggunakan Express, TypeScript, dan Socket.io.
- Menghubungkan server ke MQTT broker lokal untuk menyerap data koordinat GPS.
- Menerapkan modular routes: Auth, Reports, CCTV, Patrol Units.
- Menambahkan validasi payload request menggunakan Zod.
- Menerapkan error handling terpusat.
