# Panggil-In - Developer Mode Guide (DEVMode)

Dokumen ini berisi daftar kredensial akun uji coba (seed data) yang telah dimasukkan ke dalam database lokal untuk memudahkan pengujian semua fitur dan peran (role) dalam ekosistem Panggil-In.

---

## Daftar Kredensial Uji Coba (Seeded Accounts)

| No. | Peran (Role) | Nama Pengguna | Alamat Email | Kata Sandi (Password) | Nomor Telepon | Catatan / Target Aplikasi |
|:---|:---|:---|:---|:---|:---|:---|
| 1 | **SUPERADMIN** | Super Admin | `superadmin@panggil.in` | `superadmin123` | `081122334455` | Hak akses penuh sistem (Panel Admin) |
| 2 | **POLICE_OPERATOR** | Aiptu Budi Prasetyo | `operator@panggil.in` | `operator123` | `081234567890` | Akses Dashboard SIGAP Police (Desktop App) |
| 3 | **CITIZEN** | Rian Wijaya | `citizen@panggil.in` | `citizen123` | `089876543210` | Akses Pelaporan Warga (Mobile App) |

---

## Cara Verifikasi Dua Faktor (2FA / OTP)

Untuk pengujian lokal (development environment):
- Dialog 2FA / OTP pada aplikasi **Desktop** bersifat **simulasi (mock)** di frontend.
- Anda **tidak perlu** memeriksa SMS atau email untuk mendapatkan kode OTP.
- Cukup masukkan **6-digit angka bebas apa saja** (misalnya: `123456` atau `000000`) lalu klik **Verifikasi & Masuk** untuk masuk ke sistem.

---

## Mengatur Ulang / Mengisi Data Awal Database (Manual Seeding)

Jika Anda ingin membersihkan database dan mengisi ulang data di atas beserta data CCTV dan Patroli Unit default, Anda dapat menjalankan perintah berikut pada terminal di dalam folder `apps/backend`:

```bash
# Melakukan sinkronisasi skema prisma
npx prisma db push --skip-generate

# Melakukan seeding data akun, cctv, dan unit patroli
npx prisma db seed
```
Atau cukup jalankan launcher [start-all.bat](file:///d:/0.%20Kerjaan/Panggil-in/start-all.bat) yang otomatis memanggil proses di atas pada setiap inisialisasi awal.
