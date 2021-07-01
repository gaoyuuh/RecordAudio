//
//  AVAudioRecorderManager.m
//  recordAudip
//
//  Created by gaoyu on 2021/6/9.
//

#import "AVAudioRecorderManager.h"
#import <AVFoundation/AVFoundation.h>

#define kDefaultSampleRate 8000.0
#define kDefaultChannels 1
#define kDefaultBitsPerChannel 16

@interface AVAudioRecorderManager ()

@property (nonatomic, strong) AVAudioRecorder *recorder;

@property (nonatomic, strong) NSMutableDictionary * dicRecorder;

@end

@implementation AVAudioRecorderManager

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
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    
    dic[AVSampleRateKey] = @(sampleRate > 0 ? sampleRate : kDefaultSampleRate);
    dic[AVNumberOfChannelsKey] = @(channels > 0 ? channels : kDefaultChannels);
    
    if (audioFormatType == AudioFormatMPEG4AAC) {
        dic[AVFormatIDKey] = @(kAudioFormatMPEG4AAC);
    } else {
        dic[AVFormatIDKey] = @(kAudioFormatLinearPCM);
        
        dic[AVLinearPCMBitDepthKey] = @(bitsPerChannel > 0 ? bitsPerChannel : kDefaultBitsPerChannel);
        dic[AVLinearPCMIsFloatKey] = @(NO);
        dic[AVLinearPCMIsNonInterleaved] = @(NO);
        dic[AVLinearPCMIsBigEndianKey] = @(NO);
    }
    
    self.dicRecorder = dic;
}

- (void)startRecord {
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    // 创建录音存储文件
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"audiorecord_%.0f.%@", [NSDate timeIntervalSinceReferenceDate] * 1000.0, @"caf"]];
    NSLog(@"----- %@", filePath);
    
    NSError *error;
    self.recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL URLWithString:filePath]
                                                settings:self.dicRecorder
                                                   error:&error];
    if (error) {
        NSLog(@"录音初始化失败: %@", error);
        return;
    }
    
    [self.recorder prepareToRecord];
    
    BOOL start = [self.recorder record];
    if (!start) {
        NSLog(@"开始录音失败");
    }
}

- (void)stopRecord {
    [self.recorder stop];
    
    NSLog(@"录音文件地址：%@", self.recorder.url.absoluteString);
}

- (BOOL)isRecording {
    return self.recorder.isRecording;
}

- (void)dealloc {
    [self.recorder stop];
}

@end
