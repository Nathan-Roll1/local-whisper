set -euo pipefail
dir="$RUNNER_TEMP/fourier-mic"; mkdir -p "$dir"
export QA_MIC_DIR="$dir"
py="$RUNNER_TEMP/audio-python/bin/python"
t="$RUNNER_TEMP/audio-generated"; mkdir -p "$t"
proto="$(find "$ANDROID_HOME/emulator" -name emulator_controller.proto | head -1)"
test -s "$proto"
"$py" -m grpc_tools.protoc -I "$(dirname "$proto")" --python_out="$t" --grpc_python_out="$t" "$proto"
export PYTHONPATH="$t"
sha256sum "$proto" > "$dir/bundled-proto.sha256"
adb shell getprop ro.build.fingerprint > "$dir/android-build.txt"
"$ANDROID_HOME/emulator/emulator" -version | head -5 > "$dir/emulator-build.txt"
adb install "$RUNNER_TEMP/audio-probe/probe.apk"
trap 'adb logcat -d -s FourierMic:I > "$dir/guest-log.txt"; adb shell dumpsys media.audio_flinger | tail -200 > "$dir/audio-diagnostics.txt"' EXIT
adb shell am start -n org.oruk.qa.audiorecord/.Probe
"$py" .github/fourier-review/tone-preflight.py prepare
for i in $(seq 1 50); do adb logcat -d -s FourierMic:I | grep -q READY && break; sleep .2; done
adb logcat -d -s FourierMic:I | grep READY
"$py" .github/fourier-review/grpc-audio.py "$dir/expected.wav" | tee "$dir/grpc-result.txt"
for i in $(seq 1 70); do adb logcat -d -s FourierMic:I | grep -q DONE && break; sleep .25; done
adb logcat -d -s FourierMic:I | grep DONE
adb exec-out run-as org.oruk.qa.audiorecord cat files/guest.pcm > "$dir/guest.pcm"
"$py" .github/fourier-review/tone-preflight.py analyze
