"""Inject signed 16-bit mono PCM from WAV through the emulator's bundled gRPC service."""
import argparse
from pathlib import Path
import wave
import grpc
from google.protobuf import empty_pb2
import emulator_controller_pb2 as pb
import emulator_controller_pb2_grpc as rpc

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("wav",type=Path)
    parser.add_argument("--speech-padding",action="store_true",help="Include 0.25 s initial and 1.5 s final microphone silence")
    opts=parser.parse_args()
    with grpc.insecure_channel("127.0.0.1:8554") as channel, wave.open(str(opts.wav),"rb") as clip:
        stub=rpc.EmulatorControllerStub(channel)
        assert (clip.getnchannels(),clip.getsampwidth())==(1,2)
        rate=clip.getframerate()
        if hasattr(stub,"getMicrophoneState"):
            mic=stub.getMicrophoneState(empty_pb2.Empty(),timeout=5)
            print("gRPC host microphone enabled:",mic.realAudioEnabled,flush=True)
        fmt=pb.AudioFormat(samplingRate=rate,channels=pb.AudioFormat.Mono,format=pb.AudioFormat.AUD_FMT_S16)
        def packets():
            silence=bytes(rate//50*2)
            if opts.speech_padding:
                for _ in range(13):yield pb.AudioPacket(format=fmt,audio=silence)
            while True:
                pcm=clip.readframes(rate//50)
                if not pcm:break
                yield pb.AudioPacket(format=fmt,audio=pcm)
            if opts.speech_padding:
                for _ in range(75):yield pb.AudioPacket(format=fmt,audio=silence)
        stub.injectAudio(packets(),timeout=35)
        print("injectAudio returned OK:",clip.getnframes(),"samples at",rate,"Hz",flush=True)
if __name__=="__main__": main()
