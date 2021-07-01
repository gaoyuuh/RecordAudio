//
//  AVAudioEngineController.m
//  recordAudip
//
//  Created by gaoyu on 2021/6/28.
//

#import "AVAudioEngineController.h"
#import "AVAudioEngineManager.h"

@interface AVAudioEngineController ()

@property (nonatomic, strong) UIButton * btnRecord;

@property (nonatomic, strong) AVAudioEngineManager * engineMgr;

@property (nonatomic, strong) UISlider * volumnSlider;
@property (nonatomic, strong) UISlider * inputVolumnSlider;
@property (nonatomic, strong) UISlider * playerVolumnSlider;

@property (nonatomic, strong) UISlider * rateSlider;
@property (nonatomic, strong) UISlider * pitchSlider;
@property (nonatomic, strong) UISlider * reverbWetDryMixSlider;

@end

@implementation AVAudioEngineController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    self.btnRecord = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnRecord.frame = CGRectMake((UIScreen.mainScreen.bounds.size.width-100)/2.f, 100, 100, 40);
    [self.btnRecord setTitle:@"开始" forState:UIControlStateNormal];
    [self.btnRecord setTitleColor:UIColor.redColor forState:UIControlStateNormal];
    [self.btnRecord addTarget:self action:@selector(recordAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnRecord];
    
    UILabel *lb1 = [[UILabel alloc] initWithFrame:CGRectMake(50, CGRectGetMaxY(self.btnRecord.frame) + 5, UIScreen.mainScreen.bounds.size.width-100, 20)];
    lb1.text = @"主输出音量:";
    [self.view addSubview:lb1];
    self.volumnSlider = [[UISlider alloc] initWithFrame:CGRectMake(50, CGRectGetMaxY(self.btnRecord.frame) + 20, UIScreen.mainScreen.bounds.size.width-100, 50)];
    [self.volumnSlider addTarget:self action:@selector(sliderChange:) forControlEvents:UIControlEventValueChanged];
    self.volumnSlider.value = 1.0;
    [self.view addSubview:self.volumnSlider];
    
    UILabel *lb2 = [[UILabel alloc] initWithFrame:CGRectMake(50, CGRectGetMaxY(self.volumnSlider.frame) + 5, UIScreen.mainScreen.bounds.size.width-100, 20)];
    lb2.text = @"录音音量:";
    [self.view addSubview:lb2];
    self.inputVolumnSlider = [[UISlider alloc] initWithFrame:CGRectMake(50, CGRectGetMaxY(self.volumnSlider.frame) + 20, UIScreen.mainScreen.bounds.size.width-100, 50)];
    [self.inputVolumnSlider addTarget:self action:@selector(inputSliderChange:) forControlEvents:UIControlEventValueChanged];
    self.inputVolumnSlider.value = 1.0;
    [self.view addSubview:self.inputVolumnSlider];
    
    UILabel *lb3 = [[UILabel alloc] initWithFrame:CGRectMake(50, CGRectGetMaxY(self.inputVolumnSlider.frame) + 5, UIScreen.mainScreen.bounds.size.width-100, 20)];
    lb3.text = @"背景音乐音量:";
    [self.view addSubview:lb3];
    self.playerVolumnSlider = [[UISlider alloc] initWithFrame:CGRectMake(50, CGRectGetMaxY(self.inputVolumnSlider.frame) + 20, UIScreen.mainScreen.bounds.size.width-100, 50)];
    [self.playerVolumnSlider addTarget:self action:@selector(playerSliderChange:) forControlEvents:UIControlEventValueChanged];
    self.playerVolumnSlider.value = 1.0;
    [self.view addSubview:self.playerVolumnSlider];
    
    UILabel *lb4 = [[UILabel alloc] initWithFrame:CGRectMake(50, CGRectGetMaxY(self.playerVolumnSlider.frame) + 5, UIScreen.mainScreen.bounds.size.width-100, 20)];
    lb4.text = @"wetDryMix:";
    [self.view addSubview:lb4];
    self.reverbWetDryMixSlider = [[UISlider alloc] initWithFrame:CGRectMake(50, CGRectGetMaxY(self.playerVolumnSlider.frame) + 20, UIScreen.mainScreen.bounds.size.width-100, 50)];
    [self.reverbWetDryMixSlider addTarget:self action:@selector(WetDryMixSliderChange:) forControlEvents:UIControlEventValueChanged];
    self.reverbWetDryMixSlider.value = 0;
    self.reverbWetDryMixSlider.minimumValue = 0;
    self.reverbWetDryMixSlider.maximumValue = 100;
    [self.view addSubview:self.reverbWetDryMixSlider];
    
    UILabel *lb5 = [[UILabel alloc] initWithFrame:CGRectMake(50, CGRectGetMaxY(self.reverbWetDryMixSlider.frame) + 5, UIScreen.mainScreen.bounds.size.width-100, 20)];
    lb5.text = @"rate:";
    [self.view addSubview:lb5];
    self.rateSlider = [[UISlider alloc] initWithFrame:CGRectMake(50, CGRectGetMaxY(self.reverbWetDryMixSlider.frame) + 20, UIScreen.mainScreen.bounds.size.width-100, 50)];
    [self.rateSlider addTarget:self action:@selector(rateSliderChange:) forControlEvents:UIControlEventValueChanged];
    self.rateSlider.value = 1.0;
    self.rateSlider.minimumValue = .5;
    self.rateSlider.maximumValue = 2;
    [self.view addSubview:self.rateSlider];
    
    UILabel *lb6 = [[UILabel alloc] initWithFrame:CGRectMake(50, CGRectGetMaxY(self.rateSlider.frame) + 5, UIScreen.mainScreen.bounds.size.width-100, 20)];
    lb6.text = @"pitch:";
    [self.view addSubview:lb6];
    self.pitchSlider = [[UISlider alloc] initWithFrame:CGRectMake(50, CGRectGetMaxY(self.rateSlider.frame) + 20, UIScreen.mainScreen.bounds.size.width-100, 50)];
    [self.pitchSlider addTarget:self action:@selector(pitchSliderChange:) forControlEvents:UIControlEventValueChanged];
    self.pitchSlider.value = 0;
    self.pitchSlider.minimumValue = -2400;
    self.pitchSlider.maximumValue = 2400;
    [self.view addSubview:self.pitchSlider];
}

- (void)sliderChange:(UISlider *)slider {
    self.engineMgr.outPutVolumn = slider.value;
}

- (void)inputSliderChange:(UISlider *)slider {
    self.engineMgr.inputVolumn = slider.value;
}

- (void)playerSliderChange:(UISlider *)slider {
    self.engineMgr.playerVolumn = slider.value;
}

- (void)WetDryMixSliderChange:(UISlider *)slider {
    self.engineMgr.reverbWetDryMix = slider.value;
}

- (void)rateSliderChange:(UISlider *)slider {
    self.engineMgr.playRate = slider.value;
}

- (void)pitchSliderChange:(UISlider *)slider {
    self.engineMgr.pitch = slider.value;
}

- (void)recordAction:(UIButton *)btn {
    if (self.engineMgr.isRuning) {
        [self.btnRecord setTitle:@"开始录制" forState:UIControlStateNormal];
        
        [self.engineMgr stopRecord];
        
    } else {
        [self.btnRecord setTitle:@"结束录制" forState:UIControlStateNormal];
        
        [self.engineMgr startRecord];
    }
}

- (AVAudioEngineManager *)engineMgr {
    if (!_engineMgr) {
        _engineMgr = [[AVAudioEngineManager alloc] init];
    }
    return _engineMgr;
}

@end
