import os, re, subprocess, time
import xml.etree.ElementTree as ET
from pathlib import Path
import requests
OUT=Path(os.environ["EVIDENCE"]);APP="info.gabrimatic.localwhisper";EDITOR="org.oruk.fourierrevieweditor"
def adb(*args): return subprocess.check_output(["adb",*args],text=True).strip()
def shell(*args):return adb("shell",*args)
def api(method,path,data=None):
    r=requests.request(method,"http://127.0.0.1:4723"+path,json=data,timeout=60)
    if not r.ok: raise RuntimeError((r.status_code,r.text[:1800]))
    return r.json()["value"]
session=api("POST","/session",{"capabilities":{"alwaysMatch":{"platformName":"Android","appium:automationName":"UiAutomator2","appium:deviceName":"emulator","appium:udid":"emulator-5554","appium:noReset":True,"appium:autoLaunch":False,"appium:newCommandTimeout":1200}}})["sessionId"]
base="/session/"+session
api("POST",base+"/appium/settings",{"settings":{"enableMultiWindows":True,"waitForIdleTimeout":0,"waitForSelectorTimeout":400,"ignoreUnimportantViews":False}})
def source():return api("GET",base+"/source")
def nodes():return list(ET.fromstring(source()).iter())
def box(n):
    v=list(map(int,re.findall(r'-?\d+',n.get("bounds",""))))
    return v if len(v)==4 else [0]*4
def pos(n):
    a,b,c,d=box(n);return (a+c)//2,(b+d)//2
def shown(n):
    a,b,c,d=box(n);return n.get("displayed")!="false" and c>a and d>b
def labels(n):return [x.strip() for k in ("text","content-desc","hint") for x in n.get(k,"").splitlines() if x.strip()]
def describe(ns):return [(labels(n),box(n)) for n in ns if shown(n) and labels(n)][:100]
def snap(tag):
    (OUT/(tag+".png")).write_bytes(subprocess.check_output(["adb","exec-out","screencap","-p"]))
    try:(OUT/(tag+".xml")).write_text(source())
    except Exception as e:print(e,flush=True)
def find(ns,label,contains=False,pkg=APP):
    return [n for n in ns if shown(n) and n.get("package")==pkg and any((label.lower() in s.lower() if contains else label.lower()==s.lower()) for s in labels(n))]
def one(ns,label,**kw):
    hits=find(ns,label,**kw)
    if not hits:return None
    return min(hits,key=lambda n:(n.get("clickable")!="true",(box(n)[2]-box(n)[0])*(box(n)[3]-box(n)[1])))
def wait(fn,seconds=25):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        ns=nodes();val=fn(ns)
        if val is not None and val is not False:return val
        time.sleep(.45)
    raise RuntimeError("Missing UI state: "+str(describe(ns)))
def hit(node):
    x,y=pos(node);print("TAP",labels(node),x,y,flush=True);shell("input","tap",str(x),str(y));time.sleep(.55)
def tap(label,**kw):hit(wait(lambda ns:one(ns,label,**kw)))
def app():
    shell("am","start","-n",APP+"/.MainActivity");time.sleep(1)
def transcript(ns,words):
    for n in ns:
        if n.get('package')!=APP or not shown(n):continue
        for s in labels(n):
            if all(w in re.findall(r'[a-z]+',s.lower()) for w in words):return s
    return None
def nav(name):
    def tab(ns):
        found=[n for n in ns if n.get('package')==APP and shown(n) and any(s.lower()==name.lower() or s.lower().startswith(name.lower()+", tab") or s.lower().startswith(name.lower()+" tab ") for s in labels(n))]
        return max(found,key=lambda n:pos(n)[1]) if found else None
    hit(wait(tab))
def go():
    app();tap("Start setup");tap("More choices")
    row=None
    for i in range(8):
        ns=nodes();row=one(ns,"Oruk Fourier 2B",contains=True)
        if row is not None:break
        shell("input","swipe","520","1730","520","950","450");time.sleep(.4)
    if row is None:raise RuntimeError("Fourier picker row missing "+str(describe(ns)))
    y=pos(row)[1]; installs=find(ns,"Install")
    if not installs:raise RuntimeError("Install absent "+str(describe(ns)))
    button=min(installs,key=lambda n:abs(pos(n)[1]-y))
    if abs(pos(button)[1]-y)>110:raise RuntimeError("Fourier/Install separation too large "+str(describe(ns)))
    snap("01-fourier-choice");hit(button)
    start=time.monotonic();deadline=start+3600;last=0
    last_changed=start;last_progress=None;retried=False

    while time.monotonic()<deadline:
        ns=nodes()
        if one(ns,"Oruk Fourier 2B is ready",contains=True) is not None:break
        labels_here=[v for n in ns if n.get("package")==APP and shown(n) for v in labels(n)]
        if "Retry" in labels_here:
            print("Visible install failure:",labels_here,flush=True);snap("visible-install-error")
            transient=any(any(k in v.lower() for k in ("timed out","host lookup","network is unreachable","connection reset","503","502","504")) for v in labels_here)
            if transient and not retried:
                retried=True;hit(one(ns,"Retry"));last_changed=time.monotonic();continue
            raise RuntimeError("Visible onboarding error: "+str(labels_here))
        progress=next((v for v in labels_here if "MiB downloaded" in v),None)
        if progress!=last_progress:
            print("Fourier transfer:",progress,flush=True);last_progress=progress;last_changed=time.monotonic()
        if time.monotonic()-last_changed>420:
            snap("stalled-install");raise RuntimeError("No further published Fourier progress for seven minutes: "+str(labels_here))
        if time.monotonic()-last>25:
            last=time.monotonic();print("Installing original pack:",describe(ns)[:25],flush=True)
        time.sleep(2)
    else:raise RuntimeError("Model not ready: "+str(describe(ns)))
    snap("02-fourier-installed")
    tap("Continue")
    tap("Allow")
    allow=wait(lambda ns:next((n for n in ns if shown(n) and n.get("package","").endswith("permissioncontroller") and any(s.casefold()=="while using the app" for s in labels(n))),None))
    hit(allow);tap("Continue")
    tap("Continue")
    finish=wait(lambda ns:next(iter(find(ns,"Use without keyboard")+find(ns,"Finish setup")),None))
    hit(finish);wait(lambda ns:one(ns,"Start recording"))
    print("Ordinary launcher completed setup with the original Fourier model.",flush=True)
def record(path,words,tag):
    nav("Record");tap("Start recording");wait(lambda ns:one(ns,"Stop recording"));time.sleep(.6)
    result=subprocess.run([os.environ["QA_GRPC_PY"],".github/fourier-review/grpc-audio.py","--speech-padding",str(path)],text=True,capture_output=True)
    (OUT/(tag+"-grpc.txt")).write_text(result.stdout+result.stderr)
    result.check_returncode();print(result.stdout,flush=True)
    time.sleep(.4);tap("Stop recording")
    out=wait(lambda ns:transcript(ns,words),300);nav("History");history=wait(lambda ns:transcript(ns,words))
    if history!=out:raise RuntimeError(f"{out!r} differed from {history!r}")
    snap(tag+"-history");print(tag,"recognized in History:",repr(history),flush=True);return history
def edit(expected,tag):
    shell("am","force-stop",EDITOR);shell("am","start","-n",EDITOR+"/.Editor")
    def field(ns):return next((n for n in ns if n.get("class")=="android.widget.EditText" and n.get("package")==EDITOR and shown(n)),None)
    initial=wait(field)
    if shell("settings","get","secure","default_input_method")!=APP+"/.LocalWhisperInputMethodService":
        hit(wait(lambda ns:one(ns,"Choose keyboard",pkg=EDITOR)))
        picker=wait(lambda ns:next((n for n in ns if shown(n) and n.get("package") in ("android","com.android.systemui","com.android.settings") and any(s=="Local Whisper Keyboard" for s in labels(n))),None))
        hit(picker)
        deadline=time.monotonic()+25
        while time.monotonic()<deadline:
            selected=shell("settings","get","secure","default_input_method")
            if selected==APP+"/.LocalWhisperInputMethodService":break
            time.sleep(.3)
        else:raise RuntimeError("System keyboard selector still reports "+selected)
        initial=wait(field)
    if one(nodes(),"Insert latest transcript") is None:
        hit(initial)
    button=wait(lambda ns:one(ns,"Insert latest transcript"))
    snap(tag+"-keyboard")
    native=api("POST",base+"/element",{"using":"-android uiautomator","value":'new UiSelector().packageName("'+APP+'").className("android.widget.Button").textMatches("(?i)Insert latest transcript")'})
    element=next(iter(native.values()))
    api("POST",base+"/element/"+element+"/click",{})
    time.sleep(.65)
    def read(ns):
        n=field(ns)
        if n is None:return None
        actual=n.get('text','')
        if not expected and (actual=='Independent editor' or n.get('showing-hint')=='true'):actual=''
        return actual if actual==expected else None
    actual=wait(read,14);print(tag,"independent field:",repr(actual),flush=True);snap(tag+"-readback")
def enable_keyboard():
    shell("am","start","-a","android.settings.INPUT_METHOD_SETTINGS")
    enable=wait(lambda ns:one(ns,"Local Whisper Keyboard",pkg="com.android.settings"))
    hit(enable)
    for _ in range(8):
        ns=nodes()
        confirmation=next((n for n in ns if shown(n) and n.get("package") in ("android","com.android.settings") and any(s.casefold() in ("ok","allow") for s in labels(n))),None)
        if confirmation is not None:hit(confirmation);continue
        if APP+"/.LocalWhisperInputMethodService" in shell("ime","list","-s"):break
        time.sleep(1)
    assert APP+"/.LocalWhisperInputMethodService" in shell("ime","list","-s"),"IME missing from the visibly enabled list"
    shell("input","keyevent","KEYCODE_BACK")

def main():
    enable_keyboard()
    edit("","00-empty")
    go()
    shell("cmd","connectivity","airplane-mode","enable");shell("svc","wifi","disable");shell("svc","data","disable");time.sleep(3)
    default=[l.strip() for l in shell("dumpsys","connectivity").splitlines() if "active default network" in l.lower()]
    assert shell("settings","get","global","airplane_mode_on")=="1" and any("none" in s.lower() for s in default),default
    print("Airplane=1",default,flush=True)
    first=record(Path(os.environ["RUNNER_TEMP"])/"blue.wav",["blue","table"],"03-blue")
    second=record(Path("src/flutter/local_whisper/test/fixtures/local_whisper_mock.wav"),["recorder","offline"],"04-offline")
    assert first!=second
    edit(second,"05-newest")
    app();nav("History");wait(lambda ns:transcript(ns,["recorder","offline"]))
    deletes=find(nodes(),"Delete transcript");assert deletes
    hit(min(deletes,key=lambda n:pos(n)[1]));tap("Delete")
    wait(lambda ns:transcript(ns,["blue","table"]) if transcript(ns,["recorder","offline"]) is None else None)
    edit(first,"06-delete")
    app();nav("History");tap("Clear history");tap("Clear");wait(lambda ns:one(ns,"No recordings yet"))
    edit("","07-clear")
    print("PASS two ordinary microphone recordings, offline Fourier, external keyboard, deletion, clear",flush=True)
try:main()
except Exception:
    snap("failure");print("IME",shell("settings","get","secure","default_input_method"),flush=True)
    print([s for s in shell("dumpsys","input_method").splitlines() if "mInputShown=" in s][:6],flush=True)
    raise
finally:
    try:api("DELETE",base)
    except Exception:pass
