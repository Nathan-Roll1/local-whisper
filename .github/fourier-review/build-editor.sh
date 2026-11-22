set -eu
root="$RUNNER_TEMP/editor"; mkdir -p "$root/classes" "$root/dex"; cd "$root"
sdk=$(find "$ANDROID_HOME/platforms" -name android.jar | sort -V | tail -1)
bt=$(find "$ANDROID_HOME/build-tools" -name aapt2 | sort -V | tail -1 | xargs dirname)
cat > AndroidManifest.xml <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="org.oruk.fourierrevieweditor"><uses-sdk android:minSdkVersion="26" android:targetSdkVersion="34"/><application android:label="Review Editor" android:theme="@android:style/Theme.Material.Light.NoActionBar"><activity android:name=".Editor" android:exported="true" android:windowSoftInputMode="stateAlwaysVisible|adjustResize"><intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter></activity></application></manifest>
XML
cat > Editor.java <<'JAVA'
package org.oruk.fourierrevieweditor;
import android.app.Activity;
import android.os.Bundle;
import android.view.WindowInsets;
import android.widget.EditText;
public class Editor extends Activity {
  private EditText field;
  protected void onCreate(Bundle state) {
    super.onCreate(state);
    field = new EditText(this);
    field.setSingleLine(false);
    field.setHint("Independent editor");
    field.setGravity(android.view.Gravity.TOP);
    setContentView(field);
    field.requestFocus();
  }
  @Override public void onWindowFocusChanged(boolean focused) {
    super.onWindowFocusChanged(focused);
    if (focused && field!=null) field.postDelayed(() -> {
      if (field.getWindowInsetsController()!=null) field.getWindowInsetsController().show(WindowInsets.Type.ime());
    }, 250);
  }
}
JAVA
javac -source 8 -target 8 -classpath "$sdk" -d classes Editor.java
"$bt/d8" --lib "$sdk" --min-api 26 --output dex classes/org/oruk/fourierrevieweditor/Editor.class
"$bt/aapt2" link -I "$sdk" --manifest AndroidManifest.xml -o unsigned.apk
(cd dex && zip -q ../unsigned.apk classes.dex)
"$bt/zipalign" -f 4 unsigned.apk aligned.apk
"$bt/apksigner" sign --ks "$HOME/.android/debug.keystore" --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out editor.apk aligned.apk
