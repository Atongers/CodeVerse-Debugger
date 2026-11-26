# Verifikasi Web Export V2.2 & Browser Playtest (`#30`)

Dokumen ini mencatat hasil verifikasi teknis *pack export* (`.pck`), simulasi CI tanpa `addons/`, build Web HTML5/WASM *single-threaded*, dan uji jalan di browser lokal untuk **CodeVerse: Debugger** (`Godot 4.7.2-stable`).

---

## 1. Ringkasan Spesifikasi Build Web
- **Preset:** `"Web"` (`export_presets.cfg`, `platform="Web"`, `export_path="build/web/index.html"`)
- **Thread Support:** `false` (`variant/thread_support=false` — aman tanpa header `COOP/COEP` di GitHub Pages)
- **Canvas Policy:** `html/canvas_resize_policy=2` (*Adaptive*), `html/focus_canvas_on_start=true`
- **Exclusion Filter PCK:** Mengecualikan `addons/`, `GDD/`, `documentation/`, `reference/`, `tests/`, `scripts/tests/`, `.agents/`, `build/`, `assets/asset-manifest.json`, `map-animation.gif`, `README.md`, `STRUCTURE.md`, `skills-lock.json`.

---

## 2. Hasil Verifikasi Otomatis & Export CLI (`Godot 4.7.2-stable`)

| Tahap Uji | Perintah / Tool | Hasil | Detail |
| :--- | :--- | :---: | :--- |
| **Editor Scan & Suite MCP** | `filesystem_manage(op="scan")` + `test_run(verbose=true)` | **PASS** | `global_class_count = 91`, `7/7` test methods passed (`audio_system` `3/3`, `world_2` `4/4`, `0 failed`) |
| **Test Mandiri World 2** | `godot --headless --path . --script res://scripts/tests/test_world_2.gd` | **PASS** | `73 passed, 0 failed` (`exit code 0`) |
| **Test Mandiri Audio** | `godot --headless --path . --script res://scripts/tests/test_audio_system.gd` | **PASS** | `143 passed, 0 failed` (`exit code 0`) |
| **Simulasi Checkout CI Bersih** | Salinan tanpa `addons/` + strip `_mcp_game_helper` -> `--import`, `--quit`, `test_world_2.gd` | **PASS** | `--import` exit `0`, `--quit` exit `0`, `73 passed, 0 failed`, `0` missing autoload errors |
| **Export Pack (`.pck`)** | `godot --headless --path . --export-pack "Web" build/game_web.pck` | **PASS** | Ukuran `14,867,420` bytes (~14.18 MB), `560` file terkemas, `0` kebocoran direktori non-runtime |
| **Smoke Test `--main-pack`** | `godot --headless --main-pack build/game_web.pck --quit-after 180` | **PASS** | `exit code 0`, `0` `SCRIPT ERROR` / `Failed to instantiate an autoload` |
| **Export Web Release** | `godot --headless --path . --export-release "Web" build/web/index.html` | **PASS** | `exit code 0`, menghasilkan `index.html`, `index.js`, `index.pck`, `index.wasm` (`39,514,754` bytes) |

---

## 3. Hasil Playtest Browser Lokal (`http://localhost:8060/index.html`)
- **Lingkungan Uji:** Local Python HTTP server (`python -m http.server 8060 --directory build/web`) — diuji manual oleh developer/penguji di browser desktop.
- **Status Uji:** Aman & berjalan normal tanpa error `SharedArrayBuffer` maupun kendala muat build Web single-threaded.
- **Adaptasi Runtime Web yang Aktif (`#28`):**
  - Tombol `KELUAR` otomatis tersembunyi pada `OS.has_feature("web")` tanpa memutus *focus loop* keyboard/gamepad.
  - `_load_user_settings()` tidak memaksa *fullscreen* saat halaman dimuat; toggle *Fullscreen* tetap tersedia lewat klik pengguna di Pengaturan.
  - `AudioManager._input()` menjaga agar BGM/ambience bangkit otomatis setelah gestur klik/tombol pertama pengguna di browser.
