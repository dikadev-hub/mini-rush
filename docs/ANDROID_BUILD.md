# ANDROID BUILD — Mini Rush

## Persyaratan
- Godot 4.3 stable + export templates 4.3.stable.
- JDK: **spec meminta 17; lingkungan ini memakai OpenJDK 21.0.12** (Godot 4.3
  menerima JDK 17+; simpan catatan ini sebagai penyimpangan lingkungan, bukan
  perubahan kontrak). `export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`.
- Android SDK: `ANDROID_HOME=~/android-sdk`, platform-34, build-tools 34.0.0.
- Keystore debug: `~/.android/debug.keystore`, alias `androiddebugkey`, storepass `android`.

## Preset
`export_presets.cfg` preset **Android**: package `com.minirush.game`, app `Mini Rush`,
`gradle_build/use_gradle_build=false` (pakai APK template prebuilt, tanpa gradle),
hanya `arm64-v8a`, `permissions/internet=true`, output `build/MiniRush.apk`.

## Langkah
```bash
bash scripts/check_project.sh          # wajib lulus dulu
bash scripts/build_android.sh debug    # output build/MiniRush-debug.apk
bash scripts/build_android.sh release
```

Script otomatis:
1. Menulis `~/.config/godot/editor_settings-4.3.tres` dengan
   `export/android/java_sdk_path` dan `export/android/android_sdk_path`
   (Godot 4.3 headless menuntut keduanya di Editor Settings; env
   `GODOT_ANDROID_KEYSTORE_DEBUG_*` hanya menutup keystore).
2. Export via `--export-debug|--export-release "Android"`.
3. Verifikasi: file ada, ukuran > 5 MB, `unzip -l` mengandung `lib/arm64-v8a/`,
   `apksigner verify` (fallback `jarsigner -verify`). Gagal mana pun → exit non-zero.

## Catatan verifikasi (gelombang 1)
- Preset dikenali Godot 4.3: `--export-debug "Android" --dry-run` menemukan preset;
  penolakan hanya soal Java/Android SDK path di Editor Settings (bukan opsi tidak dikenal).
- Full build **belum dijalankan** (disk ketat) — jalankan di gelombang 3.
