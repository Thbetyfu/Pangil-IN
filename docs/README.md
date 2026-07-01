# Dokumentasi Proyek Panggil-In

Folder ini berisi seluruh dokumentasi resmi proyek **Panggil-In — Sistem Deteksi & Penanganan Begal Cerdas**.

---

## Daftar Dokumen

| File | Deskripsi | Prioritas Baca |
| :--- | :--- | :---: |
| [PRD_Panggil_In.md](./PRD_Panggil_In.md) | **Product Requirement Document** — Spesifikasi lengkap fitur, alur pengguna, skema data, dan aturan bisnis. Dokumen utama referensi pengembangan. | 1 |
| [BRD_Panggil_In.md](./BRD_Panggil_In.md) | **Business Requirement Document** — Strategi bisnis tiga fase (Bandung → Bandung+Jakarta → Nasional), rincian anggaran per fase, dan roadmap aksi keuangan. | 2 |
| [FRD_Panggil_In.md](./FRD_Panggil_In.md) | **Functional Requirement Document** — Detail teknis dan fungsional fitur per modul (Mobile App, Desktop App, Backend, AI Server). | 3 |
| [ROADMAP.md](./ROADMAP.md) | **Roadmap Pengembangan** — Sprint plan, milestone, dan prioritas pengerjaan fitur per iterasi. | 4 |
| [QA_Test_Plan.md](./QA_Test_Plan.md) | **QA Test Plan** — Strategi pengujian, test case E2E, dan skenario acceptance testing. | 5 |
| [DEVMode.md](./DEVMode.md) | **Developer Mode Guide** — Panduan menjalankan proyek secara lokal (backend, mobile, AI server, desktop). | 6 |
| [Perbaikan dekstop.md](./Perbaikan%20dekstop.md) | **Catatan Perbaikan Desktop App** — Log bug dan perbaikan spesifik untuk aplikasi Desktop SIGAP. | 7 |

---

## Struktur Project Utama

```
Panggil-In/
├── docs/                    <- Anda sedang di sini (semua dokumentasi)
├── apps/
│   ├── backend/             <- Node.js + Express + TypeScript + Prisma
│   ├── mobile_app/          <- Flutter Mobile (Android/iOS) — Citizen App
│   ├── desktop_app/         <- Flutter Desktop (Windows) — SIGAP Police App
│   └── ai_server/           <- Python FastAPI — AI Inference Server
├── infra/                   <- Konfigurasi infrastruktur (Nginx, dll)
├── docker-compose.yml       <- Dev environment
└── docker-compose.prod.yml  <- Production environment
```

---

*Dokumen ini diperbarui terakhir: 2026-07-01*
