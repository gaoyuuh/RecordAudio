//
//  RecordController.m
//  recordAudip
//
//  Created by gaoyu on 2021/6/7.
//

#import "RecordController.h"
#import "AQRecorderManager.h"

@interface RecordController ()

@property (nonatomic, strong) UIButton * btnRecord;

@property (nonatomic, strong) AQRecorderManager * recorderMgr;

@end

@implementation RecordController

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

- (AQRecorderManager *)recorderMgr {
    if (!_recorderMgr) {
        _recorderMgr = [[AQRecorderManager alloc] initAudioFormatType:AudioFormatLinearPCM sampleRate:8000.0 channels:1 bitsPerChannel:16];
    }
    return _recorderMgr;
}

@end
