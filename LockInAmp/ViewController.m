//
//  ViewController.m
//  LockInAmp
//
//  Created by Georges Kanaan on 17/05/2019.
//  Copyright © 2019 Georges Kanaan. All rights reserved.
//

#import <complex.h>
#import <EZAudio.h>

#import "ViewController.h"

int const indicatorSize = 10;

double const Fs = 44100.0;
double const Fc = 440.0;
double const ALPHA = 0.99;

@interface ViewController () <EZMicrophoneDelegate, EZOutputDataSource, EZOutputDelegate> {
    NSInteger viewheight;

    UInt32 idx;

    complex double val;
}

@property (nonatomic, strong) UIView *realView;
@property (nonatomic, strong) UIView *imaginaryView;

@property (nonatomic, strong) EZMicrophone *microphone;
@property (nonatomic, strong) EZOutput *output;

@property (nonatomic) double amplitude;
@property (nonatomic) double frequency;
@property (nonatomic) double sampleRate;
@property (nonatomic) double step;
@property (nonatomic) double theta;

@property (nonatomic, nonatomic) NSInteger realIndex;
@property (nonatomic, nonatomic) NSInteger imaginaryIndex;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    viewheight = self.view.frame.size.height;
    
    // Setup views
    self.realView = [[UIView alloc] initWithFrame:CGRectMake(self.view.frame.size.width/2 - indicatorSize/2, 20, indicatorSize, indicatorSize)];
    self.imaginaryView = [[UIView alloc] initWithFrame:CGRectMake(self.view.frame.size.width/2 + indicatorSize/2, 20, indicatorSize, indicatorSize)];
    self.realView.backgroundColor = UIColor.redColor;
    self.imaginaryView.backgroundColor = UIColor.greenColor;
    
    [self.view addSubview:self.realView];
    [self.view addSubview:self.imaginaryView];
    
    // Setup AudioSession
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error) {
        NSLog(@"Error setting up audio session category: %@", error.localizedDescription);
    }
    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"Error setting up audio session active: %@", error.localizedDescription);
    }
    
    // Setup microphone
    self.microphone = [EZMicrophone microphoneWithDelegate:self];
    NSArray *inputs = [EZAudioDevice inputDevices];
    [self.microphone setDevice:[inputs lastObject]];
    [self.microphone startFetchingAudio];
    
    // Setup output
    AudioStreamBasicDescription inputFormat = [EZAudioUtilities monoFloatFormatWithSampleRate:Fs];
    self.output = [EZOutput outputWithDataSource:self inputFormat:inputFormat];
    [self.output setDelegate:self];
    self.frequency = Fc-1;
    self.sampleRate = inputFormat.mSampleRate;
    self.amplitude = 0.80;
    
    NSArray *outputs = [EZAudioDevice outputDevices];
    [self.output setDevice:[outputs firstObject]];
    //[self.output startPlayback];

}

#pragma mark - Audio Processing
-(void)microphone:(EZMicrophone *)microphone hasAudioReceived:(float **)buffer withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels {
    // 1. Gets data from microphone, and clears graphs
    // 2. Implements lock in amplifier by:
    //  2a. Multiplying microphone with reference signal
    //  2b. Pass result through low pass filter
    // 3. Mutate dotGraphArray with True where points should be shown on the dot graph
    // 4. Calls [self.dotGraph reloadData]; at end of function to update the dot graph
    
    for(UInt32 i = 0; i < bufferSize; i++) {
        double arg = Fc / Fs * (idx + i) * 2 * M_PI;
        val = val * ALPHA + (sin(arg) + cos(arg) * I) * (*buffer)[i] * (1 - ALPHA);
    }
    
    idx += bufferSize;

    double realVal = creal(val);
    double imaginaryVal = cimag(val);
    
    float oldMax = 0.15;
    float oldMin = -0.15;
    float oldRange = (oldMax - oldMin);
    float newMax = viewheight-40-indicatorSize;
    float newMin = 20;
    float newRange = (newMax - newMin);
    
    self.realIndex = floor((((realVal - oldMin) * newRange) / oldRange) + newMin);
    self.imaginaryIndex = floor((((imaginaryVal - oldMin) * newRange) / oldRange) + newMin);
    
    self.realIndex = MIN(self.realIndex, newMax);
    self.realIndex = MAX(0, self.realIndex);
    self.imaginaryIndex = MIN(self.imaginaryIndex, newMax);
    self.imaginaryIndex = MAX(0, self.imaginaryIndex);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.realView setFrame:CGRectMake(self.realView.frame.origin.x, self.realIndex, indicatorSize, indicatorSize)];
        [self.imaginaryView setFrame:CGRectMake(self.imaginaryView.frame.origin.x, self.imaginaryIndex, indicatorSize, indicatorSize)];
    });
}

#pragma mark - EZOutput DataSource & Delegate
- (OSStatus)output:(EZOutput *)output shouldFillAudioBufferList:(AudioBufferList *)audioBufferList withNumberOfFrames:(UInt32)frames timestamp:(const AudioTimeStamp *)timestamp {
    Float32 *buffer = (Float32 *)audioBufferList->mBuffers[0].mData;
    
    double thetaIncrement = 2.0 * M_PI * self.frequency / Fs;

    for (UInt32 frame = 0; frame < frames; frame++) {
        buffer[frame] = self.amplitude * sin(self.theta);
        self.theta += thetaIncrement;
        if (self.theta > 2.0 * M_PI) {
            self.theta -= 2.0 * M_PI;
        }
    }
    
    return noErr;
}

- (void)output:(EZOutput *)output playedAudio:(float **)buffer withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels {
    return;
}

@end
