"""Compare a known speech waveform to the actual WAV returned by the Android recorder."""
import json, sys, wave
from pathlib import Path
import numpy as np
root=Path(sys.argv[1])
def read(name):
    with wave.open(str(root/name),'rb') as f:
        assert f.getnchannels()==1 and f.getsampwidth()==2
        return np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float),f.getframerate()
ref,ref_hz=read('spoken.wav'); guest,guest_hz=read('finalized-microphone.wav'); assert guest_hz==16000
ref=np.interp(np.arange(round(len(ref)*guest_hz/ref_hz))*ref_hz/guest_hz,np.arange(len(ref)),ref)
def similarity(a,b):
    n=1 << (len(a)+len(b)-1).bit_length()
    spec=np.fft.rfft(a,n)*np.fft.rfft(b[::-1],n)
    c=np.fft.irfft(spec,n)[len(b)-1:len(a)]
    norm=np.r_[0.0,np.cumsum(a*a)]
    denom=np.sqrt(np.maximum(1.0,norm[len(b):]-norm[:-len(b)]) * max(1,np.sum(b*b)))
    score=np.abs(c)/denom
    offset=int(np.argmax(score))
    return float(score[offset]),offset
# The signal-envelope check tolerates the emulator and guest's AGC, filtering,
# and small phase errors from audio resampling.
frame=160
def env(x):
    a=x[:len(x)//frame*frame].reshape(-1,frame)
    return np.sqrt((a*a).mean(axis=1))
rms=env(ref); rec=env(guest)
corr,off=similarity(guest,ref)
ec,eo=similarity(rec-rec.mean(),rms-rms.mean())
result={'actual_sample_rate':guest_hz,'finalized_frames':len(guest),'captured_seconds':len(guest)/guest_hz,'fixture_seconds':len(ref)/guest_hz,'normalized_waveform_correlation':round(corr,4),'waveform_offset_seconds':round(off/guest_hz,3),'normalized_10ms_energy_envelope_correlation':round(ec,4),'envelope_offset_seconds':round(eo*frame/guest_hz,3),'native_wav_contains_the_spoken_fixture':bool(corr>=.35 or ec>=.82)}
(root/'waveform-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(result)
if not result['native_wav_contains_the_spoken_fixture']:raise SystemExit('Waveform did not match the spoken fixture')
