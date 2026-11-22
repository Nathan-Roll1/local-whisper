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
import android.view.inspector.WindowInspector;
import android.widget.Button;
import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import static org.junit.Assert.*;
import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.concurrent.atomic.AtomicReference;

public class FourierImeTest {
    private UiAutomation ui;
    private Instrumentation ins;
    private String external, target;
    private String shell(String cmd) throws Exception {
        try(BufferedReader r=new BufferedReader(new InputStreamReader(new android.os.ParcelFileDescriptor.AutoCloseInputStream(ui.executeShellCommand(cmd))))) {
            StringBuilder b=new StringBuilder();String line;while((line=r.readLine())!=null)b.append(line).append('\n');return b.toString();
        }
    }
    private AccessibilityNodeInfo field(){
        for(AccessibilityWindowInfo w:ui.getWindows()){
            AccessibilityNodeInfo root=w.getRoot();
            if(root==null || !external.equals(String.valueOf(root.getPackageName())))continue;
            AccessibilityNodeInfo node=root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT);
            if(node!=null && "android.widget.EditText".equals(String.valueOf(node.getClassName())))return node;
        }
        return null;
    }
    private String readField() {
        AccessibilityNodeInfo f=field();return f==null?null:String.valueOf(f.getText());
    }
    private void waitField(String expected){
        long until=SystemClock.uptimeMillis()+15000;
        while(SystemClock.uptimeMillis()<until){
            if(expected.equals(readField()))return;
            SystemClock.sleep(180);
        }
        assertEquals("external field accessibility value",expected,readField());
    }
    private Button localButton(){
        AtomicReference<Button> b=new AtomicReference<>();
        ins.runOnMainSync(()->{
            for(View root:WindowInspector.getGlobalWindowViews()){
                ArrayList<View> matches=new ArrayList<>();
                root.findViewsWithText(matches,"Insert latest transcript",View.FIND_VIEWS_WITH_TEXT);
                for(View v:matches)if(v instanceof Button && v.isAttachedToWindow() && v.isShown() && target.equals(v.getContext().getPackageName())){
                    b.set((Button)v);return;
                }
            }
        });
        return b.get();
    }
    private AccessibilityNodeInfo externalButton(){
        for(AccessibilityWindowInfo w:ui.getWindows()){
            if(w.getType()!=AccessibilityWindowInfo.TYPE_INPUT_METHOD)continue;
            AccessibilityNodeInfo root=w.getRoot();if(root==null || !target.equals(String.valueOf(root.getPackageName())))continue;
            for(AccessibilityNodeInfo node:root.findAccessibilityNodeInfosByText("Insert latest transcript"))
                if(node.isVisibleToUser() && node.isClickable() && "Insert latest transcript".contentEquals(node.getText()))return node;
        }
        return null;
    }
    @Test public void clickAndObserveRealThirdPartyTextField() throws Exception {
        ins=InstrumentationRegistry.getInstrumentation();ui=ins.getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES);
        AccessibilityServiceInfo service=ui.getServiceInfo();service.flags|=AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS;ui.setServiceInfo(service);
        Context app=ins.getTargetContext();target=app.getPackageName();external=ins.getContext().getPackageName();
        String mode=InstrumentationRegistry.getArguments().getString("mode");
        String expected=mode.equals("clear")?"":new String(Files.readAllBytes(new File(app.getFilesDir(),"qa-"+(mode.equals("latest")?"newest":"previous")).toPath()),java.nio.charset.StandardCharsets.UTF_8);
        String ime=target+"/.LocalWhisperInputMethodService";
        String previous=InstrumentationRegistry.getArguments().getString("previousIme","");
        if(!previous.isEmpty() && !previous.equals(ime))shell("ime set "+previous);
        shell("settings put secure show_ime_with_hard_keyboard 1");
        app.startActivity(new Intent().setComponent(new ComponentName(external,"info.gabrimatic.localwhisper.FourierExternalEditor"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK));
        waitField("FIELD: ");
        shell("ime enable "+ime);shell("ime set "+ime);
        AccessibilityNodeInfo f=field();assertNotNull(f);f.performAction(AccessibilityNodeInfo.ACTION_CLICK);
        long until=SystemClock.uptimeMillis()+25000;
        boolean activated=false;String path="";String shown="";
        while(SystemClock.uptimeMillis()<until) {
            AccessibilityNodeInfo b=externalButton();
            if(b!=null && b.performAction(AccessibilityNodeInfo.ACTION_CLICK)){activated=true;path="UiAutomation input-method accessibility action";break;}
            Button actual=localButton();
            if(actual!=null){
                final boolean[] clicked={false};
                ins.runOnMainSync(()->{if(actual.isShown() && actual.isAttachedToWindow())clicked[0]=actual.performClick();});
                if(clicked[0]){activated=true;path="attached visible native button performClick";break;}
            }
            SystemClock.sleep(250);
        }
        for(AccessibilityWindowInfo w:ui.getWindows())shown+=w.getType()+"="+w.getTitle()+" ";
        android.util.Log.i("FourierPhysical","phase="+mode+" button="+path+" windows="+shown+" external-before-or-after="+readField());
        assertTrue("an attached real keyboard button handled the action; "+shown,activated);
        SystemClock.sleep(650);waitField("FIELD: "+expected);
        android.util.Log.i("FourierPhysical","phase="+mode+" independentEditor="+external+" actual=["+readField()+"] expected=["+("FIELD: "+expected)+"] click="+path);
    }
}
