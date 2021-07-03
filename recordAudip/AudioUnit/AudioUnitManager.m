//
//  AudioUnitManager.m
//  recordAudip
//
//  Created by gaoyu on 2021/7/1.
//

#import "AudioUnitManager.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>

#define CHECK_ERROR(error, desc) \
if (error != noErr) { \
    char formatID[5]; \
    *(UInt32 *)formatID = CFSwapInt32HostToBig(error); \
    formatID[4] = '\0'; \
    fprintf(stderr, "'%s'! %d '%-4.4s'\n", desc, error, formatID); \
}

struct AudioUnitState {
    AudioUnit   ioUnit;
    BOOL *      muteAudio;
    BOOL        running;
    
    AudioStreamBasicDescription mDataFormat;
    ExtAudioFileRef extFileId;
} audioUnitState;

// Render callback function
static OSStatus performRender (void                         *inRefCon,
                               AudioUnitRenderActionFlags   *ioActionFlags,
                               const AudioTimeStamp         *inTimeStamp,
                               UInt32                        inBusNumber,
                               UInt32                        inNumberFrames,
                               AudioBufferList              *ioData)
{
    OSStatus err = noErr;
    
    // we are calling AudioUnitRender on the input bus of AURemoteIO
    // this will store the audio data captured by the microphone in ioData
    err = AudioUnitRender(audioUnitState.ioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
    
    // mute audio if needed
    if (*audioUnitState.muteAudio) {
        for (UInt32 i = 0; i < ioData->mNumberBuffers; ++i) {
            memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
        }
    }
    
    // 写文件
    CHECK_ERROR(ExtAudioFileWriteAsync(audioUnitState.extFileId, inNumberFrames, ioData), "写文件失败");
    
    return err;
}

@interface AudioUnitManager () {
    BOOL _mute;
}

@end

@implementation AudioUnitManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _mute = NO;
        [self setAudioSession];
        [self setIOUint];
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

/// 设置 AudioUnit
- (void)setIOUint {
    
    // 音频单元描述
    AudioComponentDescription ioUnitDescription;
    ioUnitDescription.componentType = kAudioUnitType_Output;
    ioUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    ioUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioUnitDescription.componentFlags = 0;
    ioUnitDescription.componentFlagsMask = 0;
    
    // 根据音频单元描述查找到音频单元引用
    AudioComponent foundIoUnitReference = AudioComponentFindNext(NULL, &ioUnitDescription);

    // 实例化 AudioUnit
    AudioUnit ioUnitInstance;
    CHECK_ERROR(AudioComponentInstanceNew(foundIoUnitReference, &ioUnitInstance), "初始化失败");
    
    // 配置 AudioUnit 开启输入模块，输出默认开启
    UInt32 enableInput = 1;
    CHECK_ERROR(AudioUnitSetProperty(ioUnitInstance,
                                     kAudioOutputUnitProperty_EnableIO,
                                     kAudioUnitScope_Input,
                                     1,
                                     &enableInput,
                                     sizeof(enableInput)), "开启输入失败");
    
    // 设置format
    AudioStreamBasicDescription mDataFormat = {0};
    mDataFormat.mSampleRate = 44100;
    mDataFormat.mChannelsPerFrame = 2;
    mDataFormat.mFormatID = kAudioFormatLinearPCM;
    mDataFormat.mBitsPerChannel = 16;
    mDataFormat.mBytesPerPacket =
    mDataFormat.mBytesPerFrame = (mDataFormat.mBitsPerChannel / 8) * mDataFormat.mChannelsPerFrame;
    mDataFormat.mFramesPerPacket = 1;
    mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    audioUnitState.mDataFormat = mDataFormat;
        
    CHECK_ERROR(AudioUnitSetProperty(ioUnitInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &mDataFormat, sizeof(mDataFormat)), "设置input格式失败");
    CHECK_ERROR(AudioUnitSetProperty(ioUnitInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mDataFormat, sizeof(mDataFormat)), "设置output格式失败");
    
    // 设置回调函数
    AURenderCallbackStruct renderCallback;
    renderCallback.inputProc = performRender;
    renderCallback.inputProcRefCon = NULL;
    CHECK_ERROR(AudioUnitSetProperty(ioUnitInstance, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderCallback, sizeof(renderCallback)), "设置回调函数失败");
    
    audioUnitState.ioUnit = ioUnitInstance;
    audioUnitState.muteAudio = &_mute;
    
    CHECK_ERROR(AudioUnitInitialize(ioUnitInstance), "初始化失败");
}

/// 创建录音存储文件
- (void)createAudioFile {
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"audioUnit_%.0f.%@", [NSDate timeIntervalSinceReferenceDate] * 1000.0, @"caf"]];
    NSLog(@"----- %@", filePath);
    CFURLRef audioFileURL = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)filePath, NULL);

    // 创建文件
    AudioStreamBasicDescription mDataFormat = {0};
    mDataFormat.mSampleRate = 44100;
    mDataFormat.mChannelsPerFrame = 2;
    mDataFormat.mFormatID = kAudioFormatMPEG4AAC;
    mDataFormat.mFormatFlags = kMPEG4Object_AAC_Main;
    
    CHECK_ERROR(ExtAudioFileCreateWithURL(audioFileURL, kAudioFileCAFType, &mDataFormat, NULL, kAudioFileFlags_EraseFile, &audioUnitState.extFileId), "文件创建失败");

    // 设置音频数据 输入格式
    UInt32 propSize = sizeof(AudioStreamBasicDescription);
    ExtAudioFileSetProperty(audioUnitState.extFileId, kExtAudioFileProperty_ClientDataFormat, propSize, &audioUnitState.mDataFormat);
}

- (BOOL)isRuning {
    return audioUnitState.running;
}

- (void)startRecord {
    [self createAudioFile];

    OSStatus status = AudioOutputUnitStart(audioUnitState.ioUnit);
    if (status != 0) {
        NSLog(@"开始失败");
        return;
    }
    audioUnitState.running = YES;
}

- (void)stopRecord {
    ExtAudioFileDispose(audioUnitState.extFileId);
    OSStatus status = AudioOutputUnitStop(audioUnitState.ioUnit);
    if (status != 0) {
        NSLog(@"停止失败");
        return;
    }
    audioUnitState.running = NO;
}

- (void)setHasMute:(BOOL)hasMute {
    _hasMute = hasMute;
    _mute = _hasMute;
}

- (void)dealloc {
    NSLog(@"-----dealloc-----");
    AudioOutputUnitStop(audioUnitState.ioUnit);
    AudioUnitUninitialize(audioUnitState.ioUnit);
    AudioComponentInstanceDispose(audioUnitState.ioUnit);
    ExtAudioFileDispose(audioUnitState.extFileId);
}

@end
