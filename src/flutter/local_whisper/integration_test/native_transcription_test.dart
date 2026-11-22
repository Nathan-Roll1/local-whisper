import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_whisper_flutter/main.dart' as app;
import 'package:local_whisper_flutter/src/history_store.dart';
import 'package:local_whisper_flutter/src/models.dart';
import 'package:local_whisper_flutter/src/model_store.dart';
import 'package:local_whisper_flutter/src/native_speech_service.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('uses the same on-device transcript history as the keyboard', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    final history = HistoryStore();
    final support = await getApplicationSupportDirectory();
    final command = File('${support.path}/test-command');
    if (await command.exists()) {
      final phase = (await command.readAsString()).trim();
      if (phase == 'delete') {
        final entries = await history.loadHistory();
        expect(entries.length, 2);
        await history.deleteHistoryEntry(entries.first.id);
      } else if (phase == 'clear') {
        await history.clearHistory();
      } else {
        fail('Unknown host command: $phase');
      }
      print('FourierPhysical app history=$phase count=${(await history.loadHistory()).length}');
      return;
    }
    const model = 'oruk_fourier_2b_sherpa';
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/models');
    final store = ModelStore(history,modelDirectory:root);
    final m = (await store.loadModels()).firstWhere((m) => m.id == model);
    final result = await store.downloadModel(m,onProgress:(_){},cancelToken:ModelDownloadCancelToken());
    final cached = result.firstWhere((item) => item.id == model);
    expect(cached.state,ModelInstallState.installed);
    await File('${support.path}/fourier-download-ready').writeAsString('ready');
    final mark = File('${support.path}/fourier-network-checked');
    for (int i=0; i<120 && !await mark.exists(); i++) {
      await Future<void>.delayed(const Duration(seconds:1));
    }
    final source = File('${Directory.systemTemp.path}/ime-fixture.wav');
    final audio = await rootBundle.load('test/fixtures/local_whisper_mock.wav');
    await source.writeAsBytes(audio.buffer.asUint8List(), flush:true);
    final decoded = await NativeSpeechService().transcribeFileForTesting(
      audioPath:source.path,locale:'en-US',model:model,modelPath:cached.localPath!);
    expect(decoded.onDevice,true);
    expect(decoded.transcript,'Local Whisper Test Audio. The recorder works offline.');
    TranscriptEntry entry(String text)=>TranscriptEntry.create(rawText:text,finalText:text,modeName:'Clean',localeId:'en-US',duration:3);
    final older = entry('Previous transcript.');
    await Future<void>.delayed(const Duration(milliseconds:2));
    await history.saveHistory([entry(decoded.transcript),older]);
    print('FourierPhysical persisted original model output=${decoded.transcript}');
  },timeout:const Timeout(Duration(minutes:32)));
}
