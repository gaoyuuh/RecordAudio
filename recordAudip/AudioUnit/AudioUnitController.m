//
//  AudioUnitController.m
//  recordAudip
//
//  Created by gaoyu on 2021/7/1.
//

#import "AudioUnitController.h"
#import "AudioUnitManager.h"

@interface AudioUnitController ()

@property (nonatomic, strong) UIButton * btnRecord;

@property (nonatomic, strong) AudioUnitManager * audioUnitMgr;

@end

@implementation AudioUnitController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    self.btnRecord = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnRecord.frame = CGRectMake((UIScreen.mainScreen.bounds.size.width-100)/2.f, 100, 100, 40);
    [self.btnRecord setTitle:@"开始" forState:UIControlStateNormal];
    [self.btnRecord setTitleColor:UIColor.redColor forState:UIControlStateNormal];
    [self.btnRecord addTarget:self action:@selector(recordAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnRecord];
    
    UILabel *lb6 = [[UILabel alloc] initWithFrame:CGRectMake(150, 200, 50, 20)];
    lb6.text = @"mute:";
    [self.view addSubview:lb6];
    UISwitch *muteSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(150, CGRectGetMaxY(lb6.frame) + 10, 100, 50)];
    [muteSwitch setOn:NO];
    [muteSwitch addTarget:self action:@selector(muteChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:muteSwitch];
}

- (void)muteChange:(UISwitch *)swit {
    self.audioUnitMgr.hasMute = swit.isOn;
}

- (void)recordAction:(UIButton *)btn {
    if (self.audioUnitMgr.isRuning) {
        [self.btnRecord setTitle:@"开始录制" forState:UIControlStateNormal];
        
        [self.audioUnitMgr stopRecord];
        
    } else {
        [self.btnRecord setTitle:@"结束录制" forState:UIControlStateNormal];
        
        [self.audioUnitMgr startRecord];
    }
}

- (AudioUnitManager *)audioUnitMgr {
    if (!_audioUnitMgr) {
        _audioUnitMgr = [[AudioUnitManager alloc] init];
    }
    return _audioUnitMgr;
}

@end
