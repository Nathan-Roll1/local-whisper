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
    TranscriptEntry entry(String text)=>TranscriptEntry.create(rawText:text,finalText:text,modeName:'Clean',localeId:'en-US',duration:3);
    Future<void> mark(String name)=>File('${support.path}/$name').writeAsString('ready').then((_) {});
    Future<void> waitFor(String name) async {
      final deadline=DateTime.now().add(const Duration(minutes:3));
      final file=File('${support.path}/$name');
      while (!await file.exists() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds:200));
      }
      expect(await file.exists(),true,reason:'host marker $name');
    }
    await history.saveHistory([entry('Keyboard preflight.')]);
    await mark('ime-seeded');
    await waitFor('ime-seed-checked');
    await history.clearHistory();
    expect((await history.loadHistory()).length,0);
    await mark('ime-empty-before-model');
    await waitFor('ime-start-model');
    const model = 'oruk_fourier_2b_sherpa';
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/models');
    final store = ModelStore(history,modelDirectory:root);
    final m = (await store.loadModels()).firstWhere((m) => m.id == model);
    final interrupted = ModelDownloadCancelToken();
    await expectLater(store.downloadModel(m,onProgress:(p){
      if (p.installedBytes > 33 * 1024 * 1024) interrupted.cancel();
    },cancelToken:interrupted), throwsA(isA<ModelDownloadCanceledException>()));
    final partials = root.listSync(recursive:true).whereType<File>().where((f)=>f.path.contains('.resume/'));
    print('FourierPhysical direct test cached bytes=${partials.fold<int>(0,(n,f)=>n+f.lengthSync())}');
    final fresh = ModelStore(history,modelDirectory:root);
    final result = await fresh.downloadModel(m,onProgress:(_){},cancelToken:ModelDownloadCancelToken());
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
    final older = entry('Previous transcript.');
    await Future<void>.delayed(const Duration(milliseconds:2));
    await history.saveHistory([entry(decoded.transcript),older]);
    print('FourierPhysical real persisted original model output=${decoded.transcript} pid=$pid');
    await mark('ime-real-ready');
    await waitFor('ime-delete');
    await history.deleteHistoryEntry((await history.loadHistory()).first.id);
    expect((await history.loadHistory()).single.finalText,'Previous transcript.');
    await mark('ime-deleted');
    await waitFor('ime-clear');
    await history.clearHistory();
    expect((await history.loadHistory()).isEmpty,true);
    await mark('ime-cleared');
    await waitFor('ime-finished');
  },timeout:const Timeout(Duration(minutes:32)));
}
