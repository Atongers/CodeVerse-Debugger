# Laporan Alpha Testing — CodeVerse: Debugger (V1.1)

**Tanggal Pengujian:** 15 November 2026  
**Versi Build:** V1.1 (UI Rework & World 1 Syntax Shore)  
**Engine:** Godot `4.7` (2D, Forward Plus)  
**Penguji:** AI QA / Godot Developer (`godot-ai` MCP Runtime & Inspection)

---

## 1. Ringkasan Eksekutif

Pengujian Alpha Build **V1.1** dilakukan untuk memverifikasi stabilitas runtime, fungsionalitas antarmuka pasca-rework (`UiPixelTheme`, `HudTopBar`, modal Main Menu), navigasi serta interaksi di **Level 1–3 (`World 1: Syntax Shore`)**, dan penanganan kesalahan pada **Terminal Python** (`NameError` & sistem Hint).

Dari **11 skenario pengujian (`TC-01` s.d. `TC-11`)**:
- **9 skenario berstatus `PASS`** (termasuk 1 temuan *Major* yang langsung diperbaiki dan diverifikasi ulang).
- **2 skenario berstatus `PASS WITH MINOR` / `PARTIAL`** (ditemukan 2 cacat *Minor/Cosmetic* dan sebagian alur destruktif/progresi penuh belum dieksekusi agar data simpan tidak terubah).
- **0 error runtime / script error** tercatat pada `logs_read(source="game")` di seluruh scene yang dijalankan (`main_menu.tscn`, `level_1.tscn`, `level_2.tscn`, `level_3.tscn`).

**Keputusan Alpha Gate:** **LAYAK LANJUT KE BETA / POLISH MINOR** (seluruh *Blocker* dan *Major* telah terselesaikan; sisa 2 temuan *Minor/Cosmetic* dijadwalkan untuk perbaikan ringan).

---

## 2. Lingkungan & Ruang Lingkup Uji

| Parameter | Detail |
| :--- | :--- |
| **Main Scene** | `res://scenes/ui/menus/main_menu.tscn` |
| **Scene Level Teruji** | `level_1.tscn`, `level_2.tscn`, `level_3.tscn` (`scenes/levels/world_1_syntax_shore/`) |
| **Autoload Aktif** | `SaveManager` (`res://scripts/autoload/save_manager.gd`), `_mcp_game_helper` |
| **Resolusi Viewport** | `1152 x 648` (`canvas_items`, `expand`) |
| **Metode Uji** | `filesystem_manage(op="scan")`, `project_run`, simulasi input (`game_manage`), inspeksi UI tree (`get_ui_elements`), tangkapan layar (`editor_screenshot`), dan audit log (`logs_read`). |

---

## 3. Matriks Test Case

| ID | Modul / Fitur | Prasyarat | Langkah Uji | Hasil yang Diharapkan | Hasil Aktual | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-01** | Build & Parse Health Check | Editor Godot aktif | Jalankan `filesystem_manage(op="scan")`. | Semua `class_name` terdaftar tanpa error parse. | `global_class_count: 81`, `scan_settle: settled`, 0 error. | **PASS** |
| **TC-02** | Main Menu Default & Skin Selector | `main_menu.tscn` dijalankan | Jalankan `project_run(mode="main")`, periksa visual dan log game. | Menu utama tampil, 3 skin card tampil tanpa overlap, 0 error log. | Menu & 3 skin card (`Cyan Debugger`, `Volt Scout`, `Plasma Sentinel`) tampil rapi, 0 error. Footer kiri bawah masih tertulis `BUILD v1.0` (`BUG-A01`). | **PASS (Minor)** |
| **TC-03** | Modal Pilih Dunia & Level | Berada di Main Menu | Klik tombol `PILIH DUNIA & LEVEL`, periksa World 1–5, tekan `Esc`. | World 1 terbuka (Level 1–3 dengan ikon status), World 2–5 terkunci, `Esc` menutup modal. | Semua elemen 9-slice, world badge, level icon, dan lock icon tampil rapi; `Esc` menutup modal. | **PASS** |
| **TC-04** | Modal Bug Log (Main Menu) | Berada di Main Menu | Klik tombol `BUG LOG`, periksa daftar kartu bug, tekan `Esc`. | Kartu bug tampil memakai `UiPixelTheme.build_bug_card` dengan kotak diff Salah/Benar. | Kartu `BUG-02`..`BUG-04` dst. tampil jelas dengan diff merah/hijau dan tag kategori. | **PASS** |
| **TC-05** | Modal Pengaturan (`Settings`) | Berada di Main Menu | Klik tombol `PENGATURAN`, periksa slider Audio, toggle Fullscreen, grid Keycap, dan tombol Reset. | Slider memiliki track & grabber pixel, toggle switch & keycap grid rapi. | Awalnya track slider tidak terlihat (`BUG-A02`). Setelah perbaikan `pad_v = 4`, track cyan, fill, dan grabber pixel tampil jelas. | **PASS (Fixed)** |
| **TC-06** | HUD In-Game Level 1 (`HudTopBar` & `DebugToolDock`) | `level_1.tscn` dijalankan | Periksa layout `TopBar` dan `DebugToolDock` serta log game. | Vitality (`100/100`), Quest Card, `Bug Log`, `Menu Utama`, dan `DebugToolDock` bebas overlap. | Seluruh elemen HUD tampil presisi tanpa overlap, 0 error log. | **PASS** |
| **TC-07** | Pergerakan Dex & Interaksi Terminal 1 | Berada di Level 1 | Gerakkan Dex ke kiri (`move_left`) mendekati `Terminal_1`, lalu tekan `E`. | Prompt `[E]` muncul saat dekat terminal; menekan `E` membuka `TerminalOverlay`. | Dex bergerak ke `Terminal_1`, prompt `[E]` muncul, menekan `E` membuka `Terminal 1/4`. | **PASS** |
| **TC-08** | Negative Case Python (`NameError`) & Hint | `TerminalOverlay` terbuka di `Terminal_1` | Klik `Run [Ctrl+Enter]` pada kode awal (`prin(status_laser)`), lalu klik `Hint (0/3) [F1]`. | Muncul pesan `NameError`, baris error di-highlight merah, variabel tampil, dan `Hint 1` muncul. | Pesan `NameError (Baris 3)` muncul tepat, baris 3 merah, variabel `status_laser` & `kode_akses` terbaca, `Hint (1/3)` tampil. Header `Lint (AI Pendamping):` sedikit terpotong di atas (`BUG-A03`). | **PASS (Minor)** |
| **TC-09** | Level 2 Launch & `HudTopBar` | `level_2.tscn` dijalankan | Periksa spawn Dex, `HudTopBar`, `DebugToolDock`, dan log game. | Level 2 berjalan normal, progress `Terminal: 0/5 | [Tab]`, 0 error log. | Level 2 berjalan normal, layout bersih, 0 error log. | **PASS** |
| **TC-10** | Mini Pause Confirm Popup | Berada di Level 2 | Klik tombol `Menu Utama` di `HudTopBar`, periksa popup, lalu tekan `Esc`. | Popup `JEDA — KEMBALI KE MENU UTAMA?` muncul; `Esc` menutup popup kembali ke level. | Popup tampil di tengah layar dengan tombol `Lanjutkan Level` & `Ke Menu Utama`; `Esc` menutup popup. | **PASS** |
| **TC-11** | Level 3 Launch & Bug Log In-Game (`[L]`) | `level_3.tscn` dijalankan | Periksa Level 3 dan tekan `L` untuk membuka Bug Log in-game. | Level 3 bebas error dan modal `BUG LOG — LEVEL 3 (0/5)` terbuka. | Level 3 berjalan normal, 0 error log, modal Bug Log in-game tampil rapi. | **PASS** |

> **Catatan Cakupan Uji (`Not Run / Partial`):** Pengujian alur penyelesaian penuh seluruh terminal hingga `ExitGate` terbuka, pengurangan HP hingga `0` (respawn), dan eksekusi klik `Ya, Reset` pada `Reset Progres Reward` tidak dijalankan pada sesi ini agar data progres lokal pengguna tetap aman.

---

## 4. Log Temuan Bug & Cacat (`Defect Log`)

| ID Bug | Severity | Priority | Lokasi / File | Deskripsi Masalah | Status | Tindakan Perbaikan |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **BUG-A02** | **Major** | High | `scripts/ui/menus/main_menu.gd` (`_create_slider_row`) | Track dan fill bar pada `HSlider` Audio (Master, BGM, SFX) di modal Pengaturan tidak terlihat (tinggi `0 px`) karena `UiPixelTheme.make_9slice(..., 6, 0, 0)` mengatur `pad_v = 0`. | **FIXED & VERIFIED** | Mengubah `pad_h, pad_v` menjadi `4, 4` pada `slider`, `grabber_area`, dan `grabber_area_highlight`, lalu diverifikasi ulang lewat screenshot. |
| **BUG-A01** | **Minor** | Low | `scripts/ui/menus/main_menu.gd` (Footer Main Menu) | Teks versi pada footer kiri bawah Main Menu masih bertuliskan `BUILD v1.0 • SYNTAX SHORE`, belum diperbarui ke `v1.1`. | **OPEN** | Perbarui string label footer dari `BUILD v1.0` ke `BUILD v1.1` pada iterasi polish berikutnya. |
| **BUG-A03** | **Minor** | Low | `scenes/ui/terminal/terminal_overlay.tscn` / `scripts/ui/terminal/terminal_overlay.gd` | Label judul `Lint (AI Pendamping):` di panel kanan bawah `TerminalOverlay` sedikit terpotong di tepi atas kontainer scroll. | **OPEN** | Tambah `content_margin_top` atau `MarginContainer` pada kontainer teks dialog Lint di `TerminalOverlay`. |

---

## 5. Kesimpulan & Rekomendasi Tindak Lanjut

1. **Stabilitas Runtime:** Seluruh scene inti V1.1 (`main_menu.tscn`, `level_1.tscn`, `level_2.tscn`, `level_3.tscn`) berjalan stabil tanpa `SCRIPT ERROR` atau `push_error` selama pengujian interaktif.
2. **Kualitas UI Rework V1.1:** Implementasi `UiPixelTheme` dan `HudTopBar` berhasil menyeragamkan tampilan pixel 9-slice di Main Menu maupun HUD in-game tanpa bentrok dengan `DebugToolDock`.
3. **Rekomendasi Sebelum Rilis Beta:**
   - Perbaiki **BUG-A01** (`BUILD v1.0` → `BUILD v1.1`) dan **BUG-A03** (padding atas teks `Lint (AI Pendamping):`).
   - Lakukan sesi uji khusus penyelesaian penuh Level 1–3 (*full playthrough*) hingga `ExitGate` dan uji reset progres pada profil simpan uji coba.
