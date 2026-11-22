package info.gabrimatic.localwhisper;
import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.widget.*;
import android.text.*;
public class FourierExternalEditor extends Activity {
    static EditText field;
    @Override public void onWindowFocusChanged(boolean focused) {
        super.onWindowFocusChanged(focused);
        if(focused && field!=null) field.postDelayed(() -> {
            field.requestFocus();
            getSystemService(android.view.inputmethod.InputMethodManager.class)
                .showSoftInput(field,android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT);
        },250);
    }
    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        EditText editor = new EditText(this); field=editor;
        editor.setSingleLine(true);
        editor.setHint("External editable field");
        editor.setText("UNCHANGED"); editor.setSelection(editor.length());
        editor.addTextChangedListener(new TextWatcher(){
            public void beforeTextChanged(CharSequence s,int a,int c,int n){}
            public void onTextChanged(CharSequence s,int a,int b,int c){Log.i("FourierPhysical","externalText="+s);}
            public void afterTextChanged(Editable e){}
        });
        layout.addView(editor);
        Button paste = new Button(this);
        paste.setText("Paste dictation");
        paste.setAllCaps(false);
        paste.setOnClickListener(v -> {
            editor.requestFocus(); editor.selectAll();
            boolean did = editor.onTextContextMenuItem(android.R.id.paste);
            Log.i("FourierPhysical", "systemPaste="+did+" received="+editor.getText().toString());
        });
        layout.addView(paste);
        setContentView(layout);
        editor.requestFocus();
        editor.postDelayed(() -> getSystemService(android.view.inputmethod.InputMethodManager.class)
            .showSoftInput(editor, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT), 450);
    }
}
