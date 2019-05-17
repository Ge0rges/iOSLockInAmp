//
//  ViewController.m
//  LockInAmp
//
//  Created by Georges Kanaan on 17/05/2019.
//  Copyright © 2019 Georges Kanaan. All rights reserved.
//

#import <complex.h>
#import <EZMicrophone.h>

#import "ViewController.h"

#define Fs 44100.0
#define Fc 440.0
#define ALPHA 0.99
#define rowHeight 2

@interface ViewController () <UITableViewDelegate, UITableViewDataSource, EZMicrophoneDelegate> {
    UInt32 idx;
    complex double val;
    NSInteger tableViewHeight;
}

@property (nonatomic, strong) EZMicrophone *microphone;

@property (strong, nonatomic) IBOutlet UITableView *dotGraphReal;
@property (strong, nonatomic) IBOutlet UITableView *dotGraphImaginary;

@property (strong, nonatomic) NSMutableArray<NSNumber *> *dotGraphRealArray;
@property (strong, nonatomic) NSMutableArray<NSNumber *> *dotGraphImaginaryArray;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    tableViewHeight = self.dotGraphReal.frame.size.height;

    // Setup dot graph arrays
    self.dotGraphRealArray = [NSMutableArray new];
    self.dotGraphImaginaryArray = [NSMutableArray new];
    [self resetDotGraphs];
    
    // Setup dot graph
    [self.dotGraphReal reloadData];
    [self.dotGraphImaginary reloadData];
    
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
}

#pragma mark - Dot Graph Table View
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rows = floor(tableViewHeight/rowHeight);
    if (tableView == self.dotGraphReal) {
        rows = ceil(tableViewHeight/rowHeight);
    }
    return rows;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return rowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    
    if (tableView == self.dotGraphReal && self.dotGraphRealArray.count > indexPath.row) {
        if ([self.dotGraphRealArray[indexPath.row] boolValue]) {
            cell.backgroundColor = UIColor.greenColor;
            
        } else {
            cell.backgroundColor = UIColor.whiteColor;
        }
        
    } else if (tableView == self.dotGraphImaginary && self.dotGraphImaginaryArray.count > indexPath.row) {
        if ([self.dotGraphImaginaryArray[indexPath.row] boolValue]) {
            cell.backgroundColor = UIColor.greenColor;
            
        } else {
            cell.backgroundColor = UIColor.whiteColor;
        }
    }
    
    return cell;
}

#pragma mark - Dot Graph Array
- (void)resetDotGraphs {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.dotGraphRealArray removeAllObjects];
        [self.dotGraphImaginaryArray removeAllObjects];
        
        for (int i=0; i<floor(self->tableViewHeight/rowHeight); i++) {
            [self.dotGraphRealArray insertObject:@(NO) atIndex:i];
            [self.dotGraphImaginaryArray insertObject:@(NO) atIndex:i];
        }
    });
}


#pragma mark - Audio Processing
-(void)microphone:(EZMicrophone *)microphone hasAudioReceived:(float **)buffer withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels {
    // 1. Gets data from microphone, and clears graphs
    // 2. Implements lock in amplifier by:
    //  2a. Multiplying microphone with reference signal
    //  2b. Pass result through low pass filter
    // 3. Mutate dotGraphArray with True where points should be shown on the dot graph
    // 4. Calls [self.dotGraph reloadData]; at end of function to update the dot graph
    
    [self resetDotGraphs];
    
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
    float newMax = (self.dotGraphRealArray.count > 0) ? self.dotGraphRealArray.count-1 : 0;
    float newMin = 0;
    float newRange = (newMax - newMin);
    
    int realIndex = floor((((realVal - oldMin) * newRange) / oldRange) + newMin);
    int imaginaryIndex = floor((((imaginaryVal - oldMin) * newRange) / oldRange) + newMin);
    
    realIndex = MIN(realIndex, newMax);
    realIndex = MAX(0, realIndex);
    imaginaryIndex = MIN(imaginaryIndex, newMax);
    imaginaryIndex = MAX(0, imaginaryIndex);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.dotGraphRealArray replaceObjectAtIndex:realIndex withObject:[NSNumber numberWithBool:YES]];
        [self.dotGraphImaginaryArray replaceObjectAtIndex:imaginaryIndex withObject:[NSNumber numberWithBool:YES]];
        
        [self.dotGraphReal reloadData];
        [self.dotGraphImaginary reloadData];
    });
}

@end
