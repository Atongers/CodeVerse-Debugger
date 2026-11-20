# Verifikasi Sistem Audio V2.1 — CodeVerse: Debugger

Dokumen verifikasi akhir untuk **Audio System V2.1** (`GitHub Epic #17`, `#18`, `#19`, `#20`, `#21`, `#22`) berdasarkan [`GDD/GDD-V2.0/audio_github_issues_draft.md`](../GDD/GDD-V2.0/audio_github_issues_draft.md) dan [`GDD/GDD-V2.0/audio_asset_pack_report.md`](../GDD/GDD-V2.0/audio_asset_pack_report.md).

## 1. Ringkasan Implementasi
- **Autoload `AudioManager`:** [`scripts/autoload/audio_manager.gd`](../scripts/autoload/audio_manager.gd) terdaftar di [`project.godot`](../project.godot).
- **Hierarki Audio Bus:** `Master -> BGMDuck -> BGM`, `Ambience -> Master`, `SFX -> Master`, `UI -> SFX`.
- **Kurva Volume & Settings:** Konversi kuadrat `pct_to_db(pct)` (`linear_to_db(gain * gain)`, `-80.0 dB` & mute pada `0%`) tersinkron dengan `user://settings.cfg` dan didelegasikan dari [`scripts/ui/menus/main_menu.gd`](../scripts/ui/menus/main_menu.gd).
- **Auto-Ducking (`-10 dB / 0.25s`):** Reference-counted per `source_id` pada `BGMDuck` saat membuka/menutup `TerminalOverlay`, `WorkbenchOverlay`, dan dialog NPC.
- **Anti-Spam & Anti-Stacking:** `AudioStreamRandomizer` (`code_type`, `dex_step`, `emp_pulse`), throttle per-event (`>= 35 ms` ketikan kode), dan `set_loop_user_active` berbasis jarak/pemakai untuk `sfx_laser_hum.wav`, `sfx_elevator_move.wav`, dan `sfx_crane_move.wav`.
- **Integrasi BGM, Ambience & 52 SFX:** Main Menu, Story Cutscene, World 1 (Level 1–3 + mesin & hazard), World 2 (Condition Canyon + Top-Down Dex + 3 tipe musuh + Workbench + Upgrade Tree + Quest/Achievements + Boss Gatekeeper AI).

## 2. Hasil Audit Aset & Loudness (`Issue #19` & `#20`)
- **Total Aset Terverifikasi:** `59` file (`7 .ogg` di `assets/audio/bgm/` + `52 .wav` PCM 16-bit 44100 Hz di `assets/audio/sfx/`), semuanya tercantum di [`assets/asset-manifest.json`](../assets/asset-manifest.json) (`technical_checks_passed: true`) dan berstatus `import_valid: true` di Godot 4.7.2 (`59` `.import` files; seluruh `7` `.ogg` memakai `loop=true`).
- **Pengukuran `ffmpeg ebur128` (7 file `.ogg`):**
  - `bgm_main_menu.ogg`: `-24.0 LUFS`
  - `bgm_world1_syntax_shore.ogg`: `-24.0 LUFS`
  - `bgm_story_cutscene.ogg`: `-24.0 LUFS`
  - `bgm_world2_condition_canyon.ogg`: `-24.0 LUFS`
  - `bgm_boss_gatekeeper.ogg`: `-24.0 LUFS`
  - `amb_lab_hum.ogg`: `-24.0 LUFS`
  - `amb_canyon_wind.ogg`: `-24.2 LUFS`
- **Audit WAV (52 file `.wav`):** Peak berada di rentang `-5.50 dBFS` s/d `-3.50 dBFS` (`0` file melebihi `-1.0 dBFS`, `0` file dengan leading silence `>= 3 ms`).

## 3. Hasil Pengujian Otomatis & Runtime Godot 4.7.2
- **Automated Test Suites (`test_run`):**
  - Suite `audio_system` ([`tests/test_audio_system.gd`](../tests/test_audio_system.gd)): **3/3 test PASSED** (`143` assertions: bus topology, quadratic curve, 59 asset paths + manifest QA, crossfade BGM/Ambience, auto-ducking, pool SFX/UI & loop manager).
  - Suite `world_2` ([`tests/test_world_2.gd`](../tests/test_world_2.gd)): **4/4 test PASSED** (`52` assertions, `0` regresi).
- **Runtime Verification (`project_run` + `logs_read(source="game")`):**
  - Main Menu (`main_menu.tscn`), World 1 (`level_1.tscn`), dan World 2 (`world_2_city.tscn`) berjalan dengan `helper_live: true` dan `0` runtime/script errors.
