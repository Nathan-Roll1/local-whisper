set -euo pipefail
root="$RUNNER_TEMP/audio-probe"; mkdir -p "$root/classes" "$root/dex"; cd "$root"
sdk=$(find "$ANDROID_HOME/platforms" -name android.jar | sort -V | tail -1)
bt=$(find "$ANDROID_HOME/build-tools" -name aapt2 | sort -V | tail -1 | xargs dirname)
cat > AndroidManifest.xml <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="org.oruk.qa.audiorecord"><uses-sdk android:minSdkVersion="26" android:targetSdkVersion="34"/><uses-permission android:name="android.permission.RECORD_AUDIO"/><application android:debuggable="true" android:label="Microphone preflight"><activity android:name=".Probe" android:exported="true"/></application></manifest>
XML
cat > Probe.java <<'JAVA'
package org.oruk.qa.audiorecord;
import android.app.Activity;
import android.os.Bundle;
import android.media.*;
import android.util.Log;
import android.widget.Button;
import java.io.*;
public class Probe extends Activity {
  Button button;
  public void onCreate(Bundle b) {
    super.onCreate(b);
    button=new Button(this); button.setText("Start microphone capture"); setContentView(button);
    button.setOnClickListener(v -> {
      if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO)!=0)
        requestPermissions(new String[]{android.Manifest.permission.RECORD_AUDIO},1);
      else start();
    });
  }
  public void onRequestPermissionsResult(int n,String[] p,int[] g) {super.onRequestPermissionsResult(n,p,g);if(g.length>0 && g[0]==0)start();}
  void start() {
    button.setEnabled(false); button.setText("Recording");
    new Thread(() -> {
      AudioRecord mic=null;
      try(FileOutputStream out=openFileOutput("guest.pcm",MODE_PRIVATE)){
        int rate=16000;
        mic=new AudioRecord(MediaRecorder.AudioSource.MIC,rate,AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,Math.max(6400,AudioRecord.getMinBufferSize(rate,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT)));
        mic.startRecording();
        Log.i("FourierMic","READY recordingState="+mic.getRecordingState());
        byte[] block=new byte[640]; int sum=0;
        while(sum<rate*2*12) {int n=mic.read(block,0,block.length); if(n<=0)throw new IOException("read returned "+n); out.write(block,0,n); sum+=n;}
        Log.i("FourierMic","DONE bytes="+sum);
      }catch(Exception e){Log.e("FourierMic","CAPTURE_FAILED",e);}
      finally{if(mic!=null)mic.release();}
    }).start();
  }
}
JAVA
javac -source 8 -target 8 -classpath "$sdk" -d classes Probe.java
"$bt/d8" --lib "$sdk" --min-api 26 --output dex classes/org/oruk/qa/audiorecord/Probe.class
"$bt/aapt2" link -I "$sdk" --manifest AndroidManifest.xml -o unsigned.apk
(cd dex && zip -q ../unsigned.apk classes.dex)
"$bt/zipalign" -f 4 unsigned.apk aligned.apk
keytool -genkeypair -keystore qa.p12 -storepass android -keypass android -alias qa -dname CN=EmulatedAudioQA -keyalg RSA -keysize 2048 -validity 3
"$bt/apksigner" sign --ks qa.p12 --ks-key-alias qa --ks-pass pass:android --key-pass pass:android --out probe.apk aligned.apk
