# BUSINESS REQUIREMENT DOCUMENT (BRD) - PANGGIL-IN
**Versi:** v1.0.0
**Tanggal:** 2026-07-01
**Penulis:** Tim Panggil-In

---

## 1. LATAR BELAKANG & TUJUAN BISNIS

Panggil-In adalah platform keamanan publik berbasis komunitas dan AI yang bertujuan menekan angka kriminalitas jalanan (pembegalan) melalui respons darurat instan, pelacakan adaptif, dan peringatan komunitas. Dokumen ini merinci kebutuhan bisnis, strategi operasional, serta alokasi anggaran per fase untuk memastikan kelayakan finansial dengan modal awal yang sangat terbatas.

---

## 2. PERUBAHAN MODEL AUTENTIKASI (KEPUTUSAN BISNIS)

Berdasarkan analisis biaya operasional skala nasional, model autentikasi diubah untuk menghilangkan biaya SMS Gateway bagi pengguna umum:

| Peran | Metode Login | Biaya per Login |
| :--- | :--- | :--- |
| **CITIZEN (Warga)** | Email + Password langsung → Token JWT instan | **Rp 0** |
| **POLICE_OPERATOR** | Email + Password → OTP 2FA via Email/WA → Token JWT | ~Rp 0–350/OTP |
| **SUPERADMIN** | Email + Password → OTP 2FA via Email/WA → Token JWT | ~Rp 0–350/OTP |

**Dampak Penghematan:** Dengan warga tidak melalui OTP, proyeksi penghematan biaya SMS Gateway untuk skala 1 juta pengguna mencapai **Rp 50.000.000–200.000.000 / tahun** dibandingkan model OTP universal.

---

## 3. STRATEGI PELUNCURAN TIGA FASE

### FASE 1 — BANDUNG REGIONAL PILOT
**Cakupan:** Kota Bandung
**Modal:** Rp 500.000
**Timeline:** 0–6 Bulan
**Target:** 500–2.000 pengguna aktif, 5 operator polisi (simulasi)

#### Rincian Alokasi Anggaran Fase 1

| Komponen | Vendor | Biaya | Catatan |
| :--- | :--- | :--- | :--- |
| Google Play Console | Google | **Rp 400.000** | Sekali bayar selamanya |
| Domain (.my.id) | Niagahoster | **Rp 15.000/tahun** | Endpoint API resmi |
| Backend Server | Render.com | **Rp 0** | Free Tier (512MB RAM) |
| Database PostgreSQL | Neon.tech | **Rp 0** | Free Tier (500MB) |
| File Storage (foto/audio) | Cloudflare R2 | **Rp 0** | Free Tier (10GB + 0 egress fee) |
| Push Notification (FCM) | Firebase | **Rp 0** | Gratis selamanya |
| OTP Petugas (Email) | Gmail SMTP | **Rp 0** | Max 500 email/hari |
| MQTT Broker (CCTV) | HiveMQ Cloud | **Rp 0** | Free Tier (10 device) |
| **Dana Cadangan** | — | **Rp 85.000** | Buffer biaya tak terduga |
| **TOTAL** | | **Rp 500.000** | |

#### Sumber Daya Gratis yang Digunakan di Fase 1
- **Render.com**: Server Node.js backend, auto-deploy dari GitHub
- **Neon.tech**: PostgreSQL serverless, kompatibel Prisma ORM
- **Cloudflare R2**: Object storage untuk foto laporan & audio SOS, tidak ada biaya transfer data keluar
- **Firebase FCM**: Push notification community alert tanpa batas kirim
- **Gmail SMTP**: Email OTP untuk petugas, quota 500 email/hari lebih dari cukup

#### Risiko Teknis Fase 1 & Mitigasi
| Risiko | Dampak | Mitigasi |
| :--- | :--- | :--- |
| Render.com sleep setelah 15 menit | API lambat merespons saat tidak ada traffic | Gunakan UptimeRobot (gratis) untuk ping server setiap 5 menit |
| Neon.tech 500MB limit | DB penuh jika laporan sangat banyak | Hapus laporan RESOLVED >30 hari (PRD Section 6) |
| Render.com tidak support WebSocket stabil | Socket.io putus-putus | Gunakan long-polling sebagai fallback di fase ini |

---

### FASE 2 — BANDUNG + JAKARTA EXPANSION
**Cakupan:** Bandung + Jakarta (2 Kota)
**Modal:** Rp 1.000.000
**Timeline:** Bulan 7–12
**Target:** 5.000–20.000 pengguna aktif, 50 operator polisi aktif

#### Rincian Alokasi Anggaran Fase 2

| Komponen | Vendor | Biaya | Alokasi 6 Bulan |
| :--- | :--- | :--- | :--- |
| VPS Server Mandiri (2 vCPU, 2GB RAM) | IDCloudHost / Biznet GIO | Rp 70.000/bulan | **Rp 420.000** |
| WhatsApp Gateway OTP Petugas | Fonnte.com | Rp 50.000/bulan | **Rp 300.000** |
| Cloudflare R2 (jika >10GB) | Cloudflare | Rp 15.000/bulan | **Rp 90.000** |
| Stiker QR Code Kampanye | Percetakan Lokal | Sekali bayar | **Rp 190.000** |
| **TOTAL** | | | **Rp 1.000.000** |

#### Mengapa VPS Mandiri (Bukan Server Gratis Lagi)?
Di Fase 2, traffic sudah tidak memungkinkan menggunakan free tier:
- Render.com free tier **sleep** setelah 15 menit idle — tidak acceptable untuk layanan darurat 24/7
- Neon.tech 500MB habis dalam hitungan minggu untuk 20.000 pengguna
- VPS lokal memberikan latensi **<50ms** (vs >200ms dari server AS)

**Pilihan VPS Rekomendasi:**

| Provider | Spesifikasi | Harga/Bulan |
| :--- | :--- | :--- |
| **IDCloudHost** | 2 vCPU, 2GB RAM, 20GB SSD | Rp 65.000 |
| **Biznet GIO** | 2 vCPU, 2GB RAM, 40GB SSD | Rp 75.000 |
| **Nusanet** | 1 vCPU, 1GB RAM, 20GB SSD | Rp 45.000 |

#### Mengapa WhatsApp Gateway (Bukan SMS Twilio)?
- Twilio SMS ke Indonesia: **$0.05–$0.08/SMS** (~Rp 750–1.200/pesan)
- Fonnte WhatsApp API: **Rp 50.000/bulan flat** untuk unlimited pesan ke semua nomor
- Untuk 50 operator login 2x/hari = 3.000 OTP/bulan → Twilio: **Rp 2.250.000/bulan** vs Fonnte: **Rp 50.000/bulan**
- **Penghematan: Rp 2.200.000/bulan**

#### Rencana Kampanye Publik Fase 2 (Rp 190.000)
- Cetak 100 stiker QR code berisi link download Panggil-In
- Distribusikan ke pangkalan ojol (Gojek/Grab), pos polisi, dan minimarket sekitar kampus (Dago, Dipatiukur, Setiabudi)
- Target: 500 download organik baru tanpa biaya iklan digital

---

### FASE 3 — NASIONAL (ESTIMASI — MODAL MENYESUAIKAN)
**Cakupan:** Seluruh Indonesia (34 Provinsi)
**Modal:** TBD (B2G / Grant)
**Timeline:** Tahun ke-2 dst
**Target:** 2,7 Juta pengguna, 5.000 operator Polri

#### Estimasi Biaya Operasional Bulanan Fase 3

| Komponen | Opsi Hemat (Tanpa GPU CCTV) | Opsi Penuh (Dengan Deteksi AI 1.000 CCTV) |
| :--- | :--- | :--- |
| Server Backend (Kubernetes Cluster) | Rp 12.000.000 | Rp 12.000.000 |
| Database HA PostgreSQL | Rp 10.500.000 | Rp 10.500.000 |
| File Storage (Cloudflare R2) | Rp 300.000 | Rp 300.000 |
| AI Server GPU (1.000 CCTV) | **Rp 0** *(AI di HP)* | **Rp 80.000.000** |
| WhatsApp OTP Operator | Rp 500.000 | Rp 500.000 |
| SMS OTP Cadangan (Zenziva) | Rp 10.000.000 | Rp 10.000.000 |
| Bandwidth & CDN | Rp 2.000.000 | Rp 2.000.000 |
| **TOTAL / Bulan** | **~Rp 35.300.000** | **~Rp 115.300.000** |

#### Strategi Pendanaan Fase 3

1. **B2G — Kontrak Pemerintah / Polri**
   - Ajukan proposal ke **Mabes Polri** (Divisi TI) sebagai sistem Command Center berbasis AI
   - Nilai kontrak: Rp 500 juta – Rp 2 miliar/tahun tergantung cakupan wilayah
   - Referensi: Program Polri PRESISI (Prediktif, Responsibilitas, Transparansi, Berkeadilan)

2. **Google for Startups Cloud Program**
   - Daftarkan startup ke program [goo.gle/startups](https://startup.google.com)
   - Benefit: **$200.000 (~Rp 3,2 Miliar) Google Cloud credit** selama 1-2 tahun
   - Menutup seluruh biaya infrastruktur cloud Fase 3 tanpa modal sendiri

3. **Program Hibah Lokal**
   - **BRIN**: Program Riset Keamanan Nasional (Rp 100–500 juta)
   - **Telkom Indigo**: Inkubasi startup digital Indonesia
   - **Politeknik/Universitas**: Kemitraan riset AI keamanan publik

---

## 4. ROADMAP AKSI KEUANGAN (PENASIHAT KEUANGAN)

### Segera Lakukan (Minggu Ini):
1. **Beli Google Play Console** — Rp 400.000
   - Buka: [play.google.com/console](https://play.google.com/console)
   - Bayar menggunakan kartu debit/kredit atau Google Play gift card
   - Ini adalah satu-satunya pengeluaran wajib untuk bisa rilis ke publik

2. **Daftarkan Domain .my.id** — Rp 15.000
   - Registrasi di Niagahoster atau IDWEBHOST
   - Contoh: `panggilin.my.id` atau `api.panggilin.biz.id`
   - Setup DNS A Record ke IP server Render.com

3. **Setup Akun Render.com & Neon.tech** — Gratis
   - Daftar akun di Render.com, hubungkan ke GitHub repo Panggil-In
   - Daftar akun di Neon.tech, ambil connection string, masukkan ke `.env` backend

### Bulan ke 1–3 (Fase 1 Aktif):
4. Rilis APK ke Google Play Store (Internal Testing → Closed Testing → Open Testing → Production)
5. Rekrut 5 tester dari komunitas ojol Bandung (tanpa bayar — cukup dengan briefing & manfaat keamanan)
6. Monitor error log via Render.com dashboard & Sentry (free tier)

### Bulan ke 4–6 (Persiapan Fase 2):
7. Daftar VPS di IDCloudHost — sewa bulanan, bisa dibayar per bulan tanpa kontrak panjang
8. Daftar akun Fonnte.com untuk WhatsApp Gateway
9. Siapkan materi pitching untuk Polres Bandung dan Polda Jabar

---

## 5. SUMMARY ANGGARAN KUMULATIF

| Fase | Cakupan | Modal | Kumulatif |
| :--- | :--- | :--- | :--- |
| Fase 1 | Bandung | **Rp 500.000** | Rp 500.000 |
| Fase 2 | Bandung + Jakarta | **Rp 1.000.000** | Rp 1.500.000 |
| Fase 3 | Nasional | **TBD (B2G/Grant)** | TBD |

**Total modal dari kantong sendiri: Rp 1.500.000**
**Untuk membangun platform keamanan kota yang layak jual ke Pemerintah.**

---

*Dokumen ini dibuat berdasarkan keputusan bisnis yang sudah disetujui, termasuk perubahan autentikasi (bypass OTP untuk Citizen) yang telah diimplementasikan di codebase dan didokumentasikan di PRD_Panggil_In.md.*
