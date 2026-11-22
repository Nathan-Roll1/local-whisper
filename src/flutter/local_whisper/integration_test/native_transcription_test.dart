import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:local_whisper_flutter/src/models.dart';
import 'package:local_whisper_flutter/src/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_whisper_flutter/main.dart' as app;
import 'package:local_whisper_flutter/src/history_store.dart';
import 'package:local_whisper_flutter/src/model_store.dart';
import 'package:local_whisper_flutter/src/native_speech_service.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('selected native engine transcribes bundled speech audio', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    const explicitModel = String.fromEnvironment('LOCAL_WHISPER_E2E_MODEL');
    final model = explicitModel.isNotEmpty
        ? explicitModel
        : Platform.isAndroid
        ? 'parakeet_tdt_v3_sherpa'
        : 'whisperkit_large_v3_turbo';
    final service = NativeSpeechService();
    var modelPath = '';
    if (model == 'apple_speech') {
      final status = await service.appleSpeechModelStatus(locale: 'en-US');
      if (!status.available) {
        expect(status.installed, isFalse);
        return;
      }
      final installed = await service.installAppleSpeechModel(locale: 'en-US');
      expect(installed.installed, isTrue);
    } else {
      modelPath = await _resolveModelPath(model);
      if (const bool.fromEnvironment('LOCAL_WHISPER_E2E_DOWNLOAD_MODEL') &&
          !Directory(modelPath).existsSync()) {
        final store = ModelStore(
          HistoryStore(),
          modelDirectory: Directory(modelPath).parent,
        );
        final selected = (await store.loadModels()).firstWhere(
          (item) => item.id == model,
        );
        final first = ModelDownloadCancelToken();
        await expectLater(store.downloadModel(selected, onProgress: (p) {
          if (p.installedBytes > 33 * 1024 * 1024) first.cancel();
        }, cancelToken: first), throwsA(isA<ModelDownloadCanceledException>()));
        final root = Directory(modelPath).parent;
        final partialFiles = await root.list(recursive: true).where((f) =>
          f is File && f.path.contains('.resume/')).cast<File>().toList();
        final retained = partialFiles.fold<int>(0, (n,f) => n + f.lengthSync());
        expect(retained, greaterThan(32 * 1024 * 1024));
        final fresh = ModelStore(HistoryStore(), modelDirectory: root);
        await fresh.loadModels();
        print('FourierPhysical interrupted retainedBytes=$retained cachedFiles=${partialFiles.length}');
        await fresh.downloadModel(selected, onProgress: (_) {},
          cancelToken: ModelDownloadCancelToken());
        print('FourierPhysical retryInstalled disk_file_count=${Directory(modelPath).listSync(recursive:true).whereType<File>().length}');
      }
      await _waitForModelFolder(modelPath);
    }

    final filesDir = await getApplicationSupportDirectory();
    await File('${filesDir.path}/fourier-download-ready').writeAsString('download complete');
    final marker = File('${filesDir.path}/fourier-network-checked');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (!await marker.exists() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    final installed = (await ModelStore(HistoryStore(),
      modelDirectory: Directory(modelPath).parent).loadModels()).firstWhere((m) => m.id == model);
    expect(installed.state, ModelInstallState.installed);
    print('FourierPhysical cached model selected bytes=${installed.installedBytes} files=${installed.installedFiles} pid=$pid');
    final audioPath = await _copyFixtureToTemporaryFile();
    final result = await service.transcribeFileForTesting(
      audioPath: audioPath,
      locale: 'en-US',
      model: model,
      modelPath: modelPath,
    );

    print('FourierPhysical onDevice=${result.onDevice} model=${result.modelId} transcript=${result.transcript}');
    expect(result.onDevice, isTrue);
    expect(result.modelId, model);
    expect(result.transcript, 'Local Whisper Test Audio. The recorder works offline.');
    final status = File('/proc/self/status').readAsLinesSync()
      .where((l) => l.startsWith('VmHWM:') || l.startsWith('VmRSS:')).join(' ');
    print('FourierPhysical post_decode_memory $status');
    final hs = HistoryStore();
    await hs.saveOnboardingComplete(true);
    await hs.saveHistory([TranscriptEntry.create(rawText: result.transcript,
        finalText: result.transcript, modeName: 'Clean', localeId: 'en-US', duration: 3)]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const LocalWhisperApp());
    for (var i = 0; i < 30 && find.byType(NavigationBar).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final historyTab = find.descendant(of: find.byType(NavigationBar),matching:find.text('History'));
    await tester.tap(historyTab);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Copy').first);
    await tester.pumpAndSettle();
    final clip = await Clipboard.getData('text/plain');
    expect(clip?.text,result.transcript);
    print('FourierPhysical historyCopyButton=passed clipboard=${clip?.text}');
  }, timeout: const Timeout(Duration(minutes: 34)));
}

Future<String> _resolveModelPath(String model) async {
  const explicitPath = String.fromEnvironment('LOCAL_WHISPER_MODEL_PATH');
  if (explicitPath.isNotEmpty) return explicitPath;

  final documents = await getApplicationDocumentsDirectory();
  return '${documents.path}/models/$model';
}

Future<void> _waitForModelFolder(String modelPath) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (DateTime.now().isBefore(deadline)) {
    if (Directory(modelPath).existsSync()) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('Install the selected model before native E2E runs: $modelPath');
}

Future<String> _copyFixtureToTemporaryFile() async {
  final bytes = await rootBundle.load('test/fixtures/local_whisper_mock.wav');
  final file = File(
    '${Directory.systemTemp.path}/local_whisper_mock_${DateTime.now().microsecondsSinceEpoch}.wav',
  );
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  return file.path;
}
