/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Demonstrates converting audio using AudioConverterFillComplexBuffer.
 */

#import "AudioFileConvertOperation.h"
@import Darwin;
@import AVFoundation;

// ***********************
#pragma mark- Converter
/* The main Audio Conversion function using AudioConverter */

enum {
    kMyAudioConverterErr_CannotResumeFromInterruptionError = 'CANT',
    eofErr = -39 // End of file
};

typedef struct {
    AudioFileID                  srcFileID;
    SInt64                       srcFilePos;
    char *                       srcBuffer;
    UInt32                       srcBufferSize;
    AudioStreamBasicDescription     srcFormat;
    UInt32                       srcSizePerPacket;
    UInt32                       numPacketsPerRead;
    AudioStreamPacketDescription *packetDescriptions;
} AudioFileIO, *AudioFileIOPtr;

#pragma mark-

// Input data proc callback
static OSStatus EncoderDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    AudioFileIOPtr afio = (AudioFileIOPtr)inUserData;
    OSStatus error;
    
    // figure out how much to read
    UInt32 maxPackets = afio->srcBufferSize / afio->srcSizePerPacket;
    if (*ioNumberDataPackets > maxPackets) *ioNumberDataPackets = maxPackets;
    
    // read from the file
    UInt32 outNumBytes = maxPackets * afio->srcSizePerPacket;
    
    error = AudioFileReadPacketData(afio->srcFileID, false, &outNumBytes, afio->packetDescriptions, afio->srcFilePos, ioNumberDataPackets, afio->srcBuffer);
    if (eofErr == error) error = noErr;
    if (error) { printf ("Input Proc Read error: %d (%4.4s)\n", (int)error, (char*)&error); return error; }
    
    //printf("Input Proc: Read %lu packets, at position %lld size %lu\n", *ioNumberDataPackets, afio->srcFilePos, outNumBytes);
    
    // advance input file packet position
    afio->srcFilePos += *ioNumberDataPackets;
    
    // put the data pointer into the buffer list
    ioData->mBuffers[0].mData = afio->srcBuffer;
    ioData->mBuffers[0].mDataByteSize = outNumBytes;
    ioData->mBuffers[0].mNumberChannels = afio->srcFormat.mChannelsPerFrame;
    
    // don't forget the packet descriptions if required
    if (outDataPacketDescription) {
        if (afio->packetDescriptions) {
            *outDataPacketDescription = afio->packetDescriptions;
        } else {
            *outDataPacketDescription = NULL;
        }
    }
    
    return error;
}

typedef NS_ENUM(NSInteger, AudioConverterState) {
    AudioConverterStateInitial,
    AudioConverterStateRunning,
    AudioConverterStatePaused,
    AudioConverterStateDone
};

@interface AudioFileConvertOperation ()

// MARK: Properties

@property (nonatomic, strong) dispatch_queue_t queue;

@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@property (nonatomic, assign) AudioConverterState state;

@end

@implementation AudioFileConvertOperation

// MARK: Initialization

- (instancetype)initWithSourceURL:(NSURL *)sourceURL destinationURL:(NSURL *)destinationURL sampleRate:(Float64)sampleRate outputFormat:(AudioFormatID)outputFormat {
    
    if ((self = [super init])) {
        _sourceURL = sourceURL;
        _destinationURL = destinationURL;
        _sampleRate = sampleRate;
        _outputFormat = outputFormat;
        _state = AudioConverterStateInitial;
        
        _queue = dispatch_queue_create("com.example.apple-samplecode.AudioConverterFileConvertTest.AudioFileConverOperation.queue", DISPATCH_QUEUE_CONCURRENT);
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
    
    AudioStreamPacketDescription *outputPacketDescriptions = NULL;
    
    // Set the state to running.
    __weak __typeof__(self) weakSelf = self;

    dispatch_sync(self.queue, ^{
        weakSelf.state = AudioConverterStateRunning;
    });
    
    // Get the source file.
    AudioFileID sourceFileID = 0;
    
    if (![self checkError:(AudioFileOpenURL((__bridge CFURLRef _Nonnull)self.sourceURL, kAudioFileReadPermission, 0, &sourceFileID)) withErrorString:[NSString stringWithFormat:@"AudioFileOpenURL failed for sourceFile with URL: %@", self.sourceURL]]) {
        return;
    }
    
    // Get the source data format.
    AudioStreamBasicDescription sourceFormat = {};
    UInt32 size = sizeof(sourceFormat);
    if (![self checkError:AudioFileGetProperty(sourceFileID, kAudioFilePropertyDataFormat, &size, &sourceFormat) withErrorString:@"AudioFileGetProperty couldn't get the source data format"]) {
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
    
    printf("Source File format:\n");
    [AudioFileConvertOperation printAudioStreamBasicDescription:sourceFormat];
    printf("Destination File format:\n");
    [AudioFileConvertOperation printAudioStreamBasicDescription:destinationFormat];
    
    // Create the AudioConverterRef.
    AudioConverterRef converter = NULL;
    if (![self checkError:AudioConverterNew(&sourceFormat, &destinationFormat, &converter) withErrorString:@"AudioConverterNew failed"]) {
        return;
    }
    
    // If the source file has a cookie, get ir and set it on the AudioConverterRef.
    [self readCookieFromAudioFile:sourceFileID converter:converter];
    
    // Get the actuall formats (source and destination) from the AudioConverterRef.
    size = sizeof(sourceFormat);
    if (![self checkError:AudioConverterGetProperty(converter, kAudioConverterCurrentInputStreamDescription, &size, &sourceFormat) withErrorString:@"AudioConverterGetProperty kAudioConverterCurrentInputStreamDescription failed!"]) {
        return;
    }
    
    size = sizeof(destinationFormat);
    if (![self checkError:AudioConverterGetProperty(converter, kAudioConverterCurrentOutputStreamDescription, &size, &destinationFormat) withErrorString:@"AudioConverterGetProperty kAudioConverterCurrentOutputStreamDescription failed!"]) {
        return;
    }
    
    printf("Formats returned from AudioConverter:\n");
    printf("Source File format:\n");
    [AudioFileConvertOperation printAudioStreamBasicDescription:sourceFormat];
    printf("Destination File format:\n");
    [AudioFileConvertOperation printAudioStreamBasicDescription:destinationFormat];
    
    /*
     If encoding to AAC set the bitrate kAudioConverterEncodeBitRate is a UInt32 value containing
     the number of bits per second to aim for when encoding data when you explicitly set the bit rate 
     and the sample rate, this tells the encoder to stick with both bit rate and sample rate
     but there are combinations (also depending on the number of channels) which will not be allowed
     if you do not explicitly set a bit rate the encoder will pick the correct value for you depending 
     on samplerate and number of channels bit rate also scales with the number of channels, 
     therefore one bit rate per sample rate can be used for mono cases and if you have stereo or more, 
     you can multiply that number by the number of channels.
     */
    
    if (destinationFormat.mFormatID == kAudioFormatMPEG4AAC) {
        UInt32 outputBitRate = 64000;
        
        UInt32 propSize = sizeof(outputBitRate);
        
        if (destinationFormat.mSampleRate >= 44100) {
            outputBitRate = 192000;
        } else if (destinationFormat.mSampleRate < 22000) {
            outputBitRate = 32000;
        }
        
        // Set the bit rate depending on the sample rate chosen.
        if (![self checkError:AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, propSize, &outputBitRate) withErrorString:@"AudioConverterSetProperty kAudioConverterEncodeBitRate failed!"]) {
            return;
        }
        
        // Get it back and print it out.
        AudioConverterGetProperty(converter, kAudioConverterEncodeBitRate, &propSize, &outputBitRate);
        printf ("AAC Encode Bitrate: %u\n", (unsigned int)outputBitRate);
    }
    
    /*
     Can the Audio Converter resume after an interruption?
     this property may be queried at any time after construction of the Audio Converter after setting its output format
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
    
    // Create the destination audio file.
    AudioFileID destinationFileID = 0;
    if (![self checkError:AudioFileCreateWithURL((__bridge CFURLRef _Nonnull)(self.destinationURL), kAudioFileCAFType, &destinationFormat, kAudioFileFlags_EraseFile, &destinationFileID) withErrorString:@"AudioFileCreateWithURL failed!"]) {
        return;
    }
    
    // Setup source buffers and data proc info struct.
    AudioFileIO afio = {};
    afio.srcFileID = sourceFileID;
    afio.srcBufferSize = 32768;
    afio.srcBuffer = malloc(afio.srcBufferSize * sizeof(char));
    afio.srcFilePos = 0;
    afio.srcFormat = sourceFormat;
    
    if (sourceFormat.mBytesPerPacket == 0) {
        /*
         if the source format is VBR, we need to get the maximum packet size
         use kAudioFilePropertyPacketSizeUpperBound which returns the theoretical maximum packet size
         in the file (without actually scanning the whole file to find the largest packet,
         as may happen with kAudioFilePropertyMaximumPacketSize)
         */
        size = sizeof(afio.srcSizePerPacket);
        if (![self checkError:AudioFileGetProperty(sourceFileID, kAudioFilePropertyPacketSizeUpperBound, &size, &afio.srcSizePerPacket) withErrorString:@"AudioFileGetProperty kAudioFilePropertyPacketSizeUpperBound failed!"]) {
            return;
        }
        
        // How many packets can we read for our buffer size?
        afio.numPacketsPerRead = afio.srcBufferSize / afio.srcSizePerPacket;
        
        // Allocate memory for the PacketDescription structs describing the layout of each packet.
        afio.packetDescriptions = malloc(afio.numPacketsPerRead * sizeof(AudioStreamPacketDescription));
    } else {
        // CBR source format
        afio.srcSizePerPacket = sourceFormat.mBytesPerPacket;
        afio.numPacketsPerRead = afio.srcBufferSize / afio.srcSizePerPacket;
        afio.packetDescriptions = NULL;
    }
    
    // Set up output buffers
    UInt32 outputSizePerPacket = destinationFormat.mBytesPerPacket;
    UInt32 theOutputBufferSize = 32768;
    char *outputBuffer = malloc(theOutputBufferSize * sizeof(char));
    
    if (outputSizePerPacket == 0) {
        // if the destination format is VBR, we need to get max size per packet from the converter
        size = sizeof(outputSizePerPacket);
        
        if (![self checkError:AudioConverterGetProperty(converter, kAudioConverterPropertyMaximumOutputPacketSize, &size, &outputSizePerPacket) withErrorString:@"AudioConverterGetProperty kAudioConverterPropertyMaximumOutputPacketSize failed!"]) {
            if (afio.srcBuffer) { free(afio.srcBuffer); }
            if (outputBuffer) { free(outputBuffer); }
            
            return;
        }
        
        // allocate memory for the PacketDescription structures describing the layout of each packet
        outputPacketDescriptions = calloc(theOutputBufferSize / outputSizePerPacket, sizeof(AudioStreamPacketDescription));//malloc((theOutputBufferSize / outputSizePerPacket) * sizeof(AudioStreamPacketDescription));
    }
    
    UInt32 numberOutputPackets = theOutputBufferSize / outputSizePerPacket;
    
    // If the destination format has a cookie, get it and set it on the output file.
    [self writeCookieForAudioFile:destinationFileID converter:converter];
    
    // Write destination channel layout.
    if (sourceFormat.mChannelsPerFrame > 2) {
        [self writeChannelLayoutWithConverter:converter sourceFile:sourceFileID destinationFile:destinationFileID];
    }
    
    // Used for debugging printf
    UInt64 totalOutputFrames = 0;
    SInt64 outputFilePosition = 0;
    
    // Loop to convert data.
    printf("Converting...\n");
    while (YES) {
        
        // Set up output buffer list.
        AudioBufferList fillBufferList = {};
        fillBufferList.mNumberBuffers = 1;
        fillBufferList.mBuffers[0].mNumberChannels = destinationFormat.mChannelsPerFrame;
        fillBufferList.mBuffers[0].mDataByteSize = theOutputBufferSize;
        fillBufferList.mBuffers[0].mData = outputBuffer;
        
        
        BOOL wasInterrupted = [self checkIfPausedDueToInterruption];
        
        if ((error != noErr || wasInterrupted) && (!canResumeFromInterruption)) {
            // this is our interruption termination condition
            // an interruption has occured but the Audio Converter cannot continue
            error = kMyAudioConverterErr_CannotResumeFromInterruptionError;
            break;
        }
        
        // Convert data
        UInt32 ioOutputDataPackets = numberOutputPackets;
        printf("AudioConverterFillComplexBuffer...\n");
        error = AudioConverterFillComplexBuffer(converter, EncoderDataProc, &afio, &ioOutputDataPackets, &fillBufferList, outputPacketDescriptions);
        
        // if interrupted in the process of the conversion call, we must handle the error appropriately
        if (error) {
            if (error == kAudioConverterErr_HardwareInUse) {
                printf("Audio Converter returned kAudioConverterErr_HardwareInUse!\n");
            } else {
                if (![self checkError:error withErrorString:@"AudioConverterFillComplexBuffer error!"]) {
                    return;
                }
            }
        } else {
            if (ioOutputDataPackets == 0) {
                // This is the EOF condition.
                error = noErr;
                break;
            }
        }
        
        if (error == noErr) {
            // Write to output file.
            UInt32 inNumBytes = fillBufferList.mBuffers[0].mDataByteSize;
            if (![self checkError:AudioFileWritePackets(destinationFileID, false, inNumBytes, outputPacketDescriptions, outputFilePosition, &ioOutputDataPackets, outputBuffer) withErrorString:@"AudioFileWritePackets failed!"]) {
                return;
            }

            printf("Convert Output: Write %u packets at position %lld, size: %u\n", (unsigned int)ioOutputDataPackets, outputFilePosition, (unsigned int)inNumBytes);
            
            // Advance output file packet position.
            outputFilePosition += ioOutputDataPackets;
            
            if (destinationFormat.mFramesPerPacket) {
                // The format has constant frames per packet.
                totalOutputFrames += (ioOutputDataPackets * destinationFormat.mFramesPerPacket);
            } else if (outputPacketDescriptions != NULL) {
                // variable frames per packet require doing this for each packet (adding up the number of sample frames of data in each packet)
                for (UInt32 i = 0; i < ioOutputDataPackets; ++i) {
                    totalOutputFrames += outputPacketDescriptions[i].mVariableFramesInPacket;
                }
            }
        }
    }
    
    
    if (![self checkError:error withErrorString:@"An Error Occured during the conversion!"]) {
        return;
    }
    
    // write out any of the leading and trailing frames for compressed formats only
    if (destinationFormat.mBitsPerChannel == 0) {
        // our output frame count should jive with
        printf("Total number of output frames counted: %lld\n", totalOutputFrames);
        [self writePacketTableInfoWithConverter:converter toDestination:destinationFileID];
    }
    
    [self writeCookieForAudioFile:destinationFileID converter:converter];
    
    // Cleanup
    if (converter) { AudioConverterDispose(converter); }
    if (destinationFileID) { AudioFileClose(destinationFileID); }
    if (sourceFileID) { AudioFileClose(sourceFileID); }
    if (afio.srcBuffer) { free(afio.srcBuffer); }
    if (afio.packetDescriptions) { free(afio.packetDescriptions); }
    if (outputBuffer) { free(outputBuffer); }
    if (outputPacketDescriptions) { free(outputPacketDescriptions); }
    
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

/*
 Some audio formats have a magic cookie associated with them which is required to decompress audio data
 When converting audio data you must check to see if the format of the data has a magic cookie
 If the audio data format has a magic cookie associated with it, you must add this information to anAudio Converter
 using AudioConverterSetProperty and kAudioConverterDecompressionMagicCookie to appropriately decompress the data
 http://developer.apple.com/mac/library/qa/qa2001/qa1318.html
 */
- (void)readCookieFromAudioFile:(AudioFileID)sourceFileID converter:(AudioConverterRef)converter {
    // Grab the cookie from the source file and set it on the converter.
    UInt32 cookieSize = 0;
    OSStatus error = AudioFileGetPropertyInfo(sourceFileID, kAudioFilePropertyMagicCookieData, &cookieSize, NULL);
    
    // If there is an error here, then the format doesn't have a cookie - this is perfectly fine as some formats do not.
    if (error == noErr && cookieSize != 0) {
        char *cookie = malloc(cookieSize * sizeof(char));
        
        error = AudioFileGetProperty(sourceFileID, kAudioFilePropertyMagicCookieData, &cookieSize, cookie);
        if (error == noErr) {
            error = AudioConverterSetProperty(converter, kAudioConverterDecompressionMagicCookie, cookieSize, cookie);
            
            if (error != noErr) {
                printf("Could not Set kAudioConverterDecompressionMagicCookie on the Audio Converter!\n");
            }
        } else {
            printf("Could not Get kAudioFilePropertyMagicCookieData from source file!\n");
        }
        
        free(cookie);
    }
}

/*
 Some audio formats have a magic cookie associated with them which is required to decompress audio data
 When converting audio, a magic cookie may be returned by the Audio Converter so that it may be stored along with
 the output data -- This is done so that it may then be passed back to the Audio Converter at a later time as required
 */
- (void)writeCookieForAudioFile:(AudioFileID)destinationFileID converter:(AudioConverterRef)converter {
    // Grab the cookie from the converter and write it to the destination file.
    UInt32 cookieSize = 0;
    OSStatus error = AudioConverterGetPropertyInfo(converter, kAudioConverterCompressionMagicCookie, &cookieSize, NULL);
    
    // If there is an error here, then the format doesn't have a cookie - this is perfectly fine as som formats do not.
    if (error == noErr && cookieSize != 0) {
        char *cookie = malloc(cookieSize * sizeof(char));
        
        error = AudioConverterGetProperty(converter, kAudioConverterCompressionMagicCookie, &cookieSize, cookie);
        if (error == noErr) {
            error = AudioFileSetProperty(destinationFileID, kAudioFilePropertyMagicCookieData, cookieSize, cookie);
            
            if (error == noErr) {
                printf("Writing magic cookie to destination file: %u\n", (unsigned int)cookieSize);
            } else {
                printf("Even though some formats have cookies, some files don't take them and that's OK\n");
            }
        } else {
            printf("Could not Get kAudioConverterCompressionMagicCookie from Audio Converter!\n");
        }
        
        free(cookie);
    }
}

/*
 Sets the packet table containing information about the number of valid frames in a file and where they begin and end
 for the file types that support this information.
 Calling this function makes sure we write out the priming and remainder details to the destination file
 */
- (void)writePacketTableInfoWithConverter:(AudioConverterRef)converter toDestination:(AudioFileID)destinationFileID {
    UInt32 isWritable;
    UInt32 dataSize;
    OSStatus error = AudioFileGetPropertyInfo(destinationFileID, kAudioFilePropertyPacketTableInfo, &dataSize, &isWritable);
    
    if (error == noErr && isWritable) {
        AudioConverterPrimeInfo primeInfo;
        dataSize = sizeof(primeInfo);
        
        // retrieve the leadingFrames and trailingFrames information from the converter,
        error = AudioConverterGetProperty(converter, kAudioConverterPrimeInfo, &dataSize, &primeInfo);
        if (error == noErr) {
            /* we have some priming information to write out to the destination file
             The total number of packets in the file times the frames per packet (or counting each packet's
             frames individually for a variable frames per packet format) minus mPrimingFrames, minus
             mRemainderFrames, should equal mNumberValidFrames.
             */
            
            AudioFilePacketTableInfo pti;
            dataSize = sizeof(pti);
            error = AudioFileGetProperty(destinationFileID, kAudioFilePropertyPacketTableInfo, &dataSize, &pti);
            if (noErr == error) {
                // there's priming to write out to the file
                UInt64 totalFrames = pti.mNumberValidFrames + pti.mPrimingFrames + pti.mRemainderFrames; // get the total number of frames from the output file
                printf("Total number of frames from output file: %lld\n", totalFrames);
                
                pti.mPrimingFrames = primeInfo.leadingFrames;
                pti.mRemainderFrames = primeInfo.trailingFrames;
                pti.mNumberValidFrames = totalFrames - pti.mPrimingFrames - pti.mRemainderFrames;
                
                error = AudioFileSetProperty(destinationFileID, kAudioFilePropertyPacketTableInfo, sizeof(pti), &pti);
                if (noErr == error) {
                    printf("Writing packet table information to destination file: %ld\n", sizeof(pti));
                    printf("     Total valid frames: %lld\n", pti.mNumberValidFrames);
                    printf("         Priming frames: %d\n", (int)pti.mPrimingFrames);
                    printf("       Remainder frames: %d\n\n", (int)pti.mRemainderFrames);
                } else {
                    printf("Some audio files can't contain packet table information and that's OK\n");
                }
            } else {
                printf("Getting kAudioFilePropertyPacketTableInfo error: %d\n", (int)error);
            }
        } else {
            printf("No kAudioConverterPrimeInfo available and that's OK\n");
        }
    } else {
        printf("GetPropertyInfo for kAudioFilePropertyPacketTableInfo error: %d, isWritable: %u\n", (int)error, (unsigned int)isWritable);
    }
}

- (void)writeChannelLayoutWithConverter:(AudioConverterRef)converter sourceFile:(AudioFileID)sourceFileID destinationFile:(AudioFileID)destinationFileID {
    UInt32 layoutSize = 0;
    bool layoutFromConverter = true;
    
    OSStatus error = AudioConverterGetPropertyInfo(converter, kAudioConverterOutputChannelLayout, &layoutSize, NULL);
    
    // if the Audio Converter doesn't have a layout see if the input file does
    if (error || 0 == layoutSize) {
        error = AudioFileGetPropertyInfo(sourceFileID, kAudioFilePropertyChannelLayout, &layoutSize, NULL);
        layoutFromConverter = false;
    }
    
    if (noErr == error && 0 != layoutSize) {
        char* layout = malloc(layoutSize * sizeof(char));
        
        if (layoutFromConverter) {
            error = AudioConverterGetProperty(converter, kAudioConverterOutputChannelLayout, &layoutSize, layout);
            if (error) printf("Could not Get kAudioConverterOutputChannelLayout from Audio Converter!\n");
        } else {
            error = AudioFileGetProperty(sourceFileID, kAudioFilePropertyChannelLayout, &layoutSize, layout);
            if (error) printf("Could not Get kAudioFilePropertyChannelLayout from source file!\n");
        }
        
        if (noErr == error) {
            error = AudioFileSetProperty(destinationFileID, kAudioFilePropertyChannelLayout, layoutSize, layout);
            if (noErr == error) {
                printf("Writing channel layout to destination file: %u\n", (unsigned int)layoutSize);
            } else {
                printf("Even though some formats have layouts, some files don't take them and that's OK\n");
            }
        }
        
        free(layout);
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
