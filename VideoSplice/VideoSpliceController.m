//
//  VideoSpliceController.m
//  VideoSplice
//
//  Created by erpapa on 16/8/14.
//  Copyright © 2016年 erpapa. All rights reserved.
//

#import "VideoSpliceController.h"
#import <AVFoundation/AVFoundation.h>

@interface VideoSpliceController()<NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *firstLabel;
@property (weak) IBOutlet NSTextField *secondLabel;
@property (weak) IBOutlet NSTextField *thirdLabel;

@property (weak) IBOutlet NSTextField *firstField;
@property (weak) IBOutlet NSTextField *secondField;
@property (weak) IBOutlet NSTextField *thirdField;

@property (weak) IBOutlet NSSegmentedControl *segmentedControl;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

@property (weak) IBOutlet NSButton *convertButton;
@property (nonatomic, strong) AVAssetExportSession *assetExportSession;
@property (nonatomic, strong) NSTimer *timer;

@end

@implementation VideoSpliceController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    self.thirdLabel.hidden = YES;
    self.thirdField.hidden = YES;
    self.progressIndicator.hidden = YES;
    self.firstField.delegate = self;
    
}

- (IBAction)segmentedClicked:(NSSegmentedCell *)sender {
    if (sender.selectedSegment == 0) {
        self.thirdLabel.hidden = YES;
        self.thirdField.hidden = YES;
        self.firstLabel.stringValue = @"视频路径：";
        self.secondLabel.stringValue = @"输出路径：";
    } else if (sender.selectedSegment == 1) {
        self.thirdLabel.hidden = NO;
        self.thirdField.hidden = NO;
        self.firstLabel.stringValue = @"第一个：";
        self.secondLabel.stringValue = @"第二个：";
        self.thirdLabel.stringValue = @"输出路径：";
    } else if (sender.selectedSegment == 2) {
        self.thirdLabel.hidden = NO;
        self.thirdField.hidden = NO;
        self.firstLabel.stringValue = @"视频路径：";
        self.secondLabel.stringValue = @"音频路径：";
        self.thirdLabel.stringValue = @"输出路径：";
    }
}

- (IBAction)convert:(NSButton *)sender {
    self.segmentedControl.enabled = NO;
    self.convertButton.enabled = NO;
    self.progressIndicator.hidden = NO;
    
    void (^completeBlock)(BOOL success) = ^(BOOL success){
        if (success) {
            [self.timer invalidate];
            self.timer = nil;
            self.segmentedControl.enabled = YES;
            self.progressIndicator.doubleValue = 100;
            self.convertButton.enabled = YES;
            self.secondField.editable = YES;
            self.thirdField.editable = YES;
        } else {
            [self.timer invalidate];
            self.timer = nil;
            self.segmentedControl.enabled = YES;
            self.progressIndicator.doubleValue = 0;
            self.convertButton.enabled = YES;
            self.secondField.editable = YES;
            self.thirdField.editable = YES;
        }
    };
    
    if (self.segmentedControl.selectedSegment == 0) {
        self.secondField.editable = NO;
        NSURL *url = [NSURL fileURLWithPath:self.firstField.stringValue];
        NSString *savePath = self.secondField.stringValue;
        if ([self.firstField.stringValue isEqualToString:self.secondField.stringValue]) {
            savePath = [[url path] stringByAppendingString:@"_1"];
            self.secondField.stringValue = savePath;
        }
        [self convertBlurVideo:self.firstField.stringValue savePath:self.secondField.stringValue completeHandler:^(BOOL success) {
            completeBlock(success);
        }];
    } else if (self.segmentedControl.selectedSegment == 1) {
        self.thirdField.editable = NO;
        NSURL *url = [NSURL fileURLWithPath:self.firstField.stringValue];
        NSString *savePath = self.secondField.stringValue;
        if ([self.firstField.stringValue isEqualToString:self.thirdField.stringValue]) {
            savePath = [[url path] stringByAppendingString:@"_1"];
            self.thirdField.stringValue = savePath;
        }
        [self compostionFirstVideo:self.firstField.stringValue secondVideo:self.secondField.stringValue finalVideoPath:self.thirdField.stringValue completeHandler:^(BOOL success) {
            completeBlock(success);
        }];
    } else if (self.segmentedControl.selectedSegment == 2) {
        self.thirdField.editable = NO;
        NSURL *url = [NSURL fileURLWithPath:self.firstField.stringValue];
        NSString *savePath = self.secondField.stringValue;
        if ([self.firstField.stringValue isEqualToString:self.thirdField.stringValue]) {
            savePath = [[url path] stringByAppendingString:@"_1"];
            self.thirdField.stringValue = savePath;
        }
        [self compressVideoPath:self.firstField.stringValue andAudio:self.secondField.stringValue finalVideoPath:self.thirdField.stringValue completeHandler:^(BOOL success) {
            completeBlock(success);
        }];
    }
    
    
    // NSTimer
    if (self.timer != nil)
    {
        [self.timer invalidate];
    }
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(refreshProgress) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)refreshProgress
{
    self.progressIndicator.doubleValue = self.assetExportSession.progress*100;
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)obj
{
    NSURL *url = [NSURL fileURLWithPath:self.firstField.stringValue];
    NSString *inputString = [url path];
    if (url.pathExtension.length) {
        NSString *replaceString = [NSString stringWithFormat:@".%@",url.pathExtension];
        inputString = [[url path] stringByReplacingOccurrencesOfString:replaceString withString:[NSString stringWithFormat:@"_1.%@",url.pathExtension] options:NSBackwardsSearch range:NSMakeRange([url path].length - replaceString.length, replaceString.length)];
    }
    if (inputString.length == 0) {
        inputString = @"";
    }
    
    if (self.segmentedControl.selectedSegment == 0) {
        self.secondField.stringValue = inputString;
    } else {
        self.thirdField.stringValue = inputString;
    }
    
}

// 转换
#pragma mark - ########## 1 ################

- (void)convertVideo:(NSString *)videoPath savePath:(NSString *)savePath completeHandler:(void (^)(BOOL success))completeHandler
{
    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:videoPath]];
    AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    CGSize originalSize = clipVideoTrack.naturalSize;
    CGSize cropSize = CGSizeMake(852.0, 480.0);
    NSLog(@"originalSize:%@\ncropSize:%@",NSStringFromSize(originalSize),NSStringFromSize(cropSize));
    
    // 架构图层，给定轨道的变换，裁剪和不透明度等等
    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:clipVideoTrack];
    CGAffineTransform transform = [self transformWithAssetTrack:clipVideoTrack cropSize:cropSize];
    [layerInstruction setTransform:transform atTime:kCMTimeZero];
    
    // 维护一组指令以执行其组合
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    // 指定应如何分层和组合源轨道的视频帧。 轨道根据layerInstructions数组的从上到下的顺序在组合中分层
    instruction.layerInstructions = [NSArray arrayWithObject:layerInstruction];
    
    AVMutableVideoComposition* videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.frameDuration = CMTimeMake(1, 15);// 15帧/s
    videoComposition.renderSize = cropSize;
    videoComposition.instructions = [NSArray arrayWithObject:instruction];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
    }
    self.assetExportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPreset960x540];
    [self.assetExportSession setVideoComposition:videoComposition];
    [self.assetExportSession setOutputURL:[NSURL fileURLWithPath:savePath]];
    [self.assetExportSession setOutputFileType:AVFileTypeQuickTimeMovie];
    [self.assetExportSession setShouldOptimizeForNetworkUse:YES];
    [self.assetExportSession exportAsynchronouslyWithCompletionHandler:^(void){
        if(self.assetExportSession.status ==AVAssetExportSessionStatusCompleted)
        {
            NSLog(@"compress video success");
            if(completeHandler)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completeHandler(YES);
                });
                
            }
        }
        else
        {
            NSLog(@"compress video fail");
            if(completeHandler)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completeHandler(NO);
                });
            }
        }
    }];
}

// 垂直方向视频，黑色部分使用模糊填充
- (void)convertBlurVideo:(NSString *)videoPath savePath:(NSString *)savePath completeHandler:(void (^)(BOOL success))completeHandler
{
    AVMutableComposition *mixComposition = [AVMutableComposition composition];
    
    // create first track
    AVAsset *firstAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:videoPath]];
    AVAssetTrack *firstVideoTrack = [[firstAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    AVMutableCompositionTrack *compositionTrack =
    [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                preferredTrackID:kCMPersistentTrackID_Invalid]; // video类型
    
    // insertTimeRange:插入的时间range; atTime:kctimerzero（就是从0秒开始）
    [compositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, firstAsset.duration)
                        ofTrack:firstVideoTrack
                         atTime:kCMTimeZero
                          error:nil];
    
    CGSize cropSize = CGSizeMake(852.0, 480.0);
    // 架构图层，给定轨道的变换，裁剪和不透明度等等
    AVMutableVideoCompositionLayerInstruction *firstLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionTrack];
    CGAffineTransform transform = [self transformWithAssetTrack:firstVideoTrack cropSize:cropSize];
    [firstLayerInstruction setTransform:transform atTime:kCMTimeZero];
    
    AVMutableVideoCompositionLayerInstruction *secondLayerInstruction = [self leftLayerInstruction:mixComposition assetTrack:firstVideoTrack cropSize:cropSize];
    AVMutableVideoCompositionLayerInstruction *thirdLayerInstruction = [self rightLayerInstruction:mixComposition assetTrack:firstVideoTrack cropSize:cropSize];
    
    // 维护一组指令以执行其组合
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, firstAsset.duration);
    // 指定应如何分层和组合源轨道的视频帧。 轨道根据layerInstructions数组的从上到下的顺序在组合中分层
    instruction.layerInstructions = [NSArray arrayWithObjects:firstLayerInstruction,secondLayerInstruction,thirdLayerInstruction,nil];
    
    
    // create first track
    AVAsset *audioAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:videoPath]];
    AVMutableCompositionTrack *audioTrack =
    [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
                                preferredTrackID:kCMPersistentTrackID_Invalid]; // video类型
    
    // insertTimeRange:插入的时间range; atTime:kctimerzero（就是从0秒开始）
    [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, firstAsset.duration)
                        ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                         atTime:kCMTimeZero
                          error:nil];
    //开始截取audio
    AVMutableAudioMix *exportAudioMix = [AVMutableAudioMix audioMix];
    AVMutableAudioMixInputParameters *exportAudioMixInputParameters =
    [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioTrack];
    exportAudioMix.inputParameters = [NSArray arrayWithObjects:exportAudioMixInputParameters, nil];
    
    
    AVMutableVideoComposition* videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.frameDuration = CMTimeMake(1, 15);// 15帧/s
    videoComposition.renderSize = cropSize;
    videoComposition.instructions = [NSArray arrayWithObject:instruction];
    if (secondLayerInstruction || thirdLayerInstruction) {
        CALayer *videoLayer = [CALayer layer];
        videoLayer.frame = CGRectMake(0, 0, cropSize.width, cropSize.height);
        CALayer *parentLayer = [CALayer layer];
        parentLayer.frame = CGRectMake(0, 0, cropSize.width, cropSize.height);
        [parentLayer addSublayer:videoLayer];
        
        // Add filter
        CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur" keysAndValues:@"inputRadius", @5.0, nil];
        
        CALayer *leftLayer = [CALayer layer];
        leftLayer.frame = CGRectMake(0, 0, (cropSize.width - cropSize.height)*0.5, cropSize.height);
        leftLayer.backgroundFilters = @[filter];
        leftLayer.masksToBounds = YES;
        [parentLayer addSublayer:leftLayer];
        
        CALayer *rightLayer = [CALayer layer];
        rightLayer.frame = CGRectMake(cropSize.width - (cropSize.width - cropSize.height)*0.5, 0, (cropSize.width - cropSize.height)*0.5, cropSize.height);
        rightLayer.backgroundFilters = @[filter];
        rightLayer.masksToBounds = YES;
        [parentLayer addSublayer:rightLayer];
        
        videoComposition.animationTool = [AVVideoCompositionCoreAnimationTool
                                        videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    }
    
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
    }
    self.assetExportSession = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    [self.assetExportSession setVideoComposition:videoComposition];
    [self.assetExportSession setOutputURL:[NSURL fileURLWithPath:savePath]];
    [self.assetExportSession setOutputFileType:AVFileTypeQuickTimeMovie];
    [self.assetExportSession setAudioMix:exportAudioMix];
    [self.assetExportSession setShouldOptimizeForNetworkUse:YES];
    [self.assetExportSession exportAsynchronouslyWithCompletionHandler:^(void){
        if(self.assetExportSession.status ==AVAssetExportSessionStatusCompleted)
        {
            NSLog(@"compress video success");
            if(completeHandler)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completeHandler(YES);
                });
                
            }
        }
        else
        {
            NSLog(@"compress video fail");
            if(completeHandler)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completeHandler(NO);
                });
            }
        }
    }];
}

- (CGAffineTransform)transformWithAssetTrack:(AVAssetTrack *)assetTrack cropSize:(CGSize)cropSize
{
    CGSize originalSize = assetTrack.naturalSize;
    CGFloat ratio = cropSize.height/(MIN(originalSize.width, originalSize.height));
    float degress = 0;
    CGAffineTransform t = assetTrack.preferredTransform;
    if (t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0) {
        // Portrait 垂直方向
        degress = 90;
        CGAffineTransform roateTransform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI * degress/180.0); // 顺时针旋转
        CGAffineTransform translateTransform = CGAffineTransformTranslate(roateTransform,-(cropSize.width - cropSize.height)*0.5, -cropSize.height-(cropSize.width - cropSize.height)*0.5);// 居中
        CGAffineTransform scaleTransform = CGAffineTransformScale(translateTransform, ratio, ratio); // 缩放
        return scaleTransform;
    } else if(t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0) {
        // PortraitUpsideDown 倒立
        degress = 270;
        CGAffineTransform roateTransform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI * degress/180.0); // 顺时针旋转
        CGAffineTransform translateTransform = CGAffineTransformTranslate(roateTransform,-cropSize.width+(cropSize.width - cropSize.height)*0.5, (cropSize.width - cropSize.height)*0.5);// 居中
        CGAffineTransform scaleTransform = CGAffineTransformScale(translateTransform, ratio, ratio); // 缩放
        return scaleTransform;
        
    } else if(t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0) {
        // LandscapeRight // 水平
        degress = 0;
        if (originalSize.width <= originalSize.height) {
            CGAffineTransform translateTransform = CGAffineTransformTranslate(CGAffineTransformIdentity,(cropSize.width - cropSize.height)*0.5, 0);// 居中
            CGAffineTransform scaleTransform = CGAffineTransformScale(translateTransform, ratio, ratio); // 缩放
            return scaleTransform;
        } else {
            CGAffineTransform scaleTransform = CGAffineTransformScale(CGAffineTransformIdentity, ratio, ratio); // 缩放
            return scaleTransform;
        }
    } else if(t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0) {
        // LandscapeLeft
        degress = 180;
        CGAffineTransform roateTransform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI * degress/180.0); // 顺时针旋转
        CGAffineTransform translateTransform = CGAffineTransformTranslate(roateTransform, -cropSize.width, -cropSize.height);
        CGAffineTransform scaleTransform = CGAffineTransformScale(translateTransform, ratio, ratio); // 缩放
        return scaleTransform;
    }
    return CGAffineTransformIdentity;
}

- (AVMutableVideoCompositionLayerInstruction *)leftLayerInstruction:(AVMutableComposition *)mixComposition assetTrack:(AVAssetTrack *)assetTrack cropSize:(CGSize)cropSize
{
    CGSize originalSize = assetTrack.naturalSize;
    CGFloat ratio = cropSize.height/(MIN(originalSize.width, originalSize.height));
    CGAffineTransform t = assetTrack.preferredTransform;
    float degress = 0;
    if (t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0) { // Portrait 垂直方向
        degress = 90;
        CGAffineTransform roateTransform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI * degress/180.0); // 绕左上角逆时针旋转
        CGAffineTransform translateTransform = CGAffineTransformTranslate(roateTransform,-(cropSize.width - cropSize.height)*0.5, -cropSize.height);// 居左
        CGAffineTransform scaleTransform = CGAffineTransformScale(translateTransform, ratio, ratio); // 缩放
        
        // create first track
        AVMutableCompositionTrack *compositionTrack =
        [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                    preferredTrackID:kCMPersistentTrackID_Invalid]; // video类型
        
        // insertTimeRange:插入的时间range; atTime:kctimerzero（就是从0秒开始）
        [compositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, assetTrack.asset.duration)
                                  ofTrack:assetTrack
                                   atTime:kCMTimeZero
                                    error:nil];
        // 架构图层，给定轨道的变换，裁剪和不透明度等等
        AVMutableVideoCompositionLayerInstruction *firstLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionTrack];
        [firstLayerInstruction setTransform:scaleTransform atTime:kCMTimeZero];
        return firstLayerInstruction;
        
    } else if (t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0) {
        degress = 270;
        CGAffineTransform roateTransform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI * degress/180.0); // 绕左上角逆时针旋转
        CGAffineTransform translateTransform = CGAffineTransformTranslate(roateTransform,-cropSize.width+(cropSize.width - cropSize.height)*0.5, 0);// 居左
        CGAffineTransform scaleTransform = CGAffineTransformScale(translateTransform, ratio, ratio); // 缩放
        
        // create first track
        AVMutableCompositionTrack *compositionTrack =
        [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                    preferredTrackID:kCMPersistentTrackID_Invalid]; // video类型
        
        // insertTimeRange:插入的时间range; atTime:kctimerzero（就是从0秒开始）
        [compositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, assetTrack.asset.duration)
                                  ofTrack:assetTrack
                                   atTime:kCMTimeZero
                                    error:nil];
        // 架构图层，给定轨道的变换，裁剪和不透明度等等
        AVMutableVideoCompositionLayerInstruction *firstLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionTrack];
        [firstLayerInstruction setTransform:scaleTransform atTime:kCMTimeZero];
        return firstLayerInstruction;
        
    } else if (t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0) {
        degress = 0;
        if (originalSize.width <= originalSize.height) {
            CGAffineTransform scaleTransform = CGAffineTransformScale(CGAffineTransformIdentity, ratio, ratio); // 缩放
            
            // create first track
            AVMutableCompositionTrack *compositionTrack =
            [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                        preferredTrackID:kCMPersistentTrackID_Invalid]; // video类型
            
            // insertTimeRange:插入的时间range; atTime:kctimerzero（就是从0秒开始）
            [compositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, assetTrack.asset.duration)
                                      ofTrack:assetTrack
                                       atTime:kCMTimeZero
                                        error:nil];
            // 架构图层，给定轨道的变换，裁剪和不透明度等等
            AVMutableVideoCompositionLayerInstruction *firstLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionTrack];
            [firstLayerInstruction setTransform:scaleTransform atTime:kCMTimeZero];
            return firstLayerInstruction;
        } else {
            return nil;
        }
    }
    return nil;
}

- (AVMutableVideoCompositionLayerInstruction *)rightLayerInstruction:(AVMutableComposition *)mixComposition assetTrack:(AVAssetTrack *)assetTrack cropSize:(CGSize)cropSize
{
    CGSize originalSize = assetTrack.naturalSize;
    CGFloat ratio = cropSize.height/(MIN(originalSize.width, originalSize.height));
    CGAffineTransform t = assetTrack.preferredTransform;
    float degress = 0;
    if (t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0) { // Portrait 垂直方向
        degress = 90;
        CGAffineTransform roateTransform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI * degress/180.0); // 绕左上角逆时针旋转
        CGAffineTransform translateTransform = CGAffineTransformTranslate(roateTransform,-(cropSize.width - cropSize.height)*0.5, -cropSize.width);// 居右
        CGAffineTransform scaleTransform = CGAffineTransformScale(translateTransform, ratio, ratio); // 缩放
        
        // create first track
        AVMutableCompositionTrack *compositionTrack =
        [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                    preferredTrackID:kCMPersistentTrackID_Invalid]; // video类型
        
        // insertTimeRange:插入的时间range; atTime:kctimerzero（就是从0秒开始）
        [compositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, assetTrack.asset.duration)
                                  ofTrack:assetTrack
                                   atTime:kCMTimeZero
                                    error:nil];
        // 架构图层，给定轨道的变换，裁剪和不透明度等等
        AVMutableVideoCompositionLayerInstruction *firstLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionTrack];
        [firstLayerInstruction setTransform:scaleTransform atTime:kCMTimeZero];
        return firstLayerInstruction;
        
    } else if (t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0) {
        degress = 270;
        CGAffineTransform roateTransform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI * degress/180.0); // 绕左上角逆时针旋转
        CGAffineTransform translateTransform = CGAffineTransformTranslate(roateTransform,-cropSize.width+(cropSize.width - cropSize.height)*0.5, cropSize.width - cropSize.height);// 居右
        CGAffineTransform scaleTransform = CGAffineTransformScale(translateTransform, ratio, ratio); // 缩放
        
        // create first track
        AVMutableCompositionTrack *compositionTrack =
        [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                    preferredTrackID:kCMPersistentTrackID_Invalid]; // video类型
        
        // insertTimeRange:插入的时间range; atTime:kctimerzero（就是从0秒开始）
        [compositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, assetTrack.asset.duration)
                                  ofTrack:assetTrack
                                   atTime:kCMTimeZero
                                    error:nil];
        // 架构图层，给定轨道的变换，裁剪和不透明度等等
        AVMutableVideoCompositionLayerInstruction *firstLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionTrack];
        [firstLayerInstruction setTransform:scaleTransform atTime:kCMTimeZero];
        return firstLayerInstruction;
    } else if (t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0){
        degress = 0;
        if (originalSize.width <= originalSize.height) {
            CGAffineTransform translateTransform = CGAffineTransformTranslate(CGAffineTransformIdentity,cropSize.width - cropSize.height, 0);// 居中
            CGAffineTransform scaleTransform = CGAffineTransformScale(translateTransform, ratio, ratio); // 缩放
            
            
            // create first track
            AVMutableCompositionTrack *compositionTrack =
            [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                        preferredTrackID:kCMPersistentTrackID_Invalid]; // video类型
            
            // insertTimeRange:插入的时间range; atTime:kctimerzero（就是从0秒开始）
            [compositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, assetTrack.asset.duration)
                                      ofTrack:assetTrack
                                       atTime:kCMTimeZero
                                        error:nil];
            // 架构图层，给定轨道的变换，裁剪和不透明度等等
            AVMutableVideoCompositionLayerInstruction *firstLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionTrack];
            [firstLayerInstruction setTransform:scaleTransform atTime:kCMTimeZero];
            return firstLayerInstruction;
        } else {
            return nil;
        }
    }
    return nil;
}

#pragma mark - ########## 2 ################

- (void)compostionFirstVideo:(NSString *)firstVideoPath secondVideo:(NSString *)secondVideoPath finalVideoPath:(NSString *)finalVideoPath completeHandler:(void (^)(BOOL success))completeHandler;
{
    AVMutableComposition *mixComposition =  [AVMutableComposition composition];
    
    // create first track
    AVAsset *firstAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:firstVideoPath]];
    AVMutableCompositionTrack *firstTrack =
    [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                preferredTrackID:kCMPersistentTrackID_Invalid]; // video类型
    
    // insertTimeRange:插入的时间range; atTime:kctimerzero（就是从0秒开始）
    [firstTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, firstAsset.duration)
                        ofTrack:[[firstAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                         atTime:kCMTimeZero
                          error:nil];
    
    // 第一个视频的架构层
    float animateDuration = 0.5; // 两个视频切换时间
    AVMutableVideoCompositionLayerInstruction *firstlayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:firstTrack];
    [firstlayerInstruction setTransformRampFromStartTransform:CGAffineTransformIdentity toEndTransform:CGAffineTransformMakeTranslation(-firstTrack.naturalSize.width, 0) timeRange:CMTimeRangeMake(CMTimeMake(firstAsset.duration.value - firstAsset.duration.timescale*animateDuration, firstAsset.duration.timescale),CMTimeMake(firstAsset.duration.timescale*animateDuration, firstAsset.duration.timescale))];
    // [firstlayerInstruction setOpacity:0.0 atTime:firstAsset.duration]; // 播放完毕设置透明度为0
    
    // create second track
    AVAsset *secondAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:secondVideoPath]];
    AVMutableCompositionTrack *secondTrack =
    [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                preferredTrackID:kCMPersistentTrackID_Invalid]; // video类型
    // 1.atTime:kCMTimeZero,这里是把两个视频叠加的效果。
    // 2.atTime:firstAsset.duration,这里是视频推进的效果(前一个视频播放完毕继续第二个视频)
    [secondTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, secondAsset.duration)
                        ofTrack:[[secondAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                         atTime:CMTimeMake(firstAsset.duration.value - firstAsset.duration.timescale*animateDuration, firstAsset.duration.timescale)
                          error:nil];
    
    // 第二个视频的架构层
    AVMutableVideoCompositionLayerInstruction *secondlayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:secondTrack];
    [secondlayerInstruction setTransformRampFromStartTransform:CGAffineTransformMakeTranslation(firstTrack.naturalSize.width, 0) toEndTransform:CGAffineTransformIdentity timeRange:CMTimeRangeMake(CMTimeMake(firstAsset.duration.value - firstAsset.duration.timescale*animateDuration, firstAsset.duration.timescale),CMTimeMake(firstAsset.duration.timescale*animateDuration, firstAsset.duration.timescale))];
    
    AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    // 这个地方你把数组顺序倒一下，第一种情况：视频播放顺序变了;第二种情况：视频上下位置也跟着变了。
    mainInstruction.layerInstructions = [NSArray arrayWithObjects:firstlayerInstruction,secondlayerInstruction, nil];
    mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero,CMTimeAdd(firstAsset.duration, secondAsset.duration));
    
    AVMutableVideoComposition *mainComposition = [AVMutableVideoComposition videoComposition];
    mainComposition.instructions = [NSArray arrayWithObjects:mainInstruction,nil];
    mainComposition.frameDuration = CMTimeMake(1, 15);// 15帧/s
    mainComposition.renderSize = firstTrack.naturalSize; // 视频宽高
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:finalVideoPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:finalVideoPath error:nil];
    }
    self.assetExportSession = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    [self.assetExportSession setVideoComposition:mainComposition];
    [self.assetExportSession setOutputURL:[NSURL fileURLWithPath:finalVideoPath]];
    [self.assetExportSession setOutputFileType:AVFileTypeQuickTimeMovie];
    [self.assetExportSession setShouldOptimizeForNetworkUse:YES];
    // 合成视频
    [self.assetExportSession exportAsynchronouslyWithCompletionHandler:^(void){
        if(self.assetExportSession.status ==AVAssetExportSessionStatusCompleted)
        {
            NSLog(@"compress video success");
            if(completeHandler)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completeHandler(YES);
                });
                
            }
        }
        else
        {
            NSLog(@"compress video fail");
            if(completeHandler)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completeHandler(NO);
                });
            }
        }
    }];
}

#pragma mark - ########## 3 ################

- (void)compressVideoPath:(NSString *)videoPath andAudio:(NSString *)audioPath finalVideoPath:(NSString*)finalVideoPath completeHandler:(void (^)(BOOL success))completeHandler
{
    //下面两句是分别取得视频和声音文件的url，以供合成用。
    AVAsset *videoAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:videoPath]];
    AVAsset *sourceAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:audioPath]];
    
    Float32 audioDuration = CMTimeGetSeconds([sourceAsset duration]);
    
    Float32 startPoint = 0.0;
    Float32 endPoint = startPoint + CMTimeGetSeconds([videoAsset duration]);
    if(endPoint > audioDuration){
        endPoint = audioDuration;
    }
    
    // get the first audio track
    NSArray *tracks = [sourceAsset tracksWithMediaType:AVMediaTypeAudio];
    if ([tracks count] == 0)
    {
        fprintf(stderr, "audio tranks count zero!\n");
        if(completeHandler)
        {
            completeHandler(NO);
        }
        return;
    }
    
    CMTime startTime = CMTimeMake((int)(floor(startPoint * 100)), 100);
    CMTime stopTime = CMTimeMake((int)(ceil(endPoint * 100)), 100);
    CMTimeRange exportTimeRange = CMTimeRangeFromTimeToTime(startTime, stopTime);
    
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionAudioTrack insertTimeRange:exportTimeRange
                                   ofTrack:[tracks objectAtIndex:0]
                                    atTime:kCMTimeZero
                                     error:nil];
    
    /*****结束的fade时间区间******/
    float fade = 2.0;
    Float32 startFadeOut = endPoint - fade;
    if (startFadeOut < 0) {
        startFadeOut = 0;
    }
    CMTime startFadeOutTime = CMTimeMake((int)(floor(startFadeOut * 100)), 100);
    CMTime endFadeOutTime = CMTimeMake((int)(ceil(endPoint * 100)), 100);
    CMTimeRange fadeOutTimeRange = CMTimeRangeFromTimeToTime(startFadeOutTime, endFadeOutTime);
    
    //开始截取audio
    AVMutableAudioMix *exportAudioMix = [AVMutableAudioMix audioMix];
    AVMutableAudioMixInputParameters *exportAudioMixInputParameters =
    [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compositionAudioTrack];
    if (endPoint - startPoint > fade)
    {
        //不知为何会卡死
        [exportAudioMixInputParameters setVolumeRampFromStartVolume:1.0 toEndVolume:0.0 timeRange:fadeOutTimeRange];
    }
    exportAudioMix.inputParameters = [NSArray arrayWithObjects:exportAudioMixInputParameters, nil];
    
    
    //下面就是合成的过程了。
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, videoAsset.duration);
    NSArray* videoTracks = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
    if ([videoTracks count] == 0)
    {
        fprintf(stderr, "video tranks count zero!\n");
        if(completeHandler)
        {
            completeHandler(NO);
        }
        return;
    }
    [compositionVideoTrack insertTimeRange:timeRange
                                   ofTrack:[videoTracks objectAtIndex:0]
                                    atTime:kCMTimeZero
                                     error:nil];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:finalVideoPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:finalVideoPath error:nil];
    }
    self.assetExportSession = [[AVAssetExportSession alloc]initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    self.assetExportSession.outputFileType = AVFileTypeMPEG4;// 生成视频格式
    self.assetExportSession.outputURL = [NSURL fileURLWithPath:finalVideoPath];; // 生成的视频路径
    self.assetExportSession.audioMix = exportAudioMix;
    [self.assetExportSession exportAsynchronouslyWithCompletionHandler:^(void){
        if(self.assetExportSession.status ==AVAssetExportSessionStatusCompleted)
        {
            NSLog(@"compress video success");
            if(completeHandler)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completeHandler(YES);
                });
                
            }
        }
        else
        {
            NSLog(@"compress video fail");
            if(completeHandler)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completeHandler(NO);
                });
            }
        }
     }];
}

@end
