//
//  ViewController.m
//  LockInAmp
//
//  Created by Georges Kanaan on 17/05/2019.
//  Copyright © 2019 Georges Kanaan. All rights reserved.
//

#import <EZMicrophone.h>

#import "ViewController.h"

double referenceFrequency = 12;

@interface ViewController () <UITableViewDelegate, UITableViewDataSource, EZMicrophoneDelegate>

@property (nonatomic, strong) EZMicrophone *microphone;
@property (strong, nonatomic) IBOutlet UITableView *dotGraph;
@property (strong, nonatomic) NSMutableArray<NSNumber *> *dotGraphArray;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // Setup dot graph
    self.dotGraphArray = [NSMutableArray new];
    [self.dotGraph reloadData];
    
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
    NSInteger rows = floor(self.view.frame.size.height/self.dotGraph.rowHeight);
    [self updateDotgraphArraySize:rows];
    return rows;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 10;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
        cell.backgroundColor = UIColor.whiteColor;
    }
    
    if ([self.dotGraphArray[indexPath.row] boolValue]) {
        cell.backgroundColor = UIColor.greenColor;
        
    } else {
        cell.backgroundColor = UIColor.whiteColor;
    }
    
    return cell;
}

#pragma mark - Dot Graph Array
- (void)updateDotgraphArraySize:(NSInteger)rows {
    if (self.dotGraphArray.count != rows) {
        [self.dotGraphArray removeAllObjects];
        
        for (int i=0; i<rows; i++) {
            [self.dotGraphArray insertObject:@(NO) atIndex:i];
        }
    }
}

#pragma mark - Audio Processing
/**
 The microphone data represented as non-interleaved float arrays useful for:
 - Creating real-time waveforms using EZAudioPlot or EZAudioPlotGL
 - Creating any number of custom visualizations that utilize audio!
 */
-(void)microphone:(EZMicrophone *)microphone hasAudioReceived:(float **)buffer withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels {
    // 1. Gets data from microphone
    NSLog(@"buffer[0]: %@ bufferSize: %u numerOfChannels: %u", buffer[0], (unsigned int)bufferSize, (unsigned int)numberOfChannels);
    
    // 2. Implements lock in amplifier by:
    //  2a. Multiplying microphone with reference signal
    //  2b. Pass result through low pass filter
    // 3. Mutate dotGraphArray with True where points should be shown on the dot graph
    
    // 4. Calls [self.dotGraph reloadData]; at end of function to update the dot graph
    [self.dotGraph reloadData];
}

@end
