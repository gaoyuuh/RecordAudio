//
//  ViewController.m
//  recordAudip
//
//  Created by gaoyu on 2021/6/5.
//

#import "ViewController.h"
#import "RecordController.h"
#import "AVAudioEngineController.h"
#import "AVAudioRecorderController.h"
#import "AudioUnitController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
//    AVAudioSession *session = [AVAudioSession sharedInstance];
//    double sampleRate = [session sampleRate];
//    NSInteger inputChannels = [session inputNumberOfChannels];
//    NSInteger outputChannels = [session outputNumberOfChannels];
//    NSTimeInterval intputLatency = [session inputLatency];
//    NSTimeInterval outputLatency = [session outputLatency];
//    NSTimeInterval bufferDuration = [session IOBufferDuration];
//    NSLog(@"--- %f", sampleRate);
    
    
//    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
//    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
//    [audioSession setPreferredSampleRate:(double)44100.0 error:nil];
//
////    UInt32 oneFlag = 1;
////    UInt32 busZero = 0;//Element 0
////    CheckError(AudioUnitSetProperty(remoteIOUnit,
////                                    kAudioOutputUnitProperty_EnableIO,
////                                    kAudioUnitScope_Output,
////                                    busZero,
////                                    &oneFlag,
////                                    sizeof(oneFlag)),"couldn't kAudioOutputUnitProperty_EnableIO with kAudioUnitScope_Output");
//
//    AUGraph auGraph;
//    NewAUGraph(&auGraph);
//    AUGraphOpen(auGraph);
}


#pragma mark - AVAudioRecorder

- (IBAction)avAudioRecorderAction:(id)sender {
    AVAudioRecorderController *avc = [[AVAudioRecorderController alloc] init];
    [self presentViewController:avc animated:YES completion:nil];
}


#pragma mark - AudioQueue

- (IBAction)audioQueueAction:(id)sender {
    RecordController *rvc = [[RecordController alloc] init];
    [self presentViewController:rvc animated:YES completion:nil];
}


#pragma mark - AVAudioEngine

- (IBAction)audioEngineAction:(id)sender {
    AVAudioEngineController *evc = [[AVAudioEngineController alloc] init];
    [self presentViewController:evc animated:YES completion:nil];
}


#pragma mark - AudioUnit

- (IBAction)audioUnitAction:(id)sender {
    AudioUnitController *avc = [[AudioUnitController alloc] init];
    [self presentViewController:avc animated:YES completion:nil];
}

@end
