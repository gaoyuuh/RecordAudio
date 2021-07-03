/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Demonstrates converting audio using ExtAudioFile.
 */

#import "ExtendedAudioFileConvertOperation.h"
@import Darwin;
@import AVFoundation;

#pragma mark- Convert
// our own error code when we cannot continue from an interruption
enum {
    kMyAudioConverterErr_CannotResumeFromInterruptionError = 'CANT'
};

typedef NS_ENUM(NSInteger, AudioConverterState) {
    AudioConverterStateInitial,
    AudioConverterStateRunning,
    AudioConverterStatePaused,
    AudioConverterStateDone
};

@interface ExtendedAudioFileConvertOperation ()

// MARK: Properties

@property (nonatomic, strong) dispatch_queue_t queue;

@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@property (nonatomic, assign) AudioConverterState state;

@end

@implementation ExtendedAudioFileConvertOperation

// MARK: Initialization

- (instancetype)initWithSourceURL:(NSURL *)sourceURL destinationURL:(NSURL *)destinationURL sampleRate:(Float64)sampleRate outputFormat:(AudioFormatID)outputFormat {
    
    if ((self = [super init])) {
        _sourceURL = sourceURL;
        _destinationURL = destinationURL;
        _sampleRate = sampleRate;
        _outputFormat = outputFormat;
        _state = AudioConverterStateInitial;
        
        _queue = dispatch_queue_create("com.example.apple-samplecode.ExtendedAudioFileConvertTest.ExtendedAudioFileConvertOperation.queue", DISPATCH_QUEUE_CONCURRENT);
        _semaphore = dispatch_semaphore_create(0);
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruptionNotification:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
}

- (void)main {
    [super main];
    
    // This should never run on the main thread.
    assert(![NSThread isMainThread]);
    
    // Set the state to running.
    __weak __typeof__(self) weakSelf = self;
    
    dispatch_sync(self.queue, ^{
        weakSelf.state = AudioConverterStateRunning;
    });
    
    // Get the source files.
    ExtAudioFileRef sourceFile = 0;
    
    if (![self checkError:ExtAudioFileOpenURL((__bridge CFURLRef _Nonnull)(self.sourceURL), &sourceFile) withErrorString:[NSString stringWithFormat:@"ExtAudioFileOpenURL failed for sourceFile with URL: %@", self.sourceURL]]) {
        return;
    }
    
    // Get the source data format.
    AudioStreamBasicDescription sourceFormat = {};
    UInt32 size = sizeof(sourceFormat);
    
    if (![self checkError:ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileDataFormat, &size, &sourceFormat) withErrorString:@"ExtAudioFileGetProperty couldn't get the source data format"]) {
        return;
    }
    
    // Setup the output file format.
    AudioStreamBasicDescription destinationFormat = {};
    destinationFormat.mSampleRate = (self.sampleRate == 0 ? sourceFormat.mSampleRate : self.sampleRate);
    
    if (self.outputFormat == kAudioFormatLinearPCM) {
        // If the output format is PCM, create a 16-bit file format description.
        destinationFormat.mFormatID = self.outputFormat;
        destinationFormat.mChannelsPerFrame = sourceFormat.mChannelsPerFrame;
        destinationFormat.mBitsPerChannel = 16;
        destinationFormat.mBytesPerPacket = destinationFormat.mBytesPerFrame = 2 * destinationFormat.mChannelsPerFrame;
        destinationFormat.mFramesPerPacket = 1;
        destinationFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger; // little-endian
    } else {
        // This is a compressed format, need to set at least format, sample rate and channel fields for kAudioFormatProperty_FormatInfo.
        destinationFormat.mFormatID = self.outputFormat;
        
        // For iLBC, the number of channels must be 1.
        destinationFormat.mChannelsPerFrame = (self.outputFormat == kAudioFormatiLBC ? 1 : sourceFormat.mChannelsPerFrame);
        
        // Use AudioFormat API to fill out the rest of the description.
        size = sizeof(destinationFormat);
        if (![self checkError:AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &destinationFormat) withErrorString:@"AudioFormatGetProperty couldn't fill out the destination data format"]) {
            return;
        }
    }
    
    printf("Source file format:\n");
    [ExtendedAudioFileConvertOperation printAudioStreamBasicDescription:sourceFormat];
    printf("Destination file format:\n");
    [ExtendedAudioFileConvertOperation printAudioStreamBasicDescription:destinationFormat];
    
    // Create the destination audio file.
    ExtAudioFileRef destinationFile = 0;
    if (![self checkError:ExtAudioFileCreateWithURL((__bridge CFURLRef _Nonnull)(self.destinationURL), kAudioFileCAFType, &destinationFormat, NULL, kAudioFileFlags_EraseFile, &destinationFile) withErrorString:@"ExtAudioFileCreateWithURL failed!"]) {
        return;
    }
    
    /*
     set the client format - The format must be linear PCM (kAudioFormatLinearPCM)
     You must set this in order to encode or decode a non-PCM file data format
     You may set this on PCM files to specify the data format used in your calls to read/write
     */
    AudioStreamBasicDescription clientFormat;
    if (self.outputFormat == kAudioFormatLinearPCM) {
        clientFormat = destinationFormat;
    } else {
        
        clientFormat.mFormatID = kAudioFormatLinearPCM;
        UInt32 sampleSize = sizeof(SInt32);
        clientFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        clientFormat.mBitsPerChannel = 8 * sampleSize;
        clientFormat.mChannelsPerFrame = sourceFormat.mChannelsPerFrame;
        clientFormat.mFramesPerPacket = 1;
        clientFormat.mBytesPerPacket = clientFormat.mBytesPerFrame = sourceFormat.mChannelsPerFrame * sampleSize;
        clientFormat.mSampleRate = sourceFormat.mSampleRate;
    }
    
    printf("Client file format:\n");
    [ExtendedAudioFileConvertOperation printAudioStreamBasicDescription:clientFormat];
    
    size = sizeof(clientFormat);
    if (![self checkError:ExtAudioFileSetProperty(sourceFile, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat) withErrorString:@"Couldn't set the client format on the source file!"]) {
        return;
    }
    
    size = sizeof(clientFormat);
    if (![self checkError:ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat) withErrorString:@"Couldn't set the client format on the destination file!"]) {
        return;
    }
    
    // Get the audio converter.
    AudioConverterRef converter = 0;
    
    size = sizeof(converter);
    if (![self checkError:ExtAudioFileGetProperty(destinationFile, kExtAudioFileProperty_AudioConverter, &size, &converter) withErrorString:@"Failed to get the Audio Converter from the destination file."]) {
        return;
    }
    
    /*
     Can the Audio Converter resume after an interruption?
     this property may be queried at any time after construction of the Audio Converter (which in this case is owned by an ExtAudioFile object) after setting its output format
     there's no clear reason to prefer construction time, interruption time, or potential resumption time but we prefer
     construction time since it means less code to execute during or after interruption time.
     */
    BOOL canResumeFromInterruption = YES;
    UInt32 canResume = 0;
    size = sizeof(canResume);
    OSStatus error = AudioConverterGetProperty(converter, kAudioConverterPropertyCanResumeFromInterruption, &size, &canResume);
    
    if (error == noErr) {
        /*
         we recieved a valid return value from the GetProperty call
         if the property's value is 1, then the codec CAN resume work following an interruption
         if the property's value is 0, then interruptions destroy the codec's state and we're done
         */
        
        if (canResume == 0) {
            canResumeFromInterruption = NO;
        }
        
        printf("Audio Converter %s continue after interruption!\n", (!canResumeFromInterruption ? "CANNOT" : "CAN"));
        
    } else {
        /*
         if the property is unimplemented (kAudioConverterErr_PropertyNotSupported, or paramErr returned in the case of PCM),
         then the codec being used is not a hardware codec so we're not concerned about codec state
         we are always going to be able to resume conversion after an interruption
         */
        
        if (error == kAudioConverterErr_PropertyNotSupported) {
            printf("kAudioConverterPropertyCanResumeFromInterruption property not supported - see comments in source for more info.\n");
            
        } else {
            printf("AudioConverterGetProperty kAudioConverterPropertyCanResumeFromInterruption result %d, paramErr is OK if PCM\n", (int)error);
        }
        
        error = noErr;
    }
    
    // Setup buffers
    UInt32 bufferByteSize = 32768;
    char sourceBuffer[bufferByteSize];
    
    /*
     keep track of the source file offset so we know where to reset the source for
     reading if interrupted and input was not consumed by the audio converter
     */
    SInt64 sourceFrameOffset = 0;
    
    // Do the read and write - the conversion is done on and by the write call.
    printf("Converting...\n");
    while (YES) {
        // Set up output buffer list.
        AudioBufferList fillBufferList = {};
        fillBufferList.mNumberBuffers = 1;
        fillBufferList.mBuffers[0].mNumberChannels = clientFormat.mChannelsPerFrame;
        fillBufferList.mBuffers[0].mDataByteSize = bufferByteSize;
        fillBufferList.mBuffers[0].mData = sourceBuffer;
        
        /*
         The client format is always linear PCM - so here we determine how many frames of lpcm
         we can read/write given our buffer size
         */
        UInt32 numberOfFrames = 0;
        if (clientFormat.mBytesPerFrame > 0) {
            // Handles bogus analyzer divide by zero warning mBytesPerFrame can't be a 0 and is protected by an Assert.
            numberOfFrames = bufferByteSize / clientFormat.mBytesPerFrame;
        }
        
        if (![self checkError:ExtAudioFileRead(sourceFile, &numberOfFrames, &fillBufferList) withErrorString:@"ExtAudioFileRead failed!"]) {
            return;
        }
        
        if (!numberOfFrames) {
            // This is our termination condition.
            error = noErr;
            break;
        }
        
        sourceFrameOffset += numberOfFrames;
        
        BOOL wasInterrupted = [self checkIfPausedDueToInterruption];
        
        if ((error != noErr || wasInterrupted) && (!canResumeFromInterruption)) {
            // this is our interruption termination condition
            // an interruption has occured but the Audio Converter cannot continue
            error = kMyAudioConverterErr_CannotResumeFromInterruptionError;
            break;
        }
        
        error = ExtAudioFileWrite(destinationFile, numberOfFrames, &fillBufferList);
        // If we were interrupted in the process of the write call, we must handle the errors appropriately.
        if (error != noErr) {
            if (error == kExtAudioFileError_CodecUnavailableInputConsumed) {
                printf("ExtAudioFileWrite kExtAudioFileError_CodecUnavailableInputConsumed error %d\n", (int)error);
                
                /*
                 Returned when ExtAudioFileWrite was interrupted. You must stop calling
                 ExtAudioFileWrite. If the underlying audio converter can resume after an
                 interruption (see kAudioConverterPropertyCanResumeFromInterruption), you must
                 wait for an EndInterruption notification from AudioSession, then activate the session
                 before resuming. In this situation, the buffer you provided to ExtAudioFileWrite was successfully
                 consumed and you may proceed to the next buffer
                 */
            } else if (error == kExtAudioFileError_CodecUnavailableInputNotConsumed) {
                printf("ExtAudioFileWrite kExtAudioFileError_CodecUnavailableInputNotConsumed error %d\n", (int)error);
                
                /*
                 Returned when ExtAudioFileWrite was interrupted. You must stop calling
                 ExtAudioFileWrite. If the underlying audio converter can resume after an
                 interruption (see kAudioConverterPropertyCanResumeFromInterruption), you must
                 wait for an EndInterruption notification from AudioSession, then activate the session
                 before resuming. In this situation, the buffer you provided to ExtAudioFileWrite was not
                 successfully consumed and you must try to write it again
                 */
                
                // seek back to last offset before last read so we can try again after the interruption
                sourceFrameOffset -= numberOfFrames;
                if (![self checkError:ExtAudioFileSeek(sourceFile, sourceFrameOffset) withErrorString:@"ExtAudioFileSeek failed!"]) {
                    return;
                }
            } else {
                [self checkError:error withErrorString:@"ExtAudioFileWrite failed!"];
                return;
            }
        }
    }
    
    // Cleanup
    if (destinationFile) { ExtAudioFileDispose(destinationFile); }
    if (sourceFile) { ExtAudioFileDispose(sourceFile); }
    if (converter) { AudioConverterDispose(converter); }
    
    // Set the state to done.
    dispatch_sync(self.queue, ^{
        weakSelf.state = AudioConverterStateDone;
    });
    
    if (error == noErr) {
        if ([self.delegate respondsToSelector:@selector(audioFileConvertOperation:didCompleteWithURL:)]) {
            [self.delegate audioFileConvertOperation:self didCompleteWithURL:self.destinationURL];
        }
    }
}

- (BOOL)checkError:(OSStatus)error withErrorString:(NSString *)string {
    if (error == noErr) {
        return YES;
    }
    
    if ([self.delegate respondsToSelector:@selector(audioFileConvertOperation:didEncounterError:)]) {
        NSError *err = [NSError errorWithDomain:@"AudioFileConvertOperationErrorDomain" code:error userInfo:@{NSLocalizedDescriptionKey : string}];
        [self.delegate audioFileConvertOperation:self didEncounterError:err];
    }
    
    return NO;
}

- (BOOL)checkIfPausedDueToInterruption {
    __block BOOL wasInterrupted = NO;
    
    __weak __typeof__(self) weakSelf = self;
    
    dispatch_sync(self.queue, ^{
        assert(weakSelf.state != AudioConverterStateDone);
        
        while (weakSelf.state == AudioConverterStatePaused) {
            dispatch_semaphore_wait(weakSelf.semaphore, DISPATCH_TIME_FOREVER);
            
            wasInterrupted = YES;
        }
    });
    
    // We must be running or something bad has happened.
    assert(self.state == AudioConverterStateRunning);
    
    return wasInterrupted;
}

// MARK: Notification Handlers.

- (void)handleAudioSessionInterruptionNotification:(NSNotification *)notification {
    AVAudioSessionInterruptionType interruptionType = [notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    
    printf("Session interrupted > --- %s ---\n", interruptionType == AVAudioSessionInterruptionTypeBegan ? "Begin Interruption" : "End Interruption");
    
    __weak __typeof__(self) weakSelf = self;
    
    if (interruptionType == AVAudioSessionInterruptionTypeBegan) {
        dispatch_sync(self.queue, ^{
            if (weakSelf.state == AudioConverterStateRunning) {
                weakSelf.state = AudioConverterStatePaused;
            }
        });
    } else {
        
        NSError *error = nil;
        
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        
        if (error != nil) {
            NSLog(@"AVAudioSession setActive failed with error: %@", error.localizedDescription);
        }
        
        
        if (self.state == AudioConverterStatePaused) {
            dispatch_semaphore_signal(self.semaphore);
        }
        
        dispatch_sync(self.queue, ^{
            weakSelf.state = AudioConverterStateRunning;
        });
    }
}

+ (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd {
    char formatID[5];
    UInt32 mFormatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy (&mFormatID, formatID, 4);
    formatID[4] = '\0';
    printf("Sample Rate:         %10.0f\n",  asbd.mSampleRate);
    printf("Format ID:           %10s\n",    formatID);
    printf("Format Flags:        %10X\n",    (unsigned int)asbd.mFormatFlags);
    printf("Bytes per Packet:    %10d\n",    (unsigned int)asbd.mBytesPerPacket);
    printf("Frames per Packet:   %10d\n",    (unsigned int)asbd.mFramesPerPacket);
    printf("Bytes per Frame:     %10d\n",    (unsigned int)asbd.mBytesPerFrame);
    printf("Channels per Frame:  %10d\n",    (unsigned int)asbd.mChannelsPerFrame);
    printf("Bits per Channel:    %10d\n",    (unsigned int)asbd.mBitsPerChannel);
    printf("\n");
}

@end

