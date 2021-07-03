//
//  AudioUnitManager.h
//  recordAudip
//
//  Created by gaoyu on 2021/7/1.
//

#import <Foundation/Foundation.h>

@interface AudioUnitManager : NSObject

@property (nonatomic, assign) BOOL  hasMute;

- (BOOL)isRuning;

- (void)startRecord;

- (void)stopRecord;

@end

