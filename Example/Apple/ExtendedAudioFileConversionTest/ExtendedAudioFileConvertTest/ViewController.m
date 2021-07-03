/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The main view controller of this app.
 */

#import "ViewController.h"
#import "ExtendedAudioFileConvertOperation.h"

@import AVFoundation;
@import AudioToolbox;

@interface ViewController () <ExtendedAudioFileConvertOperationDelegate, AVAudioPlayerDelegate>

// MARK: Properties

@property (weak, nonatomic) IBOutlet UILabel *sourceAudioFile;

@property (weak, nonatomic) IBOutlet UILabel *sourceFormatInfo;

@property (weak, nonatomic) IBOutlet UISegmentedControl *outputFormatSelector;

@property (weak, nonatomic) IBOutlet UISegmentedControl *outputSampleRateSelector;

@property (weak, nonatomic) IBOutlet UILabel *destinationAudioFile;

@property (weak, nonatomic) IBOutlet UILabel *destinationFormatInfo;

@property (weak, nonatomic) IBOutlet UIButton *convertAndPlayButton;

@property (weak, nonatomic) IBOutlet UIButton *stopAudioButton;

@property (nonatomic, strong) NSURL *sourceURL;

@property (nonatomic, strong) NSURL *destinationURL;

@property (assign, nonatomic) AudioFormatID outputFormat;

@property (assign, nonatomic) Float64 sampleRate;

@property (nonatomic, strong) ExtendedAudioFileConvertOperation *operation;

@property (nonatomic, strong) AVAudioPlayer *player;

@end

@implementation ViewController

// MARK: View Life Cycle.

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create the URLs to be used for the source.
//    NSString *sourcePath = [[NSBundle mainBundle] pathForResource:@"sourcePCM" ofType:@"aif"];
//    NSString *sourcePath = [[NSBundle mainBundle] pathForResource:@"OutputAAC" ofType:@"caf"];
    NSString *sourcePath = [[NSBundle mainBundle] pathForResource:@"audioUnit_646998421529" ofType:@"caf"];
    self.sourceURL = [NSURL fileURLWithPath:sourcePath];
    
    // Set the default values.
    self.outputFormat = kAudioFormatMPEG4AAC;
    self.sampleRate = 0;
    
    // Update fileInfo label.
    [self updateSourceFileInfo];
    
    // Cleanup any stray files from previous runs.
    [self removeDestinationFileIfNeeded];
    
    // Add Notification observer for audio interuptions while playing back audio.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruptionNotification:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
    
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
}

// MARK: Target-Action

- (IBAction)outputFormatSelectorValueChanged:(UISegmentedControl *)sender {
    switch (sender.selectedSegmentIndex) {
        case 0:
            self.outputFormat = kAudioFormatMPEG4AAC;
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:0];
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:1];
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:2];
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:3];
            break;
        case 1:
            self.outputFormat = kAudioFormatAppleIMA4;
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:0];
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:1];
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:2];
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:3];
            break;
        case 2:
            self.outputFormat = kAudioFormatiLBC;
            self.sampleRate = 8000.0;
            [self.outputSampleRateSelector setSelectedSegmentIndex:2];
            [self.outputSampleRateSelector setEnabled:NO forSegmentAtIndex:0];
            [self.outputSampleRateSelector setEnabled:NO forSegmentAtIndex:1];
            [self.outputSampleRateSelector setEnabled:NO forSegmentAtIndex:3];
            break;
        case 3:
            self.outputFormat = kAudioFormatAppleLossless;
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:0];
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:1];
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:2];
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:3];
            break;
        case 4:
            self.outputFormat = kAudioFormatLinearPCM;
            self.sampleRate = 44100.0;
            [self.outputSampleRateSelector setSelectedSegmentIndex:0];
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:1];
            [self.outputSampleRateSelector setEnabled:YES forSegmentAtIndex:2];
            [self.outputSampleRateSelector setEnabled:NO forSegmentAtIndex:3];
            break;
    }
    
    [self removeDestinationFileIfNeeded];
}

- (IBAction)outputSampleRateSelectorValueChanged:(UISegmentedControl *)sender {
    switch ([sender selectedSegmentIndex]) {
        case 0:
            self.sampleRate = 44100.0;
            break;
        case 1:
            self.sampleRate = 22050.0;
            break;
        case 2:
            self.sampleRate = 8000.0;
            break;
        case 3:
            self.sampleRate = 0;
            break;
    }
    
    [self removeDestinationFileIfNeeded];
}

- (IBAction)userDidPressConvertAndPlayButton:(UIButton *)sender {
    [self.convertAndPlayButton setTitle:@"Converting..." forState:UIControlStateDisabled];
    sender.enabled = NO;
    self.outputFormatSelector.enabled = NO;
    self.outputSampleRateSelector.enabled = NO;
    
    self.operation = [[ExtendedAudioFileConvertOperation alloc] initWithSourceURL:self.sourceURL destinationURL:self.destinationURL sampleRate:self.sampleRate outputFormat:self.outputFormat];
    
    self.operation.delegate = self;
    
    __weak __typeof__(self) weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [weakSelf.operation start];
    });
}

- (IBAction)userDidPressStopPlayingButton:(UIButton *)sender {
    if (self.player != nil) {
        [self.player stop];
        [self audioPlayerDidFinishPlaying:self.player successfully:YES];
    }
}

- (void)setOutputFormat:(AudioFormatID)outputFormat {
    _outputFormat = outputFormat;
    
    // After we set the output format we updated the URL for the output file be save to on disk.
    char formatID[5];
    *(UInt32 *)formatID = CFSwapInt32HostToBig(_outputFormat);
    NSString *formatString = [[NSString stringWithFormat:@"%4.4s", formatID] uppercaseString];
    
    NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *destinationFilePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"Output%@.caf", formatString]];
    NSLog(@"%@",destinationFilePath);
    self.destinationURL = [NSURL fileURLWithPath:destinationFilePath];
    [self updateDestinationFileInfo];
}

// MARK: UI Update Method.

- (void)updateSourceFileInfo {
    self.sourceAudioFile.text = self.sourceURL.lastPathComponent;
    
    self.sourceFormatInfo.text = [self fileInfoForURL:self.sourceURL withBitsPerChannel:YES];
}

- (void)updateDestinationFileInfo {
    self.destinationAudioFile.text = self.destinationURL.lastPathComponent;
    
    self.destinationFormatInfo.text = [self fileInfoForURL:self.destinationURL withBitsPerChannel:(self.outputFormat == kAudioFormatLinearPCM)];
}

- (NSString *)fileInfoForURL:(NSURL *)url withBitsPerChannel:(BOOL)bitsPerChannel {
    AudioFileID fileID;
    NSString *fileInfo = @" ";
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        OSStatus error = AudioFileOpenURL((__bridge CFURLRef _Nonnull)(url), kAudioFileReadPermission, 0, &fileID);
        
        if (error == noErr) {
            AudioStreamBasicDescription asbd = {};
            UInt32 size = sizeof(asbd);
            
            error = AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &size, &asbd);
            if (error == noErr) {
                char formatID[5];
                *(UInt32 *)formatID = CFSwapInt32HostToBig(asbd.mFormatID);
                
                fileInfo = [NSString stringWithFormat: @"%4.4s %6.0f Hz (%@ ch.)", formatID, asbd.mSampleRate, @(asbd.mChannelsPerFrame)];
                
                if (bitsPerChannel) {
                    fileInfo = [fileInfo stringByAppendingFormat:@" %@ bits/ch.", @(asbd.mBitsPerChannel)];
                }
            }else {
                printf("AudioFileGetProperty kAudioFilePropertyDataFormat result %d %4.4s\n", (int)error, (char*)&error);
            }
            
            AudioFileClose(fileID);
        } else {
            printf("AudioFileOpenURL failed! result %d %c%c%c%c\n", (int)error, (error >> 24) & 0xFF, (error >> 16) & 0xFF, (error >> 8) & 0xFF, error & 0xFF);
        }
    }
    
    return fileInfo;
}

- (void)removeDestinationFileIfNeeded {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:self.destinationURL.path]) {
        [fileManager removeItemAtPath:self.destinationURL.path error:nil];
        
        [self updateDestinationFileInfo];
    }
}

// MARK: AudioFileConvertOperationDelegate Protocol Methods.

- (void)audioFileConvertOperation:(ExtendedAudioFileConvertOperation *)audioFileConvertOperation didCompleteWithURL:(NSURL *)destinationURL {
    
    __weak __typeof__(self) weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf updateDestinationFileInfo];
        
        weakSelf.operation = nil;
        [weakSelf.convertAndPlayButton setTitle:@"Playing Audio..." forState:UIControlStateDisabled];
        weakSelf.stopAudioButton.hidden = NO;
        
        NSError *error = nil;
        weakSelf.player = [[AVAudioPlayer alloc] initWithContentsOfURL:destinationURL error:&error];
        weakSelf.player.delegate = self;
        
        if (error == nil) {
            [weakSelf.player play];
        } else {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error Occured" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
            
            [weakSelf presentViewController:alertController animated:YES completion:nil];
        }
    });
}

- (void)audioFileConvertOperation:(ExtendedAudioFileConvertOperation *)audioFileConvertOperation didEncounterError:(NSError *)error {
    
    __weak __typeof__(self) weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.operation = nil;
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error Occured" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
        
        [weakSelf presentViewController:alertController animated:YES completion:nil];
        
        [weakSelf.convertAndPlayButton setTitle:@"Convert & Play File" forState:UIControlStateNormal];
        weakSelf.convertAndPlayButton.enabled = YES;
    });
}

// MARK: AVAudioPlayerDelegate Protocol Methods.

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Playback Error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alertController animated:YES completion:nil];
    
    [self audioPlayerDidFinishPlaying:player successfully:NO];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [self.convertAndPlayButton setTitle:@"Convert & Play File" forState:UIControlStateNormal];
    self.convertAndPlayButton.enabled = YES;
    self.outputFormatSelector.enabled = YES;
    self.outputSampleRateSelector.enabled = YES;
    self.stopAudioButton.hidden = YES;
    
    self.player = nil;
    
    [self removeDestinationFileIfNeeded];
}

// MARK: Notification Handler Methods.

- (void)handleAudioSessionInterruptionNotification:(NSNotification *)notification {
    
    // For the purposes of this sample we only stop playback if needed and reset the UI back to being ready to convert again.
    if (self.player != nil) {
        [self.player stop];
        [self audioPlayerDidFinishPlaying:self.player successfully:YES];
    }
    
}

@end
