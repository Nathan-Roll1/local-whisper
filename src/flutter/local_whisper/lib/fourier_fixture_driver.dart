// Device-lab-only entry point. No microphone capture. Keep model and history code unmodified.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'src/history_store.dart';
import 'src/model_store.dart';
import 'src/models.dart';
import 'src/native_speech_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Text('Fourier fixture check'))));
  final support = await getApplicationSupportDirectory();
  final command = File('${support.path}/qa-command');
  final action = (await command.readAsString()).trim();
  Future<void> write(String name, String text) => File('${support.path}/qa-$name').writeAsString(text, flush: true).then((_) {});
  final history = HistoryStore();
  try {
    if (action == 'decode') {
      if ((await history.loadHistory()).isNotEmpty) throw StateError('Expected clean history');
      const name = 'oruk_fourier_2b_sherpa';
      final root = Directory('${(await getApplicationDocumentsDirectory()).path}/models');
      final store = ModelStore(history,modelDirectory:root);
      final preset=(await store.loadModels()).firstWhere((m)=>m.id==name);
      final installed=(await store.downloadModel(preset,onProgress:(_){},cancelToken:ModelDownloadCancelToken())).firstWhere((m)=>m.id==name);
      if (installed.state!=ModelInstallState.installed) throw StateError('Incomplete install');
      await write('downloaded','ready');
      final gate=File('${support.path}/qa-airplane');
      for (int i=0; i<120 && !await gate.exists(); i++) {await Future<void>.delayed(const Duration(seconds:1));}
      if(!await gate.exists()) throw StateError('Airplane mode gate');
      final speech=NativeSpeechService();
      for (final file in ['jfk.wav','local_whisper_mock.wav']) {
        final audio=await rootBundle.load('test/fixtures/$file');
        final wave=File('${support.path}/$file');
        await wave.writeAsBytes(audio.buffer.asUint8List(),flush:true);
        final recognized=await speech.transcribeFileForTesting(audioPath:wave.path,locale:'en-US',model:name,modelPath:installed.localPath!);
        if (!recognized.onDevice || recognized.transcript.trim().isEmpty) throw StateError('Empty/off-host result');
        final text=recognized.transcript;
        final normalized=text.toLowerCase().replaceAll(RegExp('[^a-z ]'),'').trim();
        final ref=file=='jfk.wav'?'and so my fellow americans ask not what your country can do for you ask what you can do for your country':'local whisper test audio the recorder works offline';
        if (normalized!=ref) throw StateError('Unexpected decode of $file: $text');
        final newEntry=TranscriptEntry.create(rawText:text, finalText:text, modeName:'Clean',localeId:'en-US',duration:3);
        await history.saveHistory([newEntry,...await history.loadHistory()]);
        await write(file=='jfk.wav'?'previous':'newest',text);
        print('FourierPhysical decoded $file onDevice=${recognized.onDevice}: $text');
      }
    } else if (action=='delete') {
      final items=await history.loadHistory();
      if (items.length!=2) throw StateError('Expected two actual decoded items');
      await history.deleteHistoryEntry(items.first.id);
      if ((await history.loadHistory()).single.finalText != await File('${support.path}/qa-previous').readAsString()) throw StateError('Wrong surviving history item');
    } else if (action=='clear') {
      if ((await history.loadHistory()).length!=1) throw StateError('Expected one item before clear');
      await history.clearHistory();
      if ((await history.loadHistory()).isNotEmpty) throw StateError('Expected clear history');
    } else {throw StateError('Unknown action $action');}
    print('FourierPhysical app action=$action count=${(await history.loadHistory()).length}');
    await write('done-$action','ready');
  } catch(error, trace) {
    print('FourierPhysical error $error\n$trace');
    await write('error',error.toString());
  }
}
