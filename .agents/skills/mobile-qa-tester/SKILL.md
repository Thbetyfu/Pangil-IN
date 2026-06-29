---
name: mobile-qa-tester
description: >-
  Membantu pengujian ujung-ke-ujung (E2E) dan unit testing pada aplikasi seluler Panggil-In menggunakan Flutter test.
---

# Mobile QA Tester Skill

## Overview
Skill ini dirancang untuk memandu agen dalam menjalankan pengujian terotomatisasi (unit testing & widget testing) pada aplikasi seluler Panggil-In. Memastikan integritas BLoC (SosBloc), cache database lokal (Drift), dan visual overlay (Fake Shutdown & Active SOS).

## Dependencies
- **Flutter SDK**: Wajib terpasang pada sistem operasi host.
- **Drift/Build Runner**: Untuk regenerasi kode SQLite cache.

## Quick Start
Jalankan perintah pengujian langsung dari direktori root proyek mobile:
```bash
cd apps/mobile_app
flutter test
```

## Workflow

### 1. Persiapan Lingkungan Uji
- Pastikan folder dependency `.dart_tool` telah terbuat dengan menjalankan `flutter pub get`.
- Jika ada perubahan pada tabel skema SQLite, jalankan generator build runner terlebih dahulu:
  ```bash
  flutter pub run build_runner build --delete-conflicting-outputs
  ```

### 2. Eksekusi Pengujian Utama
Jalankan perintah berikut untuk menguji seluruh aspek:
```bash
flutter test
```

### 3. Asersi Kasus Uji Penting
Pastikan kasus-kasus uji kritis berikut selalu bernilai PASS:
- **`ToggleFakeShutdownEvent(enable: false) disables fakeShutdown and cancels active SOS`**: Memastikan layar tidak terkunci secara permanen dan status darurat dibersihkan sepenuhnya ke status idle.
- **`Riding Mode`**: Memastikan sensor akselerometer tidak terpicu ketika berkendara.
- **`High-G Shock Trigger`**: Memverifikasi pemicuan SOS otomatis ketika terjadi guncangan hebat.

## Common Mistakes
1. **SQLite Pool Lock**: Menjalankan pengujian paralel yang memodifikasi berkas database fisik yang sama dapat menyebabkan konflik. Gunakan berkas basis data temporer yang unik untuk setiap pengujian.
2. **Missing Code Generation**: Jika ada perubahan file `.g.dart` yang belum di-generate, tes akan gagal pada compile-time. Selalu jalankan `build_runner` setelah menyunting skema database.
