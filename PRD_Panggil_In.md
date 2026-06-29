# PRODUCT REQUIREMENT DOCUMENT (PRD) - Panggil-In

## 1. METADATA & KONTEKS GLOBAL

Dokumen ini mendefinisikan persyaratan fungsional dan non-fungsional untuk proyek **Panggil-In**, sistem cerdas terintegrasi berbasis kecerdasan buatan (AI) untuk deteksi, pelaporan, dan penanganan tindakan pembegalan secara *real-time*.

* **Nama Proyek:** Panggil-In (Sistem Deteksi & Penanganan Begal Cerdas)
* **Versi PRD & Tanggal:** v1.3.0 / 2026-06-29
* **Target Tech Stack (Unified Flutter Monorepo):**
  * **Frontend Mobile (Citizen & Crowd Client):** Flutter Mobile (Dart) untuk Android (min. SDK 26 / Android 8.0) dan iOS (min. iOS 13) dengan State Management **BLoC** (Business Logic Component). Penyimpanan lokal menggunakan **SQLite dengan Drift ORM** untuk mendukung sinkronisasi offline. Terintegrasi dengan sensor ponsel (Accelerometer, Gyroscope) dan modul Bluetooth Low Energy (BLE) untuk beaconing.
  * **Frontend Desktop (Police SIGAP Client):** Flutter Desktop (Dart) untuk sistem operasi desktop (target utama Windows Desktop) dengan State Management **BLoC**. Memanfaatkan pustaka grafis native C++ via Flutter desktop plugin untuk kelancaran rendering *live stream* video.
  * **Backend / API Gateway:** Node.js (Express) dengan TypeScript, Socket.io (WebSockets) untuk sinkronisasi pesan & koordinasi alert umum, dan MQTT Broker (seperti Mosquitto/EMQX) untuk penerimaan *high-frequency streaming* data GPS dari klien seluler.
  * **AI Inference Server:** Python (FastAPI) untuk melayani inferensi model YOLOv9, DeepSORT, EfficientNet-B4, LSTM (Behavior & NLP), dan Graph Neural Networks (GNN).
  * **Database & ORM:** PostgreSQL dengan Prisma ORM untuk relasi data terstruktur, dan Redis untuk caching data pelacakan GPS *in-memory* dan rate-limiting.
  * **Sistem Penyimpanan Media:** Object Storage (seperti MinIO atau AWS S3) untuk berkas foto dan rekaman video alert.
  * **Sistem Komunikasi Cadangan:** SMS Gateway API (untuk mengirim Stealth SMS Ping).
  * **Autentikasi:** JWT (JSON Web Token) dengan enkripsi SHA-256 yang disimpan secara aman di *Secure Storage* perangkat (klien Mobile) dan penyimpanan terenkripsi lokal (klien Desktop), diamankan dengan autentikasi dua faktor (2FA) OTP via Email/SMS khusus untuk petugas.
* **Arsitektur & Standar Kode:** Clean Architecture, SOLID Principles, ESLint Strict Mode untuk Backend, Dart Linter Strict Rules untuk Flutter Mobile/Desktop, Monorepo Project Structure untuk berbagi model data (*shared domain entities*) dan pustaka API client (*shared SDK*) antara Mobile dan Desktop.
* **Peran AI (AI Persona Prompts):**
  * Bertindaklah sebagai Senior Full-Stack Developer, Software Architect, dan QA Engineer berpengalaman. Semua respons, struktur kode, skema database, dan pengujian yang Anda hasilkan nanti harus mematuhi batasan teknologi dan standar yang didefinisikan dalam dokumen ini tanpa pengecualian.

---

## 2. RINGKASAN PRODUK & TARGET PENGGUNA

### 2.1 Masalah & Solusi (Problem & Solution)
* **Problem Statement:** 
  Tingginya angka kriminalitas jalanan (pembegalan) di Kota Bandung diperburuk oleh beberapa hambatan sistemik:
  1. Korban pembegalan mengalami trauma psikologis hebat sesaat setelah insiden sehingga kesulitan melakukan panggilan telepon darurat atau menulis laporan kronologis secara manual.
  2. Waktu respons kepolisian (5-8 menit) dapat berakibat fatal bagi korban di lokasi kejadian jika tidak ada intervensi cepat sebelum petugas tiba.
  3. Sistem pelaporan publik digital sering kali terganggu oleh tingginya laporan palsu (*prank* atau *spam*) yang mengacaukan prioritas petugas lapangan.
  4. Infrastruktur CCTV kota saat ini masih bersifat pasif (hanya merekam kejadian) dan pemrosesan video analitik *real-time* secara penuh untuk ratusan kamera membutuhkan biaya komputasi dan *bandwidth* server yang terlampau besar.
  5. Metode pelacakan pelaku begal yang merebut ponsel korban sering kali terhenti begitu pelaku mematikan koneksi internet ponsel atau mencabut kartu SIM.
* **Product Vision:** 
  Membangun ekosistem keamanan cerdas terintegrasi (Panggil-In) yang menggabungkan:
  1. Aplikasi *mobile* warga yang mendukung pemicuan darurat instan (*Zero-Click*), penyamaran sistem saat ponsel dirampas (*Anti-Thief Fake Shutdown*), taktik pelacakan adaptif (Internet, Stealth SMS, BLE Mesh), serta intervensi berbasis massa sekitar (*Proximity-Based Community Alert*).
  2. Sistem penyaringan laporan palsu menggunakan reputasi akun dan filter kecerdasan buatan (*AI Anti-Spoofing*).
  3. Aplikasi desktop pusat kendali (SIGAP Desktop) untuk kepolisian yang menampilkan analitik prediktif jalur pelarian pelaku berbasis graf (*Graph Escape route*) dan integrasi deteksi CCTV otomatis berteknologi pelacakan estafet (*Multi-Camera Vehicle Re-ID*).
  4. Pemrosesan visual adaptif (*Adaptive Frame-Rate*) pada jaringan CCTV kota untuk menekan konsumsi komputasi server.

### 2.2 Target Pengguna (User Personas)
Aplikasi ini memiliki beberapa peran (*roles*) pengguna dengan hak akses yang terisolasi:

1. **Role: GUEST (Warga Non-Terautentikasi - Mobile App)**
   * **Deskripsi Hak Akses:** Hanya dapat mengakses halaman Onboarding, Login/Register, serta melihat peta pemantauan umum zona rawan pembegalan (*Heatmap*) tanpa detail informasi laporan.
2. **Role: CITIZEN (Warga & Komunitas Mitra - Mobile App)**
   * **Deskripsi Hak Akses:** Dapat menggunakan semua fitur *mobile app* termasuk pengaktifan tombol SOS Begal! (Voice Note), fitur Lapor! (Visual dengan AI Captioning), melihat peta Pantau!, mengelola kontak darurat, menerima peringatan bahaya sekitar (*Community Alert*), serta bertindak sebagai node penerima BLE estafet.
3. **Role: POLICE_OPERATOR (Petugas Dispatch & Operator Command Center - Desktop App)**
   * **Deskripsi Hak Akses:** Memiliki akses ke Aplikasi Desktop SIGAP untuk melihat daftar laporan aktif dari warga, menerima alert deteksi otomatis dari CCTV, melakukan verifikasi/klasifikasi ulang tingkat urgensi, memantau prediksi rute pelarian pelaku, dan merutekan unit patroli terdekat ke lokasi kejadian.
4. **Role: SUPERADMIN (Administrator Sistem - Desktop App)**
   * **Deskripsi Hak Akses:** Memiliki akses penuh ke administrasi sistem aplikasi desktop, termasuk konfigurasi stream CCTV, manajemen data pengguna (Citizen & Police), pemantauan log performa, audit log tindakan, dan pembaruan pengaturan parameter AI.

---

## 3. ARSITEKTUR INFORMASI & STRUKTUR HALAMAN

Berikut adalah hierarki halaman (*Sitemap*) dan batasan aksesnya:

### 3.1 Struktur Aplikasi Mobile (Flutter Mobile - Citizen Client)
* `/onboarding` & `/login` & `/register` &rarr; [Akses: GUEST] (Hanya untuk tamu, diarahkan ke `/home` jika token JWT masih aktif di *secure storage*).
* `/home` &rarr; [Akses: Terproteksi (CITIZEN)] (Tampilan beranda berisi tombol SOS besar interaktif, status keamanan zona sekitar, pengaturan Mode Berkendara, dan daftar laporan langsung radius 2KM).
* `/home/sos-active` &rarr; [Akses: Terproteksi (CITIZEN)] (Halaman *fullscreen* mode darurat dengan indikator visual gelombang perekaman suara maksimum 30 detik).
* `/home/sos-trigger-confirmation` &rarr; [Akses: Terproteksi (CITIZEN)] (Jendela transisi konfirmasi 1 menit pasca pemicuan *Zero-Click* dengan opsi pembatalan geser atas).
* `/lapor` &rarr; [Akses: Terproteksi (CITIZEN)] (Formulir pelaporan berbasis visual untuk unggah foto dengan pemrosesan *Image Captioning* AI otomatis dan deteksi anti-spoofing).
* `/pantau` &rarr; [Akses: GUEST, CITIZEN] (Peta interaktif berbasis OpenStreetMap menampilkan *Heatmap* zona rawan dan marker laporan publik. CITIZEN dapat mengeklik marker untuk melihat ringkasan status laporan).
* `/profil` &rarr; [Akses: Terproteksi (CITIZEN)] (Mengelola profil pengguna, kontak darurat pribadi, reputasi skor pelapor, dan riwayat laporan pribadi).

### 3.2 Struktur Aplikasi Desktop (Flutter Desktop - Police Client)
Aplikasi desktop SIGAP menggunakan struktur navigasi berbasis panel (*Sidebar Navigation*) dengan isolasi hak akses peran:
* `Screen: Login` &rarr; [Akses: Publik/Hanya GUEST] (Halaman masuk bagi operator dan admin).
* `Screen: Dashboard Taktis` &rarr; [Akses: Terproteksi (POLICE_OPERATOR, SUPERADMIN)] (Ringkasan ringkasan taktis berisi total laporan aktif, status darurat mendesak, tingkat penyelesaian, peta taktis sebaran insiden, dan umpan alert CCTV terbaru).
* `Screen: Daftar Laporan` &rarr; [Akses: Terproteksi (POLICE_OPERATOR, SUPERADMIN)] (Tabel daftar laporan masuk dari warga dengan filter berdasarkan kategori, skor reputasi pelapor, status spoofing, tingkat urgensi, dan status penanganan).
* `Screen: Detail Laporan` &rarr; [Akses: Terproteksi (POLICE_OPERATOR, SUPERADMIN)] (Tampilan detail laporan warga yang dipilih: menampilkan transkrip suara SOS, analisis teks NLP, foto bukti, deskripsi AI, lokasi koordinat peta real-time [Stealth Mode jika aktif], dan histori log penanganan).
* `Screen: Live CCTV` &rarr; [Akses: Terproteksi (POLICE_OPERATOR, SUPERADMIN)] (Umpan *live stream* CCTV terintegrasi dengan overlay visual bounding box YOLOv9 untuk deteksi objek begal/senjata tajam, tombol kendali resolusi/FPS, dan overlay visual vehicle Re-ID).
* `Screen: CCTV Alert Center` &rarr; [Akses: Terproteksi (POLICE_OPERATOR, SUPERADMIN)] (Daftar peringatan otomatis yang dipicu oleh deteksi perilaku anomali CCTV dan koordinat sinyal SOS terdekat).
* `Screen: Manajemen Sistem` &rarr; [Akses: Terproteksi Super (Hanya SUPERADMIN)] (Manajemen penambahan kamera CCTV baru, registrasi akun kepolisian, log audit sistem, dan konfigurasi API AI).

---

## 4. SPESIFIKASI FITUR DETAIL (BERDASARKAN PERAN PENGGUNA)

### 4.1 Fitur Sisi Warga & Komunitas (Citizen-Side - Mobile App)

#### Fitur ID: F-01 - Pemicu SOS Kritis (Zero-Click Trigger & Anti-False Trigger)
* **User Story:** Sebagai **CITIZEN**, saya ingin **memicu sinyal SOS secara instan menggunakan tombol fisik, sensor guncangan, atau perintah suara samaran tanpa perlu membuka layar HP**, sehingga **saya tetap dapat mengirimkan laporan bahaya meskipun HP berada di saku celana atau di bawah ancaman langsung pelaku begal.**
* **Aturan Bisnis (Business Rules):**
  1. **Hardware Button Remapping:** Tombol Volume Up + Volume Down ditekan secara bersamaan selama 3 detik, atau tombol Power ditekan 5 kali berturut-turut akan memicu *Stealth Mode*. Menggunakan Android Accessibility Service API / Media Button Receiver.
  2. **High-G Gesture Detection:** Menggunakan Accelerometer & Gyroscope di latar belakang untuk membaca lonjakan G-Force. Diaktifkan dengan guncangan ekstrem ke satu arah.
  3. **Mode Berkendara (Riding Mode):** Jika sensor mendeteksi kecepatan gerak pengguna > 15 km/jam (bersepeda motor) atau mendeteksi pola aktivitas berjalan/berolahraga secara intensif, pemicu guncangan (*High-G Gesture*) otomatis dinonaktifkan untuk mencegah *false trigger* akibat guncangan jalan.
  4. **Stealth Voice Command:** Integrasi pintasan Google Assistant (Android) dan Siri (iOS) dengan frasa rahasia (contoh: "Aduh, Bandung dingin banget ya malam ini") yang secara instan memicu mode SOS di latar belakang tanpa ada tanda-tanda visual di layar.
  5. **Mekanisme Anti-False Trigger (Konfirmasi Geser):** Begitu salah satu dari 3 metode di atas terdeteksi, sistem menampilkan modal konfirmasi pembatalan selama 1 menit. Pengguna wajib menggeser (drag) tombol SOS ke atas untuk mengonfirmasi bahwa kejadian tersebut **VALID**. Jika dalam waktu 1 menit tidak digeser ke atas (tidak ada tindakan konfirmasi manual), sistem otomatis menganggapnya sebagai *false trigger* (batal) dan sinyal SOS **TIDAK** dikirimkan ke polisi.
* **Kriteria Penerimaan (Acceptance Criteria - Gherkin Format):**
  * **Skenario 1: Berhasil Memicu SOS via Tombol Fisik dan Mengonfirmasi Laporan**
    * **Given:** Pengguna terautentikasi (CITIZEN), layar HP mati, dan HP berada di dalam saku celana.
    * **When:** Pengguna menekan tombol Volume Up + Volume Down secara bersamaan selama 3 detik.
    * **Then:** HP bergetar secara haptik halus (sebagai penanda internal), menampilkan antarmuka `/home/sos-trigger-confirmation`, menampilkan hitung mundur konfirmasi 1 menit, dan ketika pengguna menggeser tombol ke atas, mode SOS aktif dikirimkan ke kepolisian.
  * **Skenario 2: Batal Memicu SOS karena Tidak Ada Konfirmasi dalam 1 Menit**
    * **Given:** Pemicuan *High-G Gesture* tidak sengaja aktif akibat HP terjatuh dari meja.
    * **When:** Tampilan konfirmasi `/home/sos-trigger-confirmation` berjalan selama 1 menit tanpa adanya interaksi geser tombol dari pengguna.
    * **Then:** Setelah waktu hitung mundur habis (00:00), sistem otomatis membatalkan sinyal SOS, membersihkan memori *background listener*, menutup halaman konfirmasi, dan tidak mengirim data apa pun ke server.
* **Kebutuhan UI/UX & Komponen Website:**
  * Jendela konfirmasi memiliki tombol *slider* geser vertikal berukuran besar berwarna merah dengan tulisan "Geser ke Atas untuk Konfirmasi Bahaya".
  * Hitung mundur 60 detik ditampilkan dengan angka digital besar yang berdenyut lambat.

---

#### Fitur ID: F-02 - Tombol SOS Cepat (Voice SOS & Proximity Community Alert)
* **User Story:** Sebagai **CITIZEN**, saya ingin **mengirimkan rekaman suara situasi darurat serta otomatis menyebarkan peringatan radius tanpa identitas detail kepada warga dan ojek online sekitar**, sehingga **kehadiran massa terdekat dapat memberikan efek deterrent instan kepada pelaku sebelum polisi tiba di lokasi.**
* **Aturan Bisnis (Business Rules):**
  1. Pengiriman data SOS dari HP korban akan mendaftarkan koordinat GPS ke server API pusat.
  2. Server secara otomatis menghitung pengguna aplikasi Panggil-In dan mitra ojek online terdekat dalam radius geografis 300–500 meter dari lokasi korban.
  3. Server mengirimkan notifikasi *Push Notification* / *Ping* darurat real-time secara anonim (tidak menampilkan nama, nomor HP, atau foto korban guna menjaga privasi dan keselamatan). Notifikasi hanya berisi: "Sinyal Bahaya Terdeteksi di Radius [X] meter dari Posisi Anda. Harap berhati-hati dan lakukan intervensi massal jika memungkinkan."
* **Kriteria Penerimaan (Acceptance Criteria - Gherkin Format):**
  * **Skenario 1: Menyebarkan Community Alert ke Pengguna Terdekat**
    * **Given:** Pengguna A mengirimkan sinyal SOS terkonfirmasi di koordinat Jalan Dago. Pengguna B (mitra ojek online) sedang aktif dan berada di Jalan Dipatiukur (jarak 350 meter dari koordinat Pengguna A).
    * **When:** Sistem memproses pengiriman data koordinat Pengguna A.
    * **Then:** Sistem secara instan mengirimkan ping peringatan bahaya ke HP Pengguna B dengan pesan: "Darurat! Sinyal bahaya aktif berjarak 350m dari posisi Anda. Harap waspada dan merapat bersama kelompok jika aman."
* **Kebutuhan UI/UX & Komponen Website:**
  * Notifikasi peringatan radius di sisi pengguna sekitar memiliki suara peringatan khusus (*custom alarm tone*) yang berbeda dari notifikasi standar Android/iOS.
  * Menampilkan peta kecil statis dengan lingkaran perimeter radius (300-500m) tanpa pin koordinat presisi titik korban untuk melindungi posisi sensitif korban dari penyalahgunaan.

---

#### Fitur ID: F-03 - Proteksi & Pelacakan Pasca-Begal (Anti-Thief Fake Shutdown & Dual-Path Tracking)
* **User Story:** Sebagai **CITIZEN**, saya ingin **ponsel saya menampilkan menu shutdown palsu dan layar mati total ketika pelaku begal mencoba mematikan HP**, sehingga **pelaku mengira HP sudah mati sementara sistem terus mengirimkan pelacakan lokasi secara konstan.**
* **Aturan Bisnis (Business Rules):**
  1. **Anti-Thief Fake Shutdown:** Ketika mode SOS aktif, aplikasi membajak antarmuka sistem penekanan tombol Power. Jika tombol Power ditekan lama, HP memunculkan dialog menu matikan daya khas sistem operasi (Android/iOS). Jika pilihan "Matikan Daya" dipilih, layar HP akan mati total (*black screen*), menonaktifkan semua suara, getaran, dan LED notifikasi. HP tampak mati total padahal mesin tetap bekerja penuh di latar belakang.
  2. **Metode 1 (Pelacakan Internet Terhubung):** Mengaktifkan *Persistent Foreground Service* dengan prioritas tertinggi OS. Koordinat GPS dienkripsi secara lokal menggunakan algoritma AES-256 (kunci enkripsi dinamis per sesi SOS) sebelum dikirimkan ke SIGAP Desktop pusat komando secara *real-time* setiap 2 detik menggunakan protokol komunikasi MQTT dengan tingkat keandalan QoS 1 (At least once).
  3. **Metode 2 - Taktik A (Stealth SMS Ping - Tanpa Paket Data):** Jika *Network State Listener* mendeteksi koneksi internet terputus (dimatikan oleh pelaku), aplikasi otomatis beralih menggunakan jaringan seluler seluler biasa (2G/3G/4G) untuk mengirimkan SMS Latar Belakang (*Stealth SMS*) berisi koordinat GPS terenkripsi ke SMS Gateway pusat komando setiap 30 detik secara senyap tanpa riwayat SMS.
  4. **Metode 2 - Taktik B (BLE Mesh Beaconing - SIM Card Dicabut):** Jika kartu SIM dicabut (sinyal seluler mati total), aplikasi menyalakan pemancar Bluetooth Low Energy (BLE) secara pasif untuk memancarkan sinyal ID darurat terenkripsi (radius pancar 100 meter). Ketika sinyal ini ditangkap oleh HP warga sekitar yang sedang terhubung ke internet, HP warga tersebut otomatis melaporkan koordinat GPS pertemuan tersebut ke server pusat secara anonim (*crowdsourced relay*).
* **Kriteria Penerimaan (Acceptance Criteria - Gherkin Format):**
  * **Skenario 1: Menjalankan Fake Shutdown dan Pelacakan MQTT Real-Time**
    * **Given:** Mode SOS aktif dan HP terhubung ke paket data seluler.
    * **When:** Pelaku begal menekan tombol power lama dan memilih opsi "Matikan Daya".
    * **Then:** Layar HP menggelap total, menonaktifkan getaran dan suara, lalu memulai transmisi data GPS terenkripsi via MQTT dengan QoS 1 setiap 2 detik ke server.
  * **Skenario 2: Beralih ke Taktik BLE Mesh Beaconing saat Koneksi & SIM Mati**
    * **Given:** HP dalam kondisi *Fake Shutdown*, pelaku mencabut kartu SIM sehingga internet & sinyal seluler mati.
    * **When:** HP korban berpapasan (jarak 40 meter) dengan HP milik Warga B yang aplikasinya aktif dan terhubung ke internet.
    * **Then:** Aplikasi di HP korban memancarkan UUID terenkripsi via BLE, HP Warga B menangkap sinyal tersebut, dan mengirimkan koordinat GPS HP Warga B ke server pusat dengan status: "Node Korban [UUID] terdeteksi di koordinat [Lat, Lng] via relay [User B]".
* **Kebutuhan UI/UX & Komponen Website:**
  * Jendela menu matikan daya palsu harus meniru persis tampilan antarmuka bawaan sistem operasi ponsel target (*native system look-alike*).
  * Selama *Stealth Mode* aktif, sentuhan pada layar tidak boleh memicu lampu latar layar menyala (*touch event blocked*).

---

#### Fitur ID: F-04 - Lapor! Visual Cerdas (Visual Report dengan AI Image Captioning & Anti-Spoofing Filter)
* **User Story:** Sebagai **CITIZEN**, saya ingin **mengirimkan laporan visual dengan foto yang divalidasi oleh filter AI anti-spoofing**, sehingga **laporan saya terverifikasi asli dan tidak diklasifikasikan sebagai laporan palsu (fake report) oleh sistem kepolisian.**
* **Aturan Bisnis (Business Rules):**
  1. Foto yang dikirim melalui fitur Lapor! akan diproses melalui modul **AI Anti-Spoofing & Fake Report Filter** di backend.
  2. Modul akan menganalisis integritas gambar: pemeriksaan *metadata* (EXIF data), deteksi duplikasi gambar internet (reverse search / hashing), serta deteksi keaslian piksel gambar untuk memastikan foto diambil langsung dari kamera aplikasi (bukan hasil unduhan internet atau hasil rekayasa AI generatif).
  3. Modul suara SOS juga dianalisis untuk mendeteksi *Deepfake Audio* / suara sintesis AI generatif.
  4. Laporan yang terindikasi palsu/rekayasa otomatis diturunkan status urgensinya menjadi **LOW-PRIORITY VERIFICATION** dan reputasi skor (*Reputation Scoring*) akun pengguna dikurangi 15 poin.
* **Kriteria Penerimaan (Acceptance Criteria - Gherkin Format):**
  * **Skenario 1: Mengirim Gambar Hasil Unduhan Internet**
    * **Given:** Pengguna berada di halaman `/lapor`.
    * **When:** Pengguna mencoba mengunggah berkas gambar berformat JPEG hasil unduhan dari mesin pencari Google.
    * **Then:** Sistem AI backend mendeteksi hilangnya metadata kamera dan kecocokan hash gambar internet, menetapkan status laporan sebagai `is_spoofed: true`, mengalihkan alur verifikasi laporan ke prioritas rendah, dan mengurangi skor reputasi akun pengguna.
* **Kebutuhan UI/UX & Komponen Website:**
  * Tampilan indikator reputasi skor pengguna pada halaman `/profil` berupa persentase nilai (0% - 100%) dengan visualisasi cincin progres berwarna hijau (reputasi baik), kuning (waspada), atau merah (reputasi buruk).

---

#### Fitur ID: F-05 - Pantau! Heatmap & Keamanan Rute (Interactive Heatmap)
* **User Story:** Sebagai **GUEST atau CITIZEN**, saya ingin **melihat peta sebaran lokasi rawan pembegalan dalam bentuk heatmap**, sehingga **saya dapat memantau keamanan jalanan dan merencanakan rute perjalanan yang lebih aman.**
* **Aturan Bisnis (Business Rules):**
  1. Data *heatmap* didasarkan pada akumulasi laporan terverifikasi (kategori begal dan aktivitas mencurigakan) dalam jangka waktu tertentu (default: 30 hari terakhir).
  2. Gradasi warna heatmap: Merah (Sangat Rawan, &ge; 10 insiden), Kuning (Waspada, 3-9 insiden), Hijau (Relatif Aman, 0-2 insiden).
  3. Detail marker laporan yang diklik oleh **CITIZEN** hanya menampilkan deskripsi kejadian, waktu kejadian (tanpa informasi identitas pelapor untuk privasi), dan status laporan.
  4. **GUEST** tidak dapat mengeklik marker individu untuk melihat detail; hanya diperbolehkan melihat warna gradasi *heatmap* secara makro.

---

### 4.2 Fitur Sisi Otoritas & Pusat Komando (Police-Side - Desktop Client)

#### Fitur ID: F-06 - Dashboard SIGAP & Multi-Sensor Fusion (Alert Verification & CCTV Correlation)
* **User Story:** Sebagai **POLICE_OPERATOR**, saya ingin **menerima alert darurat terintegrasi pada aplikasi desktop yang menggabungkan lokasi GPS SOS warga dengan CCTV terdekat secara otomatis**, sehingga **saya dapat melakukan konfirmasi visual kejadian begal secara instan pada umpan kamera terdekat.**
* **Aturan Bisnis (Business Rules):**
  1. Ketika sinyal SOS dari warga terkonfirmasi aktif, sistem *Multi-Sensor Fusion* di backend langsung mencari kamera CCTV terdekat dalam radius 100 meter dari koordinat GPS korban.
  2. Aplikasi SIGAP Desktop secara otomatis memunculkan umpan video langsung (*live feed*) dari kamera CCTV terdekat tersebut pada jendela fokus utama alert.
  3. Jika terbukti terjadi tindak kriminal pada tayangan CCTV tersebut, operator dapat langsung memicu validasi keamanan prioritas tinggi (*Verified Crime Signal*).
* **Kriteria Penerimaan (Acceptance Criteria - Gherkin Format):**
  * **Skenario 1: Pemicuan SOS Mengaktifkan Kamera CCTV Terdekat Secara Otomatis**
    * **Given:** Operator sedang membuka `Screen: Dashboard Taktis` dan sinyal SOS masuk dari Jalan Simpang Dago pada koordinat GPS tertentu.
    * **When:** Server API mendeteksi adanya CCTV Simpang Dago 01 dalam radius 60 meter dari koordinat korban.
    * **Then:** Aplikasi SIGAP Desktop berbunyi sirine alarm, membuka sub-jendela panel *live feed* CCTV Simpang Dago 01 di layar desktop secara instan, dan memetakan koordinat korban bersisian dengan kamera.
* **Kebutuhan UI/UX & Komponen Website:**
  * Jendela pop-up alert terbagi menjadi dua panel seimbang: panel peta koordinat korban di sebelah kiri dan panel *live stream* CCTV terkait di sebelah kanan.

---

#### Fitur ID: F-07 - Deteksi CCTV Adaptif (CCTV AI Detection & Adaptive Frame-Rate Manager)
* **User Story:** Sebagai **SUPERADMIN**, saya ingin **sistem secara adaptif mengatur FPS dan resolusi CCTV kota berdasarkan deteksi anomali**, sehingga **dapat menghemat kapasitas penyimpanan server dan konsumsi jaringan *bandwidth* kota.**
* **Aturan Bisnis (Business Rules):**
  1. Kamera CCTV dalam kondisi pemantauan normal berjalan pada mode hemat komputasi: **Low Frame-Rate (5-10 FPS)** dan resolusi standar (480p), memproses model YOLOv9 untuk deteksi objek awal.
  2. Begitu model YOLOv9 mendeteksi objek mencurigakan (seperti senjata tajam atau kecocokan wajah pelaku begal dengan tingkat kepercayaan &ge; 75%) atau *Behavior Classifier* mendeteksi anomali gerak agresif:
     * Sistem otomatis menaikkan kualitas tangkapan video ke **High Frame-Rate (30 FPS)** dan resolusi maksimum (1080p).
     * Mengaktifkan modul analisis tingkat tinggi: **DeepSORT Tracking** dan **Pose Estimation** secara otomatis.
  3. Jika dalam waktu 2 menit tidak terdeteksi eskalasi anomali lanjutan, sistem mengembalikan kamera ke mode hemat komputasi (Low FPS/resolusi standar).
* **Kriteria Penerimaan (Acceptance Criteria - Gherkin Format):**
  * **Skenario 1: Anomali Terdeteksi dan Meningkatkan Kualitas Video CCTV**
    * **Given:** Kamera CCTV Simpang Dago 01 berada dalam mode *monitoring* hemat komputasi (10 FPS, 480p).
    * **When:** Seseorang mengeluarkan senjata tajam di bawah kamera yang dideteksi oleh YOLOv9.
    * **Then:** Umpan video otomatis beralih menjadi 30 FPS resolusi 1080p pada aplikasi desktop, modul DeepSORT mulai melacak pergerakan orang tersebut dengan bounding box merah, dan operator SIGAP menerima pemicuan alert secara real-time.
* **Kebutuhan UI/UX & Komponen Website:**
  * Indikator status FPS dan resolusi pada umpan CCTV berupa teks status melayang (*overlay status badge*) berwarna hijau: "SAVING MODE - 10 FPS" atau merah: "ACTIVE DETECT MODE - 30 FPS".

---

#### Fitur ID: F-08 - Estafet Tracking & Prediksi Jalur Pelarian (Multi-Camera Vehicle Re-ID & Graph Escape Prediction)
* **User Story:** Sebagai **POLICE_OPERATOR**, saya ingin **sistem melacak pelaku begal secara estafet lintas kamera dan memprediksi persimpangan jalan mana saja yang akan dilalui**, sehingga **petugas lapangan dapat memblokir rute pelarian pelaku secara presisi.**
* **Aturan Bisnis (Business Rules):**
  1. **Multi-Camera Vehicle Re-Identification (Vehicle Re-ID):** Begitu pelaku begal terdeteksi di CCTV pertama, AI mengekstrak karakteristik visual unik (warna jaket, jenis helm, tipe/warna sepeda motor) menjadi sebuah vektor fitur digital. Ketika pelaku melintas di jangkauan CCTV kedua atau ketiga, sistem secara otomatis mencocokkan vektor fitur tersebut untuk melacak perpindahan pelaku.
  2. **Graph-Based Escape Route Prediction:** Peta jaringan jalan Kota Bandung dimodelkan sebagai struktur graf digital (jalan sebagai garis/sisi, persimpangan sebagai titik/node).
  3. Sistem menghitung arah vektor dan kecepatan gerak pelaku, lalu menganalisis kemungkinan persimpangan yang akan dilalui dalam rentang waktu 1, 3, hingga 5 menit ke depan dengan mempertimbangkan faktor satu arah, jalan buntu, dan kondisi kemacetan lalu lintas real-time.
  4. Aplikasi SIGAP Desktop menampilkan prediksi rute ini dalam bentuk garis putus-putus merah pada peta taktis serta memberikan rekomendasi titik blokade polisi.
* **Kriteria Penerimaan (Acceptance Criteria - Gherkin Format):**
  * **Skenario 1: Menampilkan Jalur Prediksi Pelarian Pelaku**
    * **Given:** Pelaku ber-ID 09 teridentifikasi melintas di Jalan Dago menuju arah Selatan pada CCTV Simpang Dago 01.
    * **When:** Operator mengeklik ikon pelaku ID 09 di dashboard desktop.
    * **Then:** Peta taktis SIGAP menggambar garis putus-putus merah yang memproyeksikan rute pelariannya ke Jalan Merdeka atau Jalan Juanda dalam 3 menit ke depan, serta memunculkan rekomendasi pop-up: "Rekomendasi Blokade: Persimpangan Jalan Juanda-Jalan Merdeka (Estimasi tiba: 2 menit)."
* **Kebutuhan UI/UX & Komponen Website:**
  * Garis proyeksi rute pelarian berupa garis putus-putus neon merah dengan panah animasi penunjuk arah pergerakan.
  * Kartu rekomendasi blokade melayang di peta yang dapat diklik untuk mengirimkan instruksi penugasan langsung ke unit patroli terdekat di daerah rute tersebut.

---

## 5. SKEMA DATA & ENTITAS DATABASE (DATA MODEL)

Prisma Schema & Relasi Database didefinisikan menggunakan entitas logis berikut:

### Entitas 1: User
Merepresentasikan seluruh aktor dalam sistem (Citizen, Operator Polisi, Superadmin).

| Field Name | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | String (UUID) | Primary Key, Unique | ID unik entitas pengguna. |
| `email` | String | Unique, Required | Alamat email unik pengguna. |
| `password` | String | Required | Password pengguna yang telah di-hash (Argon2 / bcrypt). |
| `name` | String | Required | Nama lengkap pengguna. |
| `phone` | String | Required, Unique | Nomor telepon untuk verifikasi dan konfirmasi laporan. |
| `role` | Enum | Default: 'CITIZEN' | Peran pengguna: 'CITIZEN', 'POLICE_OPERATOR', 'SUPERADMIN'. |
| `reputation_score` | Float | Default: 100.00 | Skor reputasi pelapor untuk memfilter laporan palsu (0.00 - 100.00). |
| `riding_mode` | Boolean | Default: false | Status apakah pengguna sedang dalam Mode Berkendara. |
| `created_at` | DateTime | Default: now() | Waktu pembuatan akun. |
| `updated_at` | DateTime | UpdatedAt | Waktu terakhir pembaruan data akun. |

### Entitas 2: Report
Merepresentasikan seluruh data laporan pembegalan yang diajukan oleh warga (CITIZEN).

| Field Name | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | String (UUID) | Primary Key, Unique | ID unik berkas laporan. |
| `reporter_id` | String (UUID) | Foreign Key -> User(id) | Relasi ke identitas pembuat laporan. |
| `type` | Enum | Required | Jenis input laporan: 'SOS_VOICE', 'VISUAL_REPORT'. |
| `status` | Enum | Default: 'PENDING' | Status laporan: 'PENDING', 'VALIDATED', 'ON_PROCESS', 'RESOLVED', 'REJECTED'. |
| `urgency` | Enum | Default: 'MEDIUM' | Tingkat keparahan bahaya: 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'. |
| `description` | String (Text) | Nullable | Narasi laporan yang ditulis warga atau dihasilkan otomatis oleh AI. |
| `audio_url` | String | Nullable | Tautan penyimpanan cloud untuk berkas suara SOS (.mp3/.wav). |
| `image_url` | String | Nullable | Tautan penyimpanan cloud untuk berkas gambar kejadian. |
| `latitude` | Float | Required | Koordinat garis lintang (latitude) lokasi kejadian dari GPS. |
| `longitude` | Float | Required | Koordinat garis bujur (longitude) lokasi kejadian dari GPS. |
| `is_spoofed` | Boolean | Default: false | Penanda apakah laporan dideteksi palsu/rekayasa oleh modul AI. |
| `anti_spoofing_score` | Float | Default: 1.00 | Skor integritas keaslian media dari AI (0.00 - 1.00). |
| `assigned_unit_id` | String (UUID) | Nullable, Foreign Key -> PatrolUnit(id) | Relasi ke unit patroli yang ditugaskan ke lokasi. |
| `created_at` | DateTime | Default: now() | Waktu pengiriman laporan. |
| `updated_at` | DateTime | UpdatedAt | Waktu perubahan status atau detail laporan. |

### Entitas 3: CCTVCamera
Merepresentasikan kamera pengawas lalu lintas kota yang terintegrasi ke dalam sistem kecerdasan buatan.

| Field Name | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | String (UUID) | Primary Key, Unique | ID unik kamera pengawas. |
| `name` | String | Required | Nama identitas kamera (misal: "CCTV Simpang Dago 01"). |
| `stream_url` | String | Required | Tautan protokol streaming langsung (RTSP/HLS). |
| `latitude` | Float | Required | Koordinat garis lintang fisik kamera. |
| `longitude` | Float | Required | Koordinat garis bujur fisik kamera. |
| `fps_mode` | Enum | Default: 'LOW' | Mode performa kamera: 'LOW' (10 FPS), 'HIGH' (30 FPS). |
| `status` | Enum | Default: 'ACTIVE' | Status operasional kamera: 'ACTIVE', 'INACTIVE', 'MAINTENANCE'. |
| `created_at` | DateTime | Default: now() | Waktu integrasi sistem kamera. |

### Entitas 4: CCTVAlert
Merepresentasikan peringatan darurat otomatis yang dihasilkan oleh model deteksi anomali pada CCTV.

| Field Name | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | String (UUID) | Primary Key, Unique | ID unik peringatan sistem. |
| `cctv_id` | String (UUID) | Foreign Key -> CCTVCamera(id) | Relasi ke kamera pemicu deteksi. |
| `status` | Enum | Default: 'UNVERIFIED' | Status alert: 'UNVERIFIED', 'VALIDATED_CRIME', 'FALSE_ALARM'. |
| `confidence` | Float | Required | Skor probabilitas akurasi AI terhadap anomali (0.00 - 1.00). |
| `snapshot_url` | String | Required | Tautan gambar potongan bukti deteksi anomali (screenshot). |
| `video_clip_url` | String | Nullable | Tautan klip video berdurasi pendek saat anomali terjadi. |
| `suspect_feature_vector` | String | Nullable | Vektor representasi fitur visual pelaku begal hasil ekstraksi Re-ID. |
| `created_at` | DateTime | Default: now() | Waktu terpicunya peringatan. |

### Entitas 5: PatrolUnit
Merepresentasikan pos kepolisian atau unit mobil/motor patroli lapangan yang bersiaga.

| Field Name | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | String (UUID) | Primary Key, Unique | ID unik unit patroli. |
| `name` | String | Required | Nama regu atau kode unit patroli (misal: "Patroli Sabhara Dago 1A"). |
| `latitude` | Float | Required | Posisi koordinat garis lintang terbaru unit dari GPS. |
| `longitude` | Float | Required | Posisi koordinat garis bujur terbaru unit dari GPS. |
| `status` | Enum | Default: 'AVAILABLE' | Status ketersediaan: 'AVAILABLE', 'ON_DUTY', 'OFFLINE'. |
| `phone` | String | Required | Nomor kontak darurat unit patroli lapangan. |
| `updated_at` | DateTime | UpdatedAt | Waktu pembaruan posisi GPS terakhir. |

---

## 6. BATASAN NON-FUNGSIONAL, KEAMANAN, & VALIDASI

### Keamanan (Security)
* **Validasi Skema Input:** 
  Semua masukan data dari sisi klien wajib divalidasi ganda menggunakan pustaka validasi ketat (seperti **Zod** di sisi frontend desktop/mobile dan **Joi** di sisi API Backend) untuk mencegah anomali tipe data.
* **Proteksi Kerentanan Umum:** 
  Sistem wajib terlindungi dari celah keamanan umum:
  * **XSS (Cross-Site Scripting):** Melakukan pembersihan data (*data sanitization*) ketat pada konten yang dimasukkan pengguna sebelum ditampilkan ke layar.
  * **SQL Injection:** Seluruh kueri database wajib menggunakan ORM Prisma yang memiliki fitur bawaan proteksi *parameterized queries*.
* **Rate Limiting:** 
  Implementasi pembatasan akses (*rate limiting*) menggunakan Redis pada rute API sensitif:
  * Maksimal 5x pencarian atau request token API per menit.
  * Maksimal 3x pemicuan SOS per menit per user.
* **Enkripsi Payload Real-time & QoS MQTT:**
  * Pengiriman koordinat GPS berkala dari HP warga via MQTT dienkripsi secara lokal (*client-side encryption*) menggunakan algoritma **AES-256** dengan kunci dinamis per sesi SOS.
  * MQTT dikonfigurasi menggunakan tingkat keandalan **QoS 1** (*At least once*) untuk menjamin penyampaian koordinat ke pusat komando di area bersinyal minim tanpa memicu beban daya baterai berlebih.
* **Offline Cache & Database Lokal:**
  * Aplikasi *mobile* warga menyimpan data heatmap rawan begal, riwayat laporan, dan daftar kontak darurat secara lokal menggunakan **SQLite dengan Drift ORM**.
  * Sinkronisasi data cache dilakukan di latar belakang saat mendeteksi koneksi Wi-Fi atau internet seluler yang stabil dan tidak mengganggu aktivitas kritis pelacakan.
* **Autentikasi Petugas Kepolisian:**
  * Aplikasi desktop SIGap diamankan menggunakan token **JWT** berdurasi sesi maksimal **12 jam** (untuk meminimalkan penyalahgunaan pada terminal komando yang tidak dijaga).
  * Proses masuk (*login*) petugas diamankan dengan lapisan keamanan kedua berupa **Autentikasi Dua Faktor (2FA) OTP** yang dikirimkan via SMS atau Email terdaftar.
* **Kepatuhan Privasi (UU PDP):** 
  Data pribadi pelapor (nama, nomor telepon, koordinat rumah) wajib disembunyikan dalam representasi data peta publik. Berkas suara SOS wajib dienkripsi saat disimpan di cloud storage dan dihapus otomatis dari server dalam waktu 90 hari setelah status laporan diselesaikan.

### Performa (Performance)
* **Desktop App Performance:** 
  Aplikasi Desktop SIGAP (Windows) harus mampu menampilkan pemetaan dan minimal 4 umpan balik kamera CCTV 30 FPS secara simultan tanpa mengalami kebocoran memori (*memory leak*), dengan *memory footprint* di bawah 500 MB RAM dan penggunaan CPU di bawah 25% pada prosesor kelas Intel Core i5.
* **Latensi Jaringan:** 
  Penerimaan koordinat MQTT di latar belakang harus memiliki waktu transmisi &lt; 200ms, dan *refresh rate* visual posisi pada peta taktis desktop &lt; 1 detik.
* **Skalabilitas Concurrency:** 
  Server backend wajib dikonfigurasi untuk mampu menangani minimal 5.000 koneksi socket *concurrent* secara simultan dalam mendistribusikan alert CCTV real-time.
* **Kebijakan Penyimpanan (Media Retention Policy):**
  * Berkas media berupa foto bukti warga dan potongan rekaman video alert CCTV disimpan pada *Object Storage* (MinIO/S3).
  * Seluruh media dari laporan kasus yang berstatus **Resolved** otomatis dihapus permanen oleh sistem setelah melewati masa **30 hari** untuk menghemat biaya operasional penyimpanan, kecuali kasus yang ditandai secara manual sebagai 'Aktif/Dalam Proses Hukum'.

### Aksesibilitas (Accessibility)
* **Keyboard Navigation & Hotkeys:** 
  Aplikasi desktop wajib menyediakan jalan pintas keyboard (*keyboard hotkeys*) terkonfigurasi untuk mempercepat validasi alert, misalnya `Ctrl + Shift + V` untuk validasi, dan `Ctrl + Shift + F` untuk menandai *false alarm*.
* **Trauma-Responsive Accessibility:** 
  Aplikasi seluler wajib menyediakan kontrol gestur suara alternatif (*voice command activation*) serta opsi tombol *shortcut* getar (*haptic feedback*) saat memicu keadaan darurat SOS bagi pengguna yang tidak dapat melihat layar akibat kondisi panik.
