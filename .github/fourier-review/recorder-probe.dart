import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MaterialApp(home: Probe()));
class Probe extends StatefulWidget {
  const Probe({super.key});
  @override State<Probe> createState()=>_ProbeState();
}
class _ProbeState extends State<Probe> {
  static const speech=MethodChannel('local_whisper/speech');
  String state='ready';
  Future<void> handle() async {
    try {
      if(state=='ready'){
        final allowed=await speech.invokeMethod<bool>('requestPermissions');
        if(allowed!=true) throw StateError('Android microphone permission declined');
        await speech.invokeMethod<void>('start',{'locale':'en-US'});
        setState(()=>state='recording');
        print('FOURIER_NATIVE_RECORDER RECORDING');
      }else if(state=='recording'){
        setState(()=>state='stopping');
        final watch=Stopwatch()..start();
        print('FOURIER_NATIVE_RECORDER STOP_REQUEST');
        final result=await speech.invokeMapMethod<String,dynamic>('stop');
        final ms=watch.elapsedMilliseconds;
        final file=File(result!['audioPath'] as String);
        final dir=await getExternalStorageDirectory();
        await file.copy('${dir!.path}/finalized-microphone.wav');
        print('FOURIER_NATIVE_RECORDER FINALIZED ms=$ms bytes=${await file.length()} reportedDuration=${result["duration"]} sampleRate=${result["sampleRate"]}');
        setState(()=>state='finished');
      }
    } catch(e){print('FOURIER_NATIVE_RECORDER ERROR $e');setState(()=>state='error');}
  }
  @override Widget build(BuildContext context)=>Scaffold(body:Center(child:ElevatedButton(
    onPressed:state=='ready'||state=='recording'?handle:null,
    child:Text({'ready':'Record probe','recording':'Stop probe'}[state]??state))));
}
