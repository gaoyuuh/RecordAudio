//
//  AQRecorderManager.h
//  recordAudip
//
//  Created by gaoyu on 2021/6/7.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, AudioFormatType) {
    AudioFormatLinearPCM,
    AudioFormatMPEG4AAC,
};

@interface AQRecorderManager : NSObject

@property (nonatomic, assign, readonly) BOOL isRecording;

/// 设置音频数据属性
/// @param audioFormatType 音频格式 AudioFormatType
/// @param sampleRate 采样率
/// @param channels 声道
/// @param bitsPerChannel 位深度
- (instancetype)initAudioFormatType:(AudioFormatType)audioFormatType
                         sampleRate:(Float64)sampleRate
                           channels:(UInt32)channels
                     bitsPerChannel:(UInt32)bitsPerChannel;

- (void)startRecord;

- (void)stopRecord;

@end
