//
//  AVAudioRecorderController.m
//  recordAudip
//
//  Created by gaoyu on 2021/6/8.
//

#import "AVAudioRecorderController.h"
#import "AVAudioRecorderManager.h"

@interface AVAudioRecorderController ()

@property (nonatomic, strong) UIButton * btnRecord;

@property (nonatomic, strong) AVAudioRecorderManager * recorderMgr;

@end

@implementation AVAudioRecorderController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    self.btnRecord = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnRecord.frame = CGRectMake((UIScreen.mainScreen.bounds.size.width-100)/2.f, 200, 100, 40);
    [self.btnRecord setTitle:@"开始" forState:UIControlStateNormal];
    [self.btnRecord setTitleColor:UIColor.redColor forState:UIControlStateNormal];
    [self.btnRecord addTarget:self action:@selector(recordAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnRecord];

}

- (void)recordAction:(UIButton *)btn {
    if (self.recorderMgr.isRecording) {
        [self.btnRecord setTitle:@"开始录制" forState:UIControlStateNormal];
        
        [self.recorderMgr stopRecord];
        
    } else {
        [self.btnRecord setTitle:@"结束录制" forState:UIControlStateNormal];
        
        [self.recorderMgr startRecord];
    }
}

- (AVAudioRecorderManager *)recorderMgr {
    if (!_recorderMgr) {
        _recorderMgr = [[AVAudioRecorderManager alloc] initAudioFormatType:AudioFormatMPEG4AAC sampleRate:8000.0 channels:1 bitsPerChannel:16];
    }
    return _recorderMgr;
}

@end
