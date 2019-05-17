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

#define numberOfRows floor(tableViewHeight/rowHeight)

int const rowHeight = 10;

double const Fs = 44100.0;
double const Fc = 440.0;
double const ALPHA = 0.99;

@interface ViewController () <UITableViewDelegate, UITableViewDataSource, EZMicrophoneDelegate, EZOutputDataSource, EZOutputDelegate> {
    NSInteger tableViewHeight;

    UInt32 idx;

    complex double val;
}

@property (nonatomic, strong) EZMicrophone *microphone;

@property (strong, nonatomic) IBOutlet UITableView *dotGraphReal;
@property (strong, nonatomic) IBOutlet UITableView *dotGraphImaginary;

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
    
    tableViewHeight = self.dotGraphReal.frame.size.height;

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
    [self.output startPlayback];

}

#pragma mark - Dot Graph Table View
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return numberOfRows;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return rowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    
    if (tableView == self.dotGraphReal) {
        cell.backgroundColor = (indexPath.row == self.realIndex) ? UIColor.greenColor : UIColor.blackColor;
    }
    
    if (tableView == self.dotGraphImaginary) {
        cell.backgroundColor = (indexPath.row == self.imaginaryIndex) ? UIColor.greenColor : UIColor.blackColor;
    }
    
    return cell;
}

#pragma mark - Audio Processing
-(void)microphone:(EZMicrophone *)microphone hasAudioReceived:(float **)buffer withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels {
    // 1. Gets data from microphone, and clears graphs
    // 2. Implements lock in amplifier by:
    //  2a. Multiplying microphone with reference signal
    //  2b. Pass result through low pass filter
    // 3. Mutate dotGraphArray with True where points should be shown on the dot graph
    // 4. Calls [self.dotGraph reloadData]; at end of function to update the dot graph
    
    NSInteger oldRealIndex = self.realIndex;
    NSInteger oldImaginaryIndex = self.imaginaryIndex;
    
    for(UInt32 i = 0; i < bufferSize; i++) {
        double arg = Fc / Fs * (idx + i) * 2 * M_PI;
        val = val * ALPHA + (sin(arg) + cos(arg) * I) * (*buffer)[i] * (1 - ALPHA);
    }
    
    idx += bufferSize;

    double realVal = creal(val);
    double imaginaryVal = cimag(val);
    
    float oldMax = 0.14;
    float oldMin = -0.14;
    float oldRange = (oldMax - oldMin);
    float newMax = numberOfRows;
    float newMin = 0;
    float newRange = (newMax - newMin);
    
    self.realIndex = floor((((realVal - oldMin) * newRange) / oldRange) + newMin);
    self.imaginaryIndex = floor((((imaginaryVal - oldMin) * newRange) / oldRange) + newMin);
    
    self.realIndex = MIN(self.realIndex, newMax);
    self.realIndex = MAX(0, self.realIndex);
    self.imaginaryIndex = MIN(self.imaginaryIndex, newMax);
    self.imaginaryIndex = MAX(0, self.imaginaryIndex);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.dotGraphReal reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:oldRealIndex inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
        [self.dotGraphImaginary reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:oldImaginaryIndex inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
        
        [self.dotGraphReal reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.realIndex inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
        [self.dotGraphImaginary reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.imaginaryIndex inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
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
