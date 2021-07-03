/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Demonstrates converting audio using AudioConverterFillComplexBuffer.
 */

@import Foundation;
@import AudioToolbox;

@protocol AudioFileConvertOperationDelegate;

@interface AudioFileConvertOperation : NSOperation

- (instancetype)initWithSourceURL:(NSURL *)sourceURL destinationURL:(NSURL *)destinationURL sampleRate:(Float64)sampleRate outputFormat:(AudioFormatID)outputFormat;

@property (readonly, nonatomic, strong) NSURL *sourceURL;

@property (readonly, nonatomic, strong) NSURL *destinationURL;

@property (readonly, nonatomic, assign) Float64 sampleRate;

@property (readonly, nonatomic, assign) AudioFormatID outputFormat;

@property (nonatomic, weak) id<AudioFileConvertOperationDelegate> delegate;

@end

@protocol AudioFileConvertOperationDelegate <NSObject>

- (void)audioFileConvertOperation:(AudioFileConvertOperation *)audioFileConvertOperation didEncounterError:(NSError *)error;

- (void)audioFileConvertOperation:(AudioFileConvertOperation *)audioFileConvertOperation didCompleteWithURL:(NSURL *)destinationURL;

@end
