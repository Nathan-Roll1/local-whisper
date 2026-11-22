package info.gabrimatic.localwhisper;
import android.content.*;
import android.widget.EditText;
public class FourierFieldReadback extends BroadcastReceiver {
    @Override public void onReceive(Context ctx,Intent intent) {
        EditText field=FourierExternalEditor.field;
        setResultData(field==null?"missing external editor":field.getText().toString());
    }
}
