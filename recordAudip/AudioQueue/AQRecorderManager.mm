//
//  AQRecorderManager.m
//  recordAudip
//
//  Created by gaoyu on 2021/6/7.
//

#import "AQRecorderManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <AVFoundation/AVFoundation.h>

#define kDefaultSampleRate 8000.0
#define kDefaultChannels 1
#define kDefaultBitsPerChannel 16

/// 自定义结构体
static const int kNumberBuffers = 3;
typedef struct AQRecorderState {
    AudioStreamBasicDescription  mDataFormat;
    AudioQueueRef                mQueue;
    AudioQueueBufferRef          mBuffers[kNumberBuffers];
    AudioFileID                  mAudioFile;
    UInt32                       bufferByteSize;
    SInt64                       mCurrentPacket;
    bool                         mIsRunning;
} AQRecorderState;

/// 处理回调函数
static void HandleInputBuffer (
    void                                 *aqData,
    AudioQueueRef                        inAQ,
    AudioQueueBufferRef                  inBuffer,
    const AudioTimeStamp                 *inStartTime,
    UInt32                               inNumPackets,
    const AudioStreamPacketDescription   *inPacketDesc
) {
    AQRecorderState *pAqData = (AQRecorderState *)aqData;
    
    if (inNumPackets == 0 && pAqData->mDataFormat.mBytesPerPacket != 0) {
        inNumPackets = inBuffer->mAudioDataByteSize / pAqData->mDataFormat.mBytesPerPacket;
    }
 
    OSStatus writeStatus = AudioFileWritePackets(pAqData->mAudioFile,
                                                 false,
                                                 inBuffer->mAudioDataByteSize,
                                                 inPacketDesc,
                                                 pAqData->mCurrentPacket,
                                                 &inNumPackets,
                                                 inBuffer->mAudioData);
    if (writeStatus == noErr) {
        pAqData->mCurrentPacket += inNumPackets;
    }
    
    if (pAqData->mIsRunning == false) {
        return;
    }
    
    AudioQueueEnqueueBuffer(pAqData->mQueue,
                            inBuffer,
                            0,
                            NULL);
}

/// 设置缓冲区大小
void DeriveBufferSize (AudioQueueRef audioQueue,
                       AudioStreamBasicDescription &ASBDescription,
                       Float64  seconds,
                       UInt32   *outBufferSize) {
    
    int packets, frames, bytes = 0;
    
    frames = (int)ceil(seconds * ASBDescription.mSampleRate);
    
    if (ASBDescription.mBytesPerFrame > 0)
        bytes = frames * ASBDescription.mBytesPerFrame;
    else {
        UInt32 maxPacketSize;
        if (ASBDescription.mBytesPerPacket > 0)
            maxPacketSize = ASBDescription.mBytesPerPacket;    // constant packet size
        else {
            UInt32 propertySize = sizeof(maxPacketSize);
            AudioQueueGetProperty(audioQueue,
                                  kAudioQueueProperty_MaximumOutputPacketSize,
                                  &maxPacketSize,
                                  &propertySize);
        }
        if (ASBDescription.mFramesPerPacket > 0)
            packets = frames / ASBDescription.mFramesPerPacket;
        else
            packets = frames;    // worst-case scenario: 1 frame in a packet
        if (packets == 0)        // sanity check
            packets = 1;
        bytes = packets * maxPacketSize;
    }
    
    *outBufferSize = bytes;
}

OSStatus SetMagicCookieForFile (
    AudioQueueRef inQueue,
    AudioFileID   inFile
) {
    OSStatus result = noErr;
    UInt32 cookieSize;
 
    if (
            AudioQueueGetPropertySize (
                inQueue,
                kAudioQueueProperty_MagicCookie,
                &cookieSize
            ) == noErr
    ) {
        char* magicCookie =
            (char *) malloc (cookieSize);
        if (
                AudioQueueGetProperty (
                    inQueue,
                    kAudioQueueProperty_MagicCookie,
                    magicCookie,
                    &cookieSize
                ) == noErr
        )
            result =    AudioFileSetProperty (
                            inFile,
                            kAudioFilePropertyMagicCookieData,
                            cookieSize,
                            magicCookie
                        );
        free (magicCookie);
    }
    return result;
}


@interface AQRecorderManager () {
    AQRecorderState aqData;
}

@end

@implementation AQRecorderManager

- (instancetype)initAudioFormatType:(AudioFormatType)audioFormatType sampleRate:(Float64)sampleRate channels:(UInt32)channels bitsPerChannel:(UInt32)bitsPerChannel {
    self = [super init];
    if (self) {
        [self initRecord];
        
        [self setAudioFormatType:audioFormatType
                      sampleRate:sampleRate
                        channels:channels
                  bitsPerChannel:bitsPerChannel];
    }
    return self;
}

- (void)initRecord {
    
}

- (void)setAudioFormatType:(AudioFormatType)audioFormatType
                sampleRate:(Float64)sampleRate
                  channels:(UInt32)channels
            bitsPerChannel:(UInt32)bitsPerChannel {
    aqData.mDataFormat.mSampleRate = sampleRate > 0 ? sampleRate : kDefaultSampleRate;
    aqData.mDataFormat.mChannelsPerFrame = channels > 0 ? channels : kDefaultChannels;
    
    if (audioFormatType == AudioFormatLinearPCM) {
        
        aqData.mDataFormat.mFormatID = kAudioFormatLinearPCM;
        aqData.mDataFormat.mBitsPerChannel = bitsPerChannel > 0 ? bitsPerChannel : kDefaultBitsPerChannel;
        aqData.mDataFormat.mBytesPerPacket =
        aqData.mDataFormat.mBytesPerFrame = (aqData.mDataFormat.mBitsPerChannel / 8) * aqData.mDataFormat.mChannelsPerFrame;
        aqData.mDataFormat.mFramesPerPacket = 1;
        aqData.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        
    } else if (audioFormatType == AudioFormatMPEG4AAC) {
        
        aqData.mDataFormat.mFormatID = kAudioFormatMPEG4AAC;
        aqData.mDataFormat.mFormatFlags = kMPEG4Object_AAC_Main;
        
    }
}

- (void)startRecord {
    aqData.mCurrentPacket = 0;
    aqData.mIsRunning = true;
    
    // 创建音频队列
    OSStatus queueStatus = AudioQueueNewInput(&aqData.mDataFormat,
                       HandleInputBuffer,
                       &aqData,
                       NULL,
                       kCFRunLoopCommonModes,
                       0,
                       &aqData.mQueue);
    if (queueStatus != noErr) {
        NSLog(@"创建音频队列失败: %d", queueStatus);
        return;
    }
    
    UInt32 dataFormatSize = sizeof(aqData.mDataFormat);
    AudioQueueGetProperty(aqData.mQueue,
                          kAudioQueueProperty_StreamDescription,
                          &aqData.mDataFormat,
                          &dataFormatSize);
    
    // 创建录音存储文件
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%.0f.%@", [NSDate timeIntervalSinceReferenceDate] * 1000.0, @"caf"]];
    NSLog(@"----- %@", filePath);
    CFURLRef audioFileURL = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)filePath, NULL);
    OSStatus fileStatus = AudioFileCreateWithURL(audioFileURL,
                                                 kAudioFileCAFType,
                                                 &aqData.mDataFormat,
                                                 kAudioFileFlags_EraseFile,
                                                 &aqData.mAudioFile);
    CFRelease(audioFileURL);
    if (fileStatus != noErr) {
        NSLog(@"创建文件失败：%d", fileStatus);
        return;
    }
    
    // 设置magic cookie
    if (aqData.mDataFormat.mFormatID != kAudioFormatLinearPCM) {
        SetMagicCookieForFile(aqData.mQueue, aqData.mAudioFile);
    }
    
    // 设置缓冲区大小
    DeriveBufferSize(aqData.mQueue,
                     aqData.mDataFormat,
                     0.5,
                     &aqData.bufferByteSize);
        
    // 创建音频队列缓冲区
    for (int i = 0; i < kNumberBuffers; ++i) {
        OSStatus allocBufferStatus = AudioQueueAllocateBuffer(aqData.mQueue,
                                                              aqData.bufferByteSize,
                                                              &aqData.mBuffers[i]);
        if (allocBufferStatus != noErr) {
            NSLog(@"分配缓冲区失败：%d", allocBufferStatus);
            return;
        }
        
        OSStatus enqueueStatus = AudioQueueEnqueueBuffer(aqData.mQueue,
                                                         aqData.mBuffers[i],
                                                         0,
                                                         NULL);
        if (enqueueStatus != noErr) {
            NSLog(@"缓冲区排队失败：%d", enqueueStatus);
            return;
        }
    }
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    // 开始录音
    OSStatus startStatus = AudioQueueStart(aqData.mQueue, NULL);
    if (startStatus != noErr) {
        NSLog(@"开始录音失败：%d", startStatus);
        return;
    }
}

- (void)stopRecord {
    aqData.mIsRunning = false;
    AudioQueueStop(aqData.mQueue, true);
    
    // 录音结束后再次调用magic cookies，一些编码器会在录音停止后更新magic cookies数据
    if (aqData.mDataFormat.mFormatID != kAudioFormatLinearPCM) {
        SetMagicCookieForFile(aqData.mQueue, aqData.mAudioFile);
    }
    
    AudioQueueDispose(aqData.mQueue, true);
    AudioFileClose(aqData.mAudioFile);
}

- (void)dealloc {
    NSLog(@"--- dealloc ---");
    AudioQueueStop(aqData.mQueue, true);
    AudioQueueDispose(aqData.mQueue, true);
    AudioFileClose(aqData.mAudioFile);
}

- (BOOL)isRecording {
    return aqData.mIsRunning ? YES : NO;
}

@end
