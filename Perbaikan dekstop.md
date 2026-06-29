# 🖥️ Dokumen Audit & Perbaikan Aplikasi Desktop (SIGAP Police Dashboard)

Dokumen ini mencatat daftar perbaikan yang telah diselesaikan pada aplikasi desktop, kendala yang sedang diatasi, serta daftar komponen yang akan diaudit dan diperbaiki berikutnya demi menjamin stabilitas fungsionalitas dan estetika premium.

---

## 🛠️ Perbaikan yang Telah Diselesaikan (Completed Fixes)

### 1. Perbaikan Kendala Stuck Loading (Layar Hitam)
* **Akar Masalah**: Koneksi HTTP ke API Gateway backend (port 3001) menggantung (*hang/timeout*) karena proses Node.js tertangguhkan oleh QuickEdit Mode pada CMD Windows.
* **Perbaikan**: Menghentikan paksa proses *zombie* dan menjalankan ulang server backend/AI secara stabil di latar belakang. Health check kembali respon instan (<0.1s).

### 2. Akurasi & Animasi YOLOv9 Bounding Box
* **Akar Masalah**: Kotak pembatas AI sebelumnya diam statis (*hardcoded*) di koordinat yang salah, sehingga tidak sinkron dengan objek nyata dalam video.
* **Perbaikan**: Mengintegrasikan `AnimationController` untuk menggerakkan kotak pembatas secara dinamis (*dynamic coordinated tracking*) mengikuti tersangka dan senjata tajam (sajam) secara beriringan.

### 3. Kendala Gambar Dicoret pada CCTV (Video Off)
* **Akar Masalah**: Logika pemutar CCTV hanya mengenali URL berakhiran `.m3u8`. Saat diberi berkas video lokal berformat `.mp4`, aplikasi mencoba memuatnya sebagai gambar (`Image.network`), yang berujung pada kegagalan (*error*).
* **Perbaikan**: Memperluas kondisi deteksi pemutar di `live_cctv_screen.dart` agar berkas `.mp4` dan tautan lokal static `/static/` langsung dioperasikan oleh pemutar video asli (`CctvPlayer`).

### 4. Halusinasi Deteksi Objek pada Layar CCTV
* **Akar Masalah**: Penggunaan video berita stasiun TV memuat banyak tayangan non-CCTV (wajah presenter, studio berita, teks iklan), namun kotak YOLOv9 digambar terus-menerus sehingga tampak tidak akurat (*hallucinating*).
* **Perbaikan**: Mengunduh video rekaman CCTV komplek murni (kasus curanmor riil di Bandung) dan memotongnya menggunakan `ffmpeg` menjadi klip berdurasi 20 detik yang berisi 100% rekaman CCTV murni tanpa gangguan presenter berita.

---

## 📋 Daftar Rencana Audit & Penyempurnaan Desktop

Berikut adalah aspek-aspek yang sedang dan akan difokuskan untuk diaudit guna menghindari *edge-cases* kesalahan:

### A. Komponen Live CCTV Monitor (`live_cctv_screen.dart`)
- [x] **Adaptive Frame-Rate Toggle**: Memastikan perpindahan toggle FPS (Low-FPS saving mode ke High-FPS active detect mode) benar-benar memperbarui visual dan interval pembaruan frame. (Verifikasi: Berhasil memicu UpdateCctvFpsEvent dan sinkron ke database backend).
- [x] **Confidence Slider (AI Threshold)**: Memverifikasi pergeseran slider threshold AI di pojok kanan atas memengaruhi visibilitas kotak bounding box. (Perbaikan: Berhasil diimplementasikan filter dinamis, kotak di bawah persentase ambang batas akan disembunyikan secara real-time).

### B. Komponen Dashboard Taktis (`dashboard_screen.dart`)
- [x] **OpenStreetMap Centering & Zoom**: Memastikan peta memusatkan layar ke lokasi kejadian laporan SOS pertama secara otomatis saat data laporan berhasil diterima, dan kembali ke Dago Bandung jika kosong. (Verifikasi: Berhasil dialokasikan koordinat default jika kosong).
- [x] **Simulasi AI Trigger (Mock Button)**: Menguji tombol "PICU BEGAL SAJAM (MOCK AI)" di pojok kanan bawah agar mengirimkan sinyal pemicu yang tepat ke server AI (port 3002). (Verifikasi: Berhasil memicu callback API mock-mqtt ke backend).
- [x] **Sinkronisasi Statistik Real-time**: Memastikan counter SOS Warga Aktif, Unit Patroli, dan CCTV terhubung dengan BLoC secara responsif tanpa penundaan. (Verifikasi: Nilai stats counter berjalan real-time).

### C. Komponen Daftar Laporan (`reports_list_screen.dart` & `report_detail_screen.dart`)
- [x] **Navigation Flow**: Memastikan transisi dari menekan item laporan SOS di daftar laporan langsung mengarah ke halaman detail laporan secara mulus. (Verifikasi: Event SelectReportEvent berjalan tanpa hambatan).
- [x] **Dispatched Patrol Unit Allocation**: Memastikan operator polisi dapat memilih dan menugaskan unit patroli yang tersedia ke lokasi kejadian, dan status laporan berubah menjadi `ON_PROCESS`. (Verifikasi: Integrasi API assignPatrolUnit berjalan sukses).

---

## ⚡ Rencana Kerja & Automasi Pengujian (QA Plan)

Untuk menguji seluruh flow di atas secara ketat:
1. **Verifikasi Manual**: Menjalankan Hot Restart dan menguji fungsionalitas UI secara interaktif di layar.
2. **Automated Endpoint Assertions**: Menggunakan pengujian berbasis skrip Python untuk memastikan semua mutasi data di database backend PostgreSQL sinkron saat UI ditekan (misal: perubahan status CCTV dan laporan).
