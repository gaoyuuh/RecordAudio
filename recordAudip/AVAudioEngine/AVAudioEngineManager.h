//
//  AVAudioEngineManager.h
//  recordAudip
//
//  Created by gaoyu on 2021/6/28.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface AVAudioEngineManager : NSObject

@property (nonatomic, assign) CGFloat   outPutVolumn;
@property (nonatomic, assign) CGFloat   inputVolumn;
@property (nonatomic, assign) CGFloat   playerVolumn;

/// 0-100
@property (nonatomic, assign) CGFloat   reverbWetDryMix;
/// 1/32 32
@property (nonatomic, assign) CGFloat   playRate;
/// -2400 2400
@property (nonatomic, assign) CGFloat   pitch;

- (BOOL)isRuning;

- (void)startRecord;

- (void)stopRecord;

@end

