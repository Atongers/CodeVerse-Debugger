# Laporan Alpha Testing — CodeVerse: Debugger (V2.0)

**Tanggal Pengujian:** 16 November 2026  
**Versi Build:** V2.0 (World 2: Condition Canyon + Main Menu V2.0 + Regresi World 1)  
**Engine:** Godot `4.7.2-stable` (2D, Forward Plus)  
**Penguji:** AI QA / Godot Developer (`test_run` Suite & `godot-ai` MCP Runtime)

---

## 1. Ringkasan Eksekutif

Pengujian Alpha Build **V2.0** dilakukan untuk memverifikasi integrasi penuh **World 2: Condition Canyon (`Milestone 2A` & `2B`)**, ekspansi `PythonInterpreter` untuk `if/elif/else`, sistem ekonomi/RPG (`Scrap Bits`, `Workbench`, `Upgrade Tree`, `Quest`, `Achievements`), pembaruan Main Menu, serta jaminan **Zero Regression** pada **World 1 (`Syntax Shore`)**.

Dari **12 skenario pengujian (`TC-01` s.d. `TC-12`)**:
- **12 skenario berstatus `PASS`** setelah perbaikan pasca-Alpha (seluruh temuan `BUG-V2-01` s.d. `BUG-V2-04` dan bug musuh World 2 telah diperbaiki dan diverifikasi ulang).
- **0 runtime `SCRIPT ERROR` atau `push_error`** selama seluruh sesi runtime di `main_menu.tscn`, `world_2_city.tscn`, dan `level_1.tscn`.

**Keputusan Alpha Gate:** **LULUS (`PASS`) — SIAP KE TAHAP BETA / DETAILING GDD** (seluruh *Major* dan *Minor* yang tercatat telah diperbaiki dan terverifikasi via `test_run` dan screenshot runtime).

---

## 2. Lingkungan & Ruang Lingkup Uji

| Parameter | Detail |
| :--- | :--- |
| **Main Scene** | `res://scenes/ui/menus/main_menu.tscn` |
| **Scene Baru V2.0** | `res://scenes/levels/world_2_condition_canyon/world_2_city.tscn` (`120 × 80` tiles @ `16×16 px`) |
| **Scene Regresi W1** | `res://scenes/levels/world_1_syntax_shore/level_1.tscn` |
| **Autoload Aktif** | `SaveManager` (V2: `user://save_data.json`), `_mcp_game_helper` |
| **Resolusi Viewport** | `1152 × 648` (`canvas_items`, `expand`) |
| **Metode Uji** | `filesystem_manage(op="scan")`, `test_run(suite="world_2")`, `project_run` interaktif (`game_manage`), `editor_screenshot(source="game")`, dan audit log (`logs_read(source="game")`). |

---

## 3. Matriks Test Case

| ID | Modul / Fitur | Prasyarat | Langkah Uji | Hasil yang Diharapkan | Hasil Aktual | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-01** | Class Registration & GDScript Scan | Editor Godot terbuka | Jalankan `filesystem_manage(op="scan")`. | Semua script & `class_name` terdaftar tanpa parse error. | `global_class_count: 91`, `scan_settle: settled`, 0 error. | **PASS** |
| **TC-02** | Automated Test Suite (`world_2`) | Suite `tests/test_world_2.gd` | Jalankan `test_run(suite="world_2", verbose=true)`. | `test_interpreter_world1_regression`, `test_interpreter_world2_conditionals_and_bugs`, `test_save_manager_and_rpg_state`, `test_world2_scene_and_entities_build` lulus semua. | `4/4` test methods **PASSED** (`52` total assertions, `0` failed, durasi `56 ms` pasca-fix). | **PASS** |
| **TC-03** | Main Menu V2.0 & Modal Achievements | `main_menu.tscn` berjalan | Klik `ACHIEVEMENTS` dan periksa daftar 12 badge serta footer Main Menu. | 12 badge RPG (`ACH-01..12`) tampil jelas sesuai status unlock; footer menunjukkan versi build terkini. | Awalnya footer tertulis `BUILD v1.1`; setelah fix (`BUG-V2-04`) tampil `BUILD v2.0 • CONDITION CANYON` bersama 12 badge RPG. | **PASS (Fixed)** |
| **TC-04** | Modal Pilih Dunia & Level (World 1–5) | Berada di Main Menu | Klik `PILIH DUNIA & LEVEL`, periksa kartu Dunia 1–5 & tombol `Act 1..3` Dunia 2. | Semua tombol (`Level 1..3`, `Act 1..3`, label `Terkunci`) muat di dalam modal tanpa terpotong atau scrollbar horizontal. | Awalnya tombol `Act 1..3` melebar ke kanan (`BUG-V2-01`). Setelah `btn_box` dipindah ke bawah deskripsi, seluruh tombol & status tampil utuh tanpa scrollbar horizontal. | **PASS (Fixed)** |
| **TC-05** | Launch World 2 Act 1 & Cutscene Prolog | `world_2_city.tscn` dijalankan | Jalankan scene `world_2_city.tscn`, tutup Cutscene 3-slide (`Esc`), cek spawn Distrik 1 & `HudTopBar`. | Cutscene menutup, `ACH-01` terbuka, Dex spawn di Outskirts Bunker (`x ≈ 220`), `HudTopBar` + `World2ActionBar` + `DebugToolDock` bebas overlap. | Seluruh elemen peta & HUD tampil tajam pada `zoom = 1.5` tanpa overlap, 0 runtime error. | **PASS** |
| **TC-06** | Modal Upgrade Tree 12 Node (`[U]`) | Berada di World 2 | Tekan tombol `[U]` untuk membuka `UpgradeTreeOverlay`, lalu tekan `Esc`. | 3 cabang (`Survival`, `Tactical EMP`, `Utility`), 12 ikon node, konektor `Line2D`, & panel detail tampil rapi. | Seluruh 12 node, konektor `Line2D`, dan keterangan syarat/harga tampil bersih; `Esc` menutup modal. | **PASS** |
| **TC-07** | Modal Jurnal Misi & Lore (`[J]`) | Berada di World 2 | Tekan tombol `[J]` untuk membuka `QuestJournalOverlay`, cek daftar quest & 3 arsip lore. | `MQ-01` berstatus `AKTIF`, `SQ-01..03` & `MQ-02..03` berstatus `TERKUNCI`, `LORE-01..03` tampil di panel kanan. | Layout split Quest & Lore terbaca rapi tanpa clipping. | **PASS** |
| **TC-08** | Shortcut Main Menu ke `Act 2: Gardu Timur` | Di modal Level Select | Klik tombol `W2_Act2Btn` (`Act 2: Gardu Timur`). | Pindah ke `world_2_city.tscn`, sandbox Act 2 aktif (`90 Bits`, `2x Patch`, `2x Battery`, `Terminal: 2/5`), Dex spawn di Distrik 4 (`x ≈ 1100`). | Scene berpindah mulus ke Distrik 4 (`x=1115.8, y=672.2`), `[MQ-02]` aktif, `NPC` menampilkan `?`, `0` runtime error. | **PASS** |
| **TC-09** | Combat EMP Pulse (`[F]`) & AI Musuh | Berada di Distrik 4 (Act 2) | Gerakkan Dex ke kanan mendekati `PatrolDrone` & `ShieldSentinel`, tekan `F`. | EMP Pulse merusak `PatrolDrone`; musuh tidak menumpuk & serangan berupa proyektil; `ShieldSentinel` tidak overlap label dan mengunci `Terminal_3`. | Soft separation, proyektil bola energi `PatrolDrone`, telegraph lunge `ScrapHound`, `Row 0` patroli, label `ShieldSentinel`, & gating `Terminal_3` diperbaiki dan berjalan 0 error. | **PASS (Fixed)** |
| **TC-10** | Quick-Use Item Crafted (`[1]` Repair Patch) | HP Dex < 100 & Patch > 0 | Tekan tombol angka `1` saat HP berkurang (`55/100`). | Stok `[1] Patch` berkurang (`2 -> 1`) dan HP Dex bertambah `+50`. | Tombol HUD berubah menjadi `[1] Patch (1)` dan HP terpulihkan sebelum serangan berikutnya masuk. | **PASS** |
| **TC-11** | Camera Overview Map (`[Tab]`) & Boss Act 3 | Berada di World 2 | Tekan `[Tab]` untuk zoom out & uji `Act 3: Boss Gatekeeper`. | Ke-5 distrik terlihat jelas; label `Terminal_4A`, `Terminal_4B`, & `BossGatekeeperAI` tidak saling bertumpuk. | Posisi `Terminal_4A` & `BossGatekeeperAI` terpisah bersih saat `Act 3` diverifikasi ulang; tombol EMP `[F]` terhubung mulus ke sub-node Boss. | **PASS (Fixed)** |
| **TC-12** | Regresi World 1 (`level_1.tscn`) | World 2 selesai diuji | Jalankan `level_1.tscn` via `project_run` dan periksa `logs_read(source="game")`. | World 1 berjalan normal tanpa kerusakan dari perubahan interpreter/SaveManager V2. | `level_1.tscn` live (`helper_live: true`), `0` error runtime. | **PASS** |

> **Catatan Cakupan (`Partial / Not Run`):** Alur penyelesaian penuh seluruh terminal World 2 secara berurutan di UI (`Terminal_1` -> `Workbench Calibration` -> `Terminal_2` -> `Terminal_3` -> `Terminal_4A` & `4B` Boss Restoration) diverifikasi logikanya lewat unit test `tests/test_world_2.gd`, namun playthrough manual berurutan dari Act 1 hingga Victory Modal World 2 belum diselesaikan seluruhnya dalam 1 sesi runtime kontinu.

---

## 4. Log Temuan Bug & Cacat (`Defect Log`)

| ID Bug | Severity | Priority | Lokasi / File | Deskripsi Masalah | Status | Rekomendasi Perbaikan |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **BUG-V2-01** | **Major** | High | `scripts/ui/menus/main_menu.gd` (`_build_level_select_modal`) | Penambahan 3 tombol Act (`custom_minimum_size = 126x34`) pada baris Dunia 2 membuat lebar total baris melebihi ukuran modal (`780 px`), memicu scrollbar horizontal dan memotong tombol `Level 3`, `Act 3`, serta label `Terkunci` Dunia 3–5 di sisi kanan. | **FIXED & VERIFIED** | Memindahkan `btn_box` Dunia 2 ke bawah deskripsi (`iv` `VBoxContainer`), diverifikasi ulang lewat screenshot tanpa scrollbar horizontal maupun clipping. |
| **BUG-V2-02** | **Minor** | Medium | `scripts/characters/enemy_topdown.gd` | Musuh (`PatrolDrone_1` & `PatrolDrone_2`) tidak memiliki *separation steering* dan menembak secara hitscan instan. | **FIXED & VERIFIED** | Menambahkan *soft separation steering* antar anggota `w2_enemies`, proyektil energi nyata `120 px/s`, telegraph lunge `ScrapHound`, serta animasi `Row 0` `ShieldSentinel`. |
| **BUG-V2-03** | **Minor** | Low | `scripts/levels/world_2_city_builder.gd`, `enemy_topdown.gd`, `boss_gatekeeper_ai.gd` | Teks label status `BossGatekeeperAI` bertumpuk dengan `Terminal_4A` dan label `HP` `ShieldSentinel` bersinggungan dengan kubah perisai; `_process()` Boss belum memiliki guard editor. | **FIXED & VERIFIED** | Menaikkan offset label `ShieldSentinel`, menggeser `Terminal_4A` & `BossGatekeeperAI`, mengganti serangan Boss Fase 0 menjadi bola laser yang dapat dihindari, serta menambah `Engine.is_editor_hint()`. |
| **BUG-V2-04** | **Minor** | Low | `scripts/ui/menus/main_menu.gd` (Footer Main Menu) | Teks label versi di kiri bawah Main Menu (`ver_lbl.text`) masih menampilkan `"BUILD v1.1 • SYNTAX SHORE"`, belum mencerminkan build V2.0. | **FIXED & VERIFIED** | Memperbarui string footer menjadi `"BUILD v2.0 • CONDITION CANYON"` dan diverifikasi di Main Menu. |
