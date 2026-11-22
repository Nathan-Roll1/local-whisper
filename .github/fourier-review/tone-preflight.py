import json, os, re, subprocess, sys, time, wave
from pathlib import Path
import xml.etree.ElementTree as ET
import numpy as np
out=Path(os.environ['QA_MIC_DIR'])
rate=16000
tones=[523,947,691]
def click_visible(labels):
    for _ in range(15):
        subprocess.run(['adb','shell','uiautomator','dump','/sdcard/view.xml'],capture_output=True)
        tree=subprocess.check_output(['adb','exec-out','cat','/sdcard/view.xml'])
        for node in ET.fromstring(tree).iter():
            if node.get('text','').casefold() not in labels:continue
            x,y,a,b=map(int,re.findall(r'\d+',node.get('bounds','')))
            subprocess.run(['adb','shell','input','tap',str((x+a)//2),str((y+b)//2)],check=True)
            print('Tapped visible control:',node.get('text'),flush=True);return
        time.sleep(.25)
    raise RuntimeError('Missing visible control: '+str(labels))
if sys.argv[1]=='prepare':
    t=np.arange(rate)/rate
    chunks=[np.zeros(rate//4)]
    for f in tones:
        chunks.extend([np.sin(2*np.pi*f*t)*15000,np.zeros(rate//4)])
    with wave.open(str(out/'expected.wav'),'wb') as fp:
        fp.setparams((1,2,rate,0,'NONE',''))
        fp.writeframes(np.concatenate(chunks).astype('<i2').tobytes())
    click_visible({'start microphone capture'})
    click_visible({'while using the app','only this time'})
else:
    data=np.fromfile(out/'guest.pcm',dtype='<i2').astype(float)
    events={f:[] for f in tones}; peaks=[]
    for offset in range(0,len(data)-1600,800):
        a=data[offset:offset+1600]; rms=np.sqrt(np.mean(a*a))
        if rms<400:continue
        spectrum=np.abs(np.fft.rfft(a*np.hanning(len(a))))
        f=int(np.argmax(spectrum))*10
        for expected in tones:
            if abs(f-expected)<=12:events[expected].append(offset/rate)
        peaks.append(round(float(rms),2))
    samples=[len(events[f]) for f in tones]
    onset=[min(events[f]) if events[f] else None for f in tones]
    passed=all(i>=12 for i in samples) and all(0.8<b-a<1.8 for a,b in zip(onset,onset[1:]))
    result={'emulated':True,'api':'Android AudioRecord(MIC), 16000 Hz signed mono 16-bit','frames':len(data),'frequencies_hz':tones,'matching_100ms_windows_50ms_hop':samples,'first_match_seconds':onset,'peak_window_rms':max(peaks,default=0),'passed':passed}
    (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(result,flush=True)
    if not passed:raise SystemExit('No confirmed three-tone microphone signal')
