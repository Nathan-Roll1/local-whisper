import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_whisper_flutter/src/sherpa_speech_service.dart';

void main() {
  final pack = Platform.environment['FOURIER_MODEL_DIR'];
  if (pack == null) return;
  test('Fourier returns the spoken text through the app service', timeout: const Timeout(Duration(minutes: 5)), () async {
    final file = await File('test/fixtures/local_whisper_mock.wav').copy('${Directory.systemTemp.path}/fourier_app.wav');
    final result = await SherpaSpeechService().transcribeFile(audioPath: file.path,model:'oruk_fourier_2b_sherpa',modelPath:pack,locale:'en-US',duration:1);
    print('Fourier through the app: ${result.transcript}');
    expect(result.onDevice, isTrue);
    expect(result.modelId, 'oruk_fourier_2b_sherpa');
    expect(result.transcript.toLowerCase(), anyOf(contains('local'),contains('whisper'),contains('offline')));
  });
}
