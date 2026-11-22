package info.gabrimatic.localwhisper;

import android.accessibilityservice.AccessibilityServiceInfo;
import android.app.Instrumentation;
import android.app.UiAutomation;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.SystemClock;
import android.view.View;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityWindowInfo;
import androidx.test.platform.app.InstrumentationRegistry;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import static org.junit.Assert.*;
import org.junit.Test;

public class FourierImeTest {
    private UiAutomation ui;
    private Instrumentation instrument;
    private String external;
    private static final int TIMEOUT=20000;
    private String shell(String cmd) throws Exception {
        try(BufferedReader reader=new BufferedReader(new InputStreamReader(
                new android.os.ParcelFileDescriptor.AutoCloseInputStream(ui.executeShellCommand(cmd))))) {
            return reader.readLine();
        }
    }
    private String editorText(){
        for (AccessibilityWindowInfo win: ui.getWindows()) {
            AccessibilityNodeInfo root=win.getRoot();
            if(root==null || !external.contentEquals(root.getPackageName()==null?"":root.getPackageName()))continue;
            AccessibilityNodeInfo f=root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT);
            if(f!=null && "android.widget.EditText".contentEquals(f.getClassName()))return String.valueOf(f.getText());
        }
        AccessibilityNodeInfo root=ui.getRootInActiveWindow();
        if(root!=null && external.equals(String.valueOf(root.getPackageName()))) {
            AccessibilityNodeInfo f=root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT);
            if(f!=null)return String.valueOf(f.getText());
        }
        return "";
    }
    private void waitForText(String expected){
        long end=SystemClock.uptimeMillis()+TIMEOUT;
        while(SystemClock.uptimeMillis()<end){
            if(expected.equals(editorText()))return;
            SystemClock.sleep(150);
        }
        assertEquals(expected,editorText());
    }
    @Test public void tapsActualImeAgainstExternalField() throws Exception {
        instrument=InstrumentationRegistry.getInstrumentation();
        ui=instrument.getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES);
        AccessibilityServiceInfo config=ui.getServiceInfo();
        config.flags |= AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS;
        ui.setServiceInfo(config);
        Context app=instrument.getTargetContext();
        external=instrument.getContext().getPackageName();
        String mode=InstrumentationRegistry.getArguments().getString("mode", "latest");
        String expected=mode.equals("latest")?"Local Whisper Test Audio. The recorder works offline.":mode.equals("delete")?"Previous transcript.":"";
        String ime=app.getPackageName()+"/.LocalWhisperInputMethodService";
        shell("settings put secure show_ime_with_hard_keyboard 1");shell("ime enable "+ime);shell("ime set "+ime);
        app.startActivity(new Intent().setComponent(new ComponentName(external,"info.gabrimatic.localwhisper.FourierExternalEditor"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK));
        waitForText("UNCHANGED");
        android.graphics.Point point = new android.graphics.Point(-1,-1);
        long end=SystemClock.uptimeMillis()+TIMEOUT;
        while(SystemClock.uptimeMillis()<end && point.x<0) {
            instrument.runOnMainSync(()->{
                for(View root : android.view.inspector.WindowInspector.getGlobalWindowViews()){
                    ArrayList<View> matches=new ArrayList<>();
                    root.findViewsWithText(matches,"Insert latest transcript",View.FIND_VIEWS_WITH_TEXT);
                    for(View button:matches) if(button instanceof android.widget.Button && button.isShown()){
                        int[] position=new int[2]; button.getLocationOnScreen(position);
                        point.set(position[0]+button.getWidth()/2,position[1]+button.getHeight()/2);
                        return;
                    }
                }
            });
            SystemClock.sleep(150);
        }
        assertTrue("production keyboard button visible in an Android window",point.x>=0);
        shell("input tap "+point.x+" "+point.y);
        android.util.Log.i("FourierPhysical","real on-screen keyboard tap "+point);
        SystemClock.sleep(450);
        waitForText("UNCHANGED"+expected);
        android.util.Log.i("FourierPhysical","directIme mode="+mode+" externalPackage="+external+" exact="+editorText());
    }
}
