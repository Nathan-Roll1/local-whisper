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
            while True:
                pcm=clip.readframes(rate//50)
                if not pcm:break
                yield pb.AudioPacket(format=fmt,audio=pcm)
        stub.injectAudio(packets(),timeout=35)
        print("injectAudio returned OK:",clip.getnframes(),"samples at",rate,"Hz",flush=True)
if __name__=="__main__": main()
