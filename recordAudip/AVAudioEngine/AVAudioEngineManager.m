//
//  AVAudioEngineManager.m
//  recordAudip
//
//  Created by gaoyu on 2021/6/28.
//

#import "AVAudioEngineManager.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>

@interface AVAudioEngineManager ()

@property (nonatomic, strong) AVAudioEngine * engine;

@property (nonatomic, strong) AVAudioInputNode * inputNode;
@property (nonatomic, strong) AVAudioMixerNode * mixerNode;
@property (nonatomic, strong) AVAudioPlayerNode * playerNode;
@property (nonatomic, strong) AVAudioUnitReverb * reverbNode;
@property (nonatomic, strong) AVAudioUnitTimePitch * effectNode;
@property (nonatomic, strong) AVAudioOutputNode * outputNode;

@end

@implementation AVAudioEngineManager

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setAudioSession];
        [self handleEngineAndNode];
    }
    return self;
}

/// 设置 AVAudioSession
- (void)setAudioSession {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    NSError *error;
    [session setPreferredSampleRate:44100 error:&error];
    
    // I/O buffer时长，在44100采样率下，采样1024个样本大约耗费时间为23ms（ 1024/44100 * 1000ms = 23ms ）
    // 若对延迟有要求，则可以主动设置更小的时间
    NSTimeInterval ioBufferDuration = 0.005;
    [session setPreferredIOBufferDuration:ioBufferDuration error:&error];
    
    [session setActive:YES error:&error];
    
    NSLog(@"session error: %@", error);
}

/// 创建engine、node、连接处理链
- (void)handleEngineAndNode {
    self.engine = [[AVAudioEngine alloc] init];

    // 输入node
    self.inputNode = self.engine.inputNode;
    // 输出node
    self.outputNode = self.engine.outputNode;
    // 混音node
    self.mixerNode = self.engine.mainMixerNode;
    
    // 播放node
    self.playerNode = [[AVAudioPlayerNode alloc] init];
    [self.engine attachNode:self.playerNode];
    
    // 混响node
    self.reverbNode = [[AVAudioUnitReverb alloc] init];
    self.reverbNode.wetDryMix = 0;
    [self.reverbNode loadFactoryPreset:AVAudioUnitReverbPresetLargeRoom];
    [self.engine attachNode:self.reverbNode];
    
    // 效果node，提供播放速率、以及音调偏移
    self.effectNode = [[AVAudioUnitTimePitch alloc] init];
    [self.engine attachNode:self.effectNode];

    // 播放文件
    NSURL *drumLoopURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"drumLoop" ofType:@"caf"]];
    AVAudioFile *drumLoopFile = [[AVAudioFile alloc] initForReading:drumLoopURL error:nil];
//    [self.playerNode scheduleFile:drumLoopFile atTime:nil completionHandler:nil];
    AVAudioPCMBuffer *playerLoopBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:[drumLoopFile processingFormat] frameCapacity:(AVAudioFrameCount)[drumLoopFile length]];
    [drumLoopFile readIntoBuffer:playerLoopBuffer error:nil];
    [self.playerNode scheduleBuffer:playerLoopBuffer atTime:nil options:AVAudioPlayerNodeBufferLoops completionHandler:nil];
    
    /*
                                     inputNode  ----->
                                                        mixerNode ---> outputNode
     playerNode ---> reverbNode ---> effectNode ----->
     */
    [self.engine connect:self.inputNode to:self.mixerNode fromBus:0 toBus:0 format:[self.inputNode inputFormatForBus:0]];
    
    [self.engine connect:self.playerNode to:self.reverbNode format:playerLoopBuffer.format];
    [self.engine connect:self.reverbNode to:self.effectNode format:playerLoopBuffer.format];
    [self.engine connect:self.effectNode to:self.mixerNode fromBus:0 toBus:1 format:playerLoopBuffer.format];
    
    [self.engine connect:self.mixerNode to:self.outputNode format:[self.inputNode inputFormatForBus:0]];
}

- (void)startRecord {
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"audioEngine_%.0f.%@", [NSDate timeIntervalSinceReferenceDate] * 1000.0, @"caf"]];
    NSLog(@"录音存储文件地址：%@", filePath);
    NSURL *fileUrl = [NSURL URLWithString:filePath];
    AVAudioFile *file = [[AVAudioFile alloc] initForWriting:fileUrl
                                                   settings:[self.inputNode inputFormatForBus:0].settings
                                                      error:nil];
    NSLog(@"---- %@", [self.inputNode inputFormatForBus:0]);
    [self.mixerNode installTapOnBus:0 bufferSize:4096 format:[self.inputNode inputFormatForBus:0] block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        [file writeFromBuffer:buffer error:nil];
    }];

    [self.engine prepare];
    NSError *error;
    [self.engine startAndReturnError:&error];
    if (error) {
        return;
    }
    [self.playerNode play];
}

- (void)stopRecord {
    [self.engine.mainMixerNode removeTapOnBus:0];
    [self.engine stop];
}

- (BOOL)isRuning {
    return self.engine.isRunning;
}


#pragma mark - 设置

- (void)setOutPutVolumn:(CGFloat)outPutVolumn {
    _outPutVolumn = outPutVolumn;
    self.mixerNode.outputVolume = outPutVolumn;
}

- (void)setPlayerVolumn:(CGFloat)playerVolumn {
    _playerVolumn = playerVolumn;
    self.playerNode.volume = playerVolumn;
}

- (void)setInputVolumn:(CGFloat)inputVolumn {
    _inputVolumn = inputVolumn;
    self.inputNode.volume = inputVolumn;
}

- (void)setPitch:(CGFloat)pitch {
    _pitch = pitch;
    self.effectNode.pitch = pitch;
}

- (void)setReverbWetDryMix:(CGFloat)reverbWetDryMix {
    _reverbWetDryMix = reverbWetDryMix;
    self.reverbNode.wetDryMix = reverbWetDryMix;
}

- (void)setPlayRate:(CGFloat)playRate {
    _playRate = playRate;
    self.effectNode.rate = playRate;
}

@end
