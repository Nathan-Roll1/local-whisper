package info.gabrimatic.localwhisper;
import android.app.Activity;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.WindowInsets;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
public class FourierExternalEditor extends Activity {
    static EditText field;
    private final long deadline = SystemClock.uptimeMillis()+28000;
    private void requestVisible(){
        if (field==null || !hasWindowFocus() || SystemClock.uptimeMillis()>deadline) return;
        field.requestFocus();
        getSystemService(InputMethodManager.class).showSoftInput(field, InputMethodManager.SHOW_IMPLICIT);
        if (getWindow().getInsetsController()!=null) getWindow().getInsetsController().show(WindowInsets.Type.ime());
        if (!field.getRootWindowInsets().isVisible(WindowInsets.Type.ime())) field.postDelayed(this::requestVisible,400);
    }
    @Override protected void onCreate(Bundle b){
        super.onCreate(b);
        field=new EditText(this);field.setSingleLine(true);field.setHint("Independent editor");
        field.setText("FIELD: ");field.setSelection(field.length());setContentView(field);field.requestFocus();
    }
    @Override public void onWindowFocusChanged(boolean focused){
        super.onWindowFocusChanged(focused);if(focused && field!=null) field.post(this::requestVisible);
    }
}
