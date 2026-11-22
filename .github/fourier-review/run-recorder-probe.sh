set -euo pipefail
e="$RUNNER_TEMP/native-stop"; mkdir -p "$e"
app=info.gabrimatic.localwhisper
py="$RUNNER_TEMP/audio-python/bin/python"
t="$RUNNER_TEMP/audio-generated"; mkdir -p "$t"
proto="$(find "$ANDROID_HOME/emulator" -name emulator_controller.proto | head -1)"
"$py" -m grpc_tools.protoc -I "$(dirname "$proto")" --python_out="$t" --grpc_python_out="$t" "$proto"
export PYTHONPATH="$t"
trap 'adb logcat -d -b all -v brief | grep -Ei "FOURIER_NATIVE_RECORDER|sherpa|onnx|crash|FATAL EXCEPTION|lmkd|lowmemorykiller" | tail -220 > "$e/guest.log" || true; adb shell dumpsys meminfo "$app" > "$e/final-meminfo.txt" || true' EXIT
adb install src/flutter/local_whisper/build/app/outputs/flutter-apk/app-release.apk
adb shell input keyevent KEYCODE_WAKEUP
adb shell wm dismiss-keyguard
adb shell cmd connectivity airplane-mode enable
adb shell svc wifi disable
adb shell svc data disable
adb shell am start -n "$app/.MainActivity"
"$py" .github/fourier-review/gui-press.py 'Record probe'
"$py" .github/fourier-review/gui-press.py 'While using the app'
for i in $(seq 1 50); do adb logcat -d -s flutter:I | grep -q 'FOURIER_NATIVE_RECORDER RECORDING' && break; sleep .25; done
adb logcat -d -s flutter:I | grep 'FOURIER_NATIVE_RECORDER RECORDING'
espeak -v en-us -s 145 -w "$e/spoken.wav" 'The blue notebook is on the table.'
"$py" .github/fourier-review/grpc-audio.py --speech-padding "$e/spoken.wav" | tee "$e/grpc.txt"
"$py" .github/fourier-review/gui-press.py 'Stop probe'
for i in $(seq 1 65); do adb logcat -d -s flutter:I | grep -q 'FOURIER_NATIVE_RECORDER FINALIZED' && break; sleep .5; done
adb logcat -d -s flutter:I | grep 'FOURIER_NATIVE_RECORDER' | tee "$e/method-channel.txt"
grep -q FINALIZED "$e/method-channel.txt"
adb forward tcp:17609 tcp:17609
curl --fail --silent --show-error --max-time 20 http://127.0.0.1:17609/finalized-microphone.wav -o "$e/finalized-microphone.wav"
adb forward --remove tcp:17609
"$py" .github/fourier-review/compare-captured.py "$e"
