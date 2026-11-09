# INSTALLATION — Mini Rush

## 1. Godot 4.3 headless
```bash
mkdir -p ~/godot && cd ~/godot
wget https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip
unzip Godot_v4.3-stable_linux.x86_64.zip && chmod +x Godot_v4.3-stable_linux.x86_64
~/godot/Godot_v4.3-stable_linux.x86_64 --version   # wajib 4.3.stable
```

## 2. Export templates
```bash
wget https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz
mkdir -p ~/.local/share/godot/export_templates/4.3.stable
unzip Godot_v4.3-stable_export_templates.tpz -d /tmp/tpl
mv /tmp/tpl/templates/* ~/.local/share/godot/export_templates/4.3.stable/
```

## 3. JDK
Spec meminta JDK 17. Lingkungan pengembangan ini memakai **OpenJDK 21.0.12**
(Godot 4.3 menerima JDK 17+; penyimpangan dicatat di docs/ANDROID_BUILD.md dan
docs/reports/a9_qa_build.md):
```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
```

## 4. Android SDK
```bash
export ANDROID_HOME=$HOME/android-sdk
# cmdline-tools → $ANDROID_HOME/cmdline-tools/latest
yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager \
  "platform-tools" "platforms;android-34" "build-tools;34.0.0" "cmdline-tools;latest"
```

## 5. Keystore debug (sudah dibuat di lingkungan ini)
```bash
keytool -genkeypair -v -keystore $HOME/.android/debug.keystore \
  -storepass android -alias androiddebugkey -keypass android \
  -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```

## 6. Env Godot Android (dipakai scripts/build_android.sh otomatis)
```bash
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$HOME/.android/debug.keystore
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
export GODOT_ANDROID_SDK_PATH=$ANDROID_HOME
```
Catatan verifikasi: env keystore di atas **diakui** Godot 4.3 headless; tetapi
`export/android/java_sdk_path` dan `export/android/android_sdk_path` harus ada di
`~/.config/godot/editor_settings-4.3.tres` — `build_android.sh` menuliskannya bila belum ada.

## 7. Verifikasi
```bash
bash scripts/check_project.sh
```
