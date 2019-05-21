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
double const Fc = 440.0*5;
double const ALPHA = 0.99;
float const indicatorYMargin = 40;

@interface ViewController () <EZMicrophoneDelegate, EZOutputDataSource> {
    NSInteger viewheight;
    complex double val;
    double theta;
    
    int calibrations;
    float oldMaxR;
    float oldMinR;
    float oldMaxI;
    float oldMinI;
}

@property (nonatomic, strong) UIView *realView;
@property (nonatomic, strong) UIView *imaginaryView;

@property (nonatomic, strong) EZMicrophone *microphone;
@property (nonatomic, strong) EZOutput *output;

@property (nonatomic, nonatomic) NSInteger realIndex;
@property (nonatomic, nonatomic) NSInteger imaginaryIndex;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    viewheight = self.view.frame.size.height;
    calibrations = 0;
    oldMaxR = FLT_MIN;
    oldMinR = FLT_MAX;
    oldMaxI = FLT_MIN;
    oldMinI = FLT_MAX;
    
    // Setup views
    self.realView = [[UIView alloc] initWithFrame:CGRectMake(self.view.frame.size.width/2 - indicatorSize/2, indicatorYMargin, indicatorSize, indicatorSize)];
    self.imaginaryView = [[UIView alloc] initWithFrame:CGRectMake(self.view.frame.size.width/2 + indicatorSize/2, indicatorYMargin, indicatorSize, indicatorSize)];
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
    
    NSArray *outputs = [EZAudioDevice outputDevices];
    [self.output setDevice:[outputs firstObject]];
    [self.output startPlayback];


}

#pragma mark - Audio Processing
-(void)microphone:(EZMicrophone *)microphone hasAudioReceived:(float **)buffer withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels {
    // 1. Gets data from microphone, and clears graphs
    // 2. Implements lock in amplifier by:
    //  2a. Multiplying microphone with reference signal
    //  2b. Pass result through low pass filter
    // 3. Mutate dotGraphArray with True where points should be shown on the dot graph
    // 4. Calls [self.dotGraph reloadData]; at end of function to update the dot graph
    
    // Lock in amp math
    for(UInt32 i = 0; i < bufferSize; i++) {
        double arg = Fc / Fs * i * 2 * M_PI + theta;// theta preserves phase information
        val = val * ALPHA + (sin(arg) + cos(arg) * I) * (*buffer)[i] * (1 - ALPHA);
    }
    
    // Split val into real and imaginary parts
    double realVal = creal(val);
    double imaginaryVal = cimag(val);
    
    // Calibrations
    if (calibrations < 2700) {
        oldMinI = MIN(oldMinI, imaginaryVal);
        oldMaxI = MAX(oldMaxI, imaginaryVal);
        oldMinR = MIN(oldMinR, realVal);
        oldMaxR = MAX(oldMaxR, realVal);
        
        //NSLog(@"calibration %i vals oldMinI: %f oldMaxI: %f oldMinR: %f oldMaxR: %f", calibrations, oldMinI, oldMaxI, oldMinR, oldMaxR);
        calibrations ++;
        return;
    }
    
    // Scale val to the height of the screen
    float oldRangeR = (oldMaxR - oldMinR);
    float oldRangeI = (oldMaxI - oldMinI);
    float newMax = viewheight-indicatorYMargin*2-indicatorSize;
    float newMin = indicatorYMargin;
    float newRange = (newMax - newMin);
    
    self.realIndex = floor((((realVal - oldMinR) * newRange) / oldRangeR) + newMin);
    self.imaginaryIndex = floor((((imaginaryVal - oldMinI) * newRange) / oldRangeI) + newMin);
    
    // On the main queue (UI), animate the indicators.
    dispatch_async(dispatch_get_main_queue(), ^{
        //[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
        [UIView animateWithDuration:0.1 animations:^{
            [self.realView setFrame:CGRectMake(self.realView.frame.origin.x, self.realIndex, indicatorSize, indicatorSize)];
            [self.imaginaryView setFrame:CGRectMake(self.imaginaryView.frame.origin.x, self.imaginaryIndex, indicatorSize, indicatorSize)];
        } completion:nil];
    });
}

#pragma mark - EZOutput DataSource & Delegate
- (OSStatus)output:(EZOutput *)output shouldFillAudioBufferList:(AudioBufferList *)audioBufferList withNumberOfFrames:(UInt32)frames timestamp:(const AudioTimeStamp *)timestamp {// Generate a reference signal at Fc
    Float32 *buffer = (Float32 *)audioBufferList->mBuffers[0].mData;
    
    double thetaIncrement = 2.0 * M_PI * Fc / Fs;
    
    for (UInt32 frame = 0; frame < frames; frame++) {
        buffer[frame] = sin(theta);
        theta += thetaIncrement;
        theta = (theta > 2.0 * M_PI) ? 0 : theta;
    }
    
    return noErr;
}

#pragma mark - UI
- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

@end
