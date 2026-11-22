set -euo pipefail
pkg=info.gabrimatic.localwhisper
export EVIDENCE="$RUNNER_TEMP/fourier-ui"
mkdir -p "$EVIDENCE"
adb shell getprop ro.product.cpu.abi
adb shell wm size 1080x2200
adb shell wm density 240
adb install src/flutter/local_whisper/build/app/outputs/flutter-apk/app-release.apk
adb install "$RUNNER_TEMP/editor/editor.apk"
adb shell pm grant "$pkg" android.permission.RECORD_AUDIO
adb shell ime enable "$pkg/.LocalWhisperInputMethodService"
adb shell ime set "$pkg/.LocalWhisperInputMethodService"
adb shell settings put secure show_ime_with_hard_keyboard 1
adb emu avd hostmicon
espeak -v en-us -s 145 -w "$RUNNER_TEMP/blue.wav" "The blue notebook is on the table."
appium --address 127.0.0.1 --port 4723 > "$EVIDENCE/appium.log" 2>&1 &
for i in $(seq 1 45); do curl -fsS http://127.0.0.1:4723/status >/dev/null 2>&1 && break; sleep 1; done
trap 'adb logcat -d -v brief | grep -iE "flutter|AudioRecord|audioflinger|lowmemorykiller|FATAL EXCEPTION|AndroidRuntime" | tail -220 > "$EVIDENCE/android.log" || true; pactl list source-outputs > "$EVIDENCE/pulse-final.txt" || true' EXIT
python3 -u .github/fourier-review/drive-gui.py | tee "$EVIDENCE/observed.txt"
