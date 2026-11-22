set -euo pipefail
pkg=info.gabrimatic.localwhisper
export EVIDENCE="$RUNNER_TEMP/fourier-ui"
mkdir -p "$EVIDENCE"
adb shell getprop ro.product.cpu.abi
adb shell wm size 1080x2200
adb shell wm density 240
adb install src/flutter/local_whisper/build/app/outputs/flutter-apk/app-release.apk
adb install "$RUNNER_TEMP/editor/editor.apk"
adb shell settings put secure show_ime_with_hard_keyboard 1
export QA_GRPC_PY="$RUNNER_TEMP/audio-python/bin/python"
t="$RUNNER_TEMP/audio-generated"; mkdir -p "$t"
proto="$(find "$ANDROID_HOME/emulator" -name emulator_controller.proto | head -1)"
test -s "$proto"
"$QA_GRPC_PY" -m grpc_tools.protoc -I "$(dirname "$proto")" --python_out="$t" --grpc_python_out="$t" "$proto"
export PYTHONPATH="$t"
espeak -v en-us -s 145 -w "$RUNNER_TEMP/blue.wav" "The blue notebook is on the table."
appium --address 127.0.0.1 --port 4723 > "$EVIDENCE/appium.log" 2>&1 &
for i in $(seq 1 45); do curl -fsS http://127.0.0.1:4723/status >/dev/null 2>&1 && break; sleep 1; done
trap 'adb logcat -d -v brief | grep -iE "flutter|AudioRecord|audioflinger|lowmemorykiller|FATAL EXCEPTION|AndroidRuntime" | tail -220 > "$EVIDENCE/android.log" || true' EXIT
python3 -u .github/fourier-review/drive-gui.py | tee "$EVIDENCE/observed.txt"
