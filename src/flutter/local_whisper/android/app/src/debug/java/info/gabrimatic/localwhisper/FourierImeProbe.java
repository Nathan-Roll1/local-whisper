package info.gabrimatic.localwhisper;
import android.content.*;
import android.util.Log;
import android.view.View;
import android.view.inspector.WindowInspector;
import android.widget.Button;
import java.util.ArrayList;
// Debug-build fixture for privileged adb only. The production IME is unchanged.
public class FourierImeProbe extends BroadcastReceiver {
    @Override public void onReceive(Context ctx, Intent intent) {
        String phase=intent.getStringExtra("phase");
        for (View root:WindowInspector.getGlobalWindowViews()) {
            ArrayList<View> matches=new ArrayList<>();
            root.findViewsWithText(matches,"Insert latest transcript", View.FIND_VIEWS_WITH_TEXT);
            for (View view:matches) {
                if (!(view instanceof Button) || !view.isShown()) continue;
                boolean probe="probe".equals(intent.getStringExtra("mode"));
                String result=probe?"visible":view.performClick()?"clicked":"unhandled";
                setResultData(result);
                Log.i("FourierPhysical","nativeButton phase="+phase+" result="+result+" pid="+android.os.Process.myPid());
                return;
            }
        }
        setResultData("hidden");
    }
}
