import 'package:flutter_test/flutter_test.dart';
import 'package:local_whisper_flutter/src/sherpa_speech_service.dart';
void main(){
  for(final p in ['jfk.wav','phone-input.wav']){
    test('Fourier raw mobile output on $p',() async {
      final r = await SherpaSpeechService().transcribeFile(audioPath: '/tmp/$p',
        model:'oruk_fourier_2b_sherpa', modelPath:'/tmp/model/onnx/sherpa-int8',locale:'en-US',duration:11);
      print('FourierMarker fixture=$p actual=${r.transcript}');
      expect(r.transcript.toLowerCase(),contains('my fellow americans'));
      expect(r.transcript,isNot(contains('<asr_text>')));
    },timeout:const Timeout(Duration(minutes:3)));
  }
}
