/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Demonstrates converting audio using ExtAudioFile.
 */

#import <Foundation/Foundation.h>
@import AudioToolbox;

@protocol ExtendedAudioFileConvertOperationDelegate;

@interface ExtendedAudioFileConvertOperation : NSOperation

- (instancetype)initWithSourceURL:(NSURL *)sourceURL destinationURL:(NSURL *)destinationURL sampleRate:(Float64)sampleRate outputFormat:(AudioFormatID)outputFormat;

@property (readonly, nonatomic, strong) NSURL *sourceURL;

@property (readonly, nonatomic, strong) NSURL *destinationURL;

@property (readonly, nonatomic, assign) Float64 sampleRate;

@property (readonly, nonatomic, assign) AudioFormatID outputFormat;

@property (nonatomic, weak) id<ExtendedAudioFileConvertOperationDelegate> delegate;

@end

@protocol ExtendedAudioFileConvertOperationDelegate <NSObject>

- (void)audioFileConvertOperation:(ExtendedAudioFileConvertOperation *)audioFileConvertOperation didEncounterError:(NSError *)error;

- (void)audioFileConvertOperation:(ExtendedAudioFileConvertOperation *)audioFileConvertOperation didCompleteWithURL:(NSURL *)destinationURL;

@end
