"""Click an ordinary Android accessibility label, including system permission prompts."""
import re,subprocess,sys,time
from xml.etree import ElementTree
label=sys.argv[1].casefold()
for attempt in range(20):
    subprocess.run(['adb','shell','uiautomator','dump','/sdcard/qa-control.xml'],capture_output=True)
    source=subprocess.run(['adb','exec-out','cat','/sdcard/qa-control.xml'],capture_output=True)
    try:nodes=list(ElementTree.fromstring(source.stdout).iter())
    except ElementTree.ParseError:continue
    for n in nodes:
        if label not in [n.get('text','').casefold(),n.get('content-desc','').casefold()]:continue
        x,y,a,b=map(int,re.findall(r'\d+',n.get('bounds','')))
        subprocess.run(['adb','shell','input','tap',str((x+a)//2),str((y+b)//2)],check=True)
        print('Tapped',label,n.get('package'),flush=True);sys.exit(0)
    time.sleep(.25)
raise RuntimeError('Control not found: '+label+'; visible: '+str([n.get('text') or n.get('content-desc') for n in nodes if n.get('text') or n.get('content-desc')]))
