//
//  ZegoLiveViewController.m
//  LiveDemo2
//
//  Created by Randy Qiu on 4/10/16.
//  Copyright © 2016 Zego. All rights reserved.
//

#import "ZegoLiveViewController.h"
#import "ZegoAVKitManager.h"
#import "ZegoSettingViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ZegoDemoAnchorCongif : NSObject

@property BOOL enableBeautify;
@property BOOL enableMic;
@property BOOL useFrontCamera;
@property NSInteger filterIndex;

@end

@implementation ZegoDemoAnchorCongif

- (instancetype)init {
    self = [super init];
    if (self) {
        _enableMic = YES;
        _useFrontCamera = NO;
        _enableBeautify = NO;
    }
    
    return self;
}

@end


const NSString *kZegoDemoViewTypeKey  = @"type";    ///< 1 - publish view, 2 -  play view
const NSString *kZegoDemoVideoViewKey = @"view";                                                                                                                                                                                                                                                                                                                        
const NSString *kZegoDemoViewIndexKey = @"view_idx";
const NSString *kZegoDemoStreamIDKey  = @"stream_id";


@interface ZegoLiveViewController () <ZegoLiveApiDelegate>
@property (weak, nonatomic) IBOutlet UIButton *btnEnableBeautify;
@property (weak, nonatomic) IBOutlet UIButton *btnFrontCamera;
@property (weak, nonatomic) IBOutlet UIButton *btnEnableMic;
@property (weak, nonatomic) IBOutlet UIButton *btnJoin;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *anchorToolBoxHeightConstrait;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *statusBoxHeightConstraint;

@property (weak, nonatomic) IBOutlet UIPickerView *filterPicker;

@property (weak, nonatomic) IBOutlet UIView *bigView;
@property (weak, nonatomic) IBOutlet UIView *smallView;
@property (weak, nonatomic) IBOutlet UILabel *liveIDField;
@property (weak, nonatomic) IBOutlet UIView *anchorToolBox;
@property (weak, nonatomic) IBOutlet UILabel *liveStatus;
@property (weak, nonatomic) IBOutlet UILabel *liveInfo;

@property (weak, nonatomic) IBOutlet UIButton *btnShowFilter;

@property (weak, nonatomic) IBOutlet UIView *audienceBox;
@property (weak, nonatomic) IBOutlet UITextField *playStreamID;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *statusBoxBottemSpaceConstraint;

@property (readonly) NSArray *filterList;

@property (strong) UITapGestureRecognizer *smallViewTapGestureRecognizer;

@property (nonatomic) BOOL isPublishing;
@property BOOL isPlaying;
@property BOOL isPreviewOn;
@property (nonatomic) BOOL isLogin;

@property NSMutableArray<NSDictionary *> *videoViewInfo;

@end

@implementation ZegoLiveViewController
{
    ZegoDemoAnchorCongif *_anchorConfig;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    _anchorConfig = [[ZegoDemoAnchorCongif alloc] init];
    [self setupAnchorToolBox];
    
    _filterList = @[
                    @"无滤镜",
                    @"简洁",
                    @"黑白",
                    @"老化",
                    @"哥特",
                    @"锐色",
                    @"淡雅",
                    @"酒红",
                    @"青柠",
                    @"浪漫",
                    @"光晕",
                    @"蓝调",
                    @"梦幻",
                    @"夜色"
                    ];
    
    [self setupLiveKit];
    
    if (self.isLogin) {
        assert(false);
        return;
    }
    
    bool ret = false;
    
    ZegoUser *user = [self userInfo];
    ret = [getZegoAV_ShareInstance() loginChannel:self.liveChannel user:user];
    
    assert(ret);
    NSLog(@"%s, ret: %d", __func__, ret);
    
    self.smallView.hidden = YES;
    _videoViewInfo = [NSMutableArray array];
    self.anchorToolBox.hidden = YES;
 
    [self toggleStatusBox:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardWillDismiss:) name:UIKeyboardWillHideNotification object:nil];
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    if (!self.smallViewTapGestureRecognizer) {
        self.smallViewTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSmallViewTap:)];
    }
    [self.smallView addGestureRecognizer:self.smallViewTapGestureRecognizer];
    
     [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
}

- (void)handleAudioSessionInterruption:(NSNotification *)notification {
    if ([notification.userInfo count] == 0) {
        return;
    }
    
    if (self.videoViewInfo.count == 0) {
        return;
    }
    
    AVAudioSessionInterruptionType type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
    
    if (AVAudioSessionInterruptionTypeBegan == type) {
        NSLog(@"audioSessionWasInterrupted Begin");
        [self leave:nil];
    } else if(AVAudioSessionInterruptionTypeEnded == type) {
        NSLog(@"audioSessionWasInterrupted End");
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [self.smallView removeGestureRecognizer:self.smallViewTapGestureRecognizer];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    [super viewWillDisappear:animated];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    switch (self.interfaceOrientation) {
        case UIInterfaceOrientationPortrait:
            [getZegoAV_ShareInstance() setCaptureRotation:CAPTURE_ROTATE_0];
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
            [getZegoAV_ShareInstance() setCaptureRotation:CAPTURE_ROTATE_180];
            break;
            
        case UIInterfaceOrientationLandscapeLeft:
            [getZegoAV_ShareInstance() setCaptureRotation:CAPTURE_ROTATE_90];
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            [getZegoAV_ShareInstance() setCaptureRotation:CAPTURE_ROTATE_270];
            break;
            
        default:
            break;
    }
}

- (void)handleSmallViewTap:(NSNotification *)notification {
    [self switchVideoView];
}


- (void)switchVideoView {
    ZegoLiveApi *api = getZegoAV_ShareInstance();
    
    if (self.videoViewInfo.count == 2) {
        NSMutableDictionary *firstViewInfo = [self.videoViewInfo[0] mutableCopy];
        NSInteger firstViewType = [firstViewInfo[kZegoDemoViewTypeKey] integerValue];
        NSInteger firstViewIndex = [firstViewInfo[kZegoDemoViewIndexKey] integerValue];
        UIView *firstView = firstViewInfo[kZegoDemoVideoViewKey];
        
        
        NSMutableDictionary *secondViewInfo = [self.videoViewInfo[1] mutableCopy];
        NSInteger secondViewType = [secondViewInfo[kZegoDemoViewTypeKey] integerValue];
        NSInteger secondViewIndex = [secondViewInfo[kZegoDemoViewIndexKey] integerValue];
        UIView *secondView = secondViewInfo[kZegoDemoVideoViewKey];
        
        if (firstViewType == 1) {
            [api setLocalView:nil];
            [api setRemoteView:(RemoteViewIndex)secondViewIndex view:nil];
            
            [api setLocalView:secondView];
            [api setRemoteView:(RemoteViewIndex)secondViewIndex view:firstView];
        } else if (secondViewType == 1) {
            [api setLocalView:nil];
            [api setRemoteView:(RemoteViewIndex)firstViewIndex view:nil];
            
            [api setLocalView:firstView];
            [api setRemoteView:(RemoteViewIndex)firstViewIndex view:secondView];
        } else {
            [api setRemoteView:(RemoteViewIndex)firstViewIndex view:nil];
            [api setRemoteView:(RemoteViewIndex)secondViewIndex view:nil];
            
            [api setRemoteView:(RemoteViewIndex)secondViewIndex view:firstView];
            [api setRemoteView:(RemoteViewIndex)firstViewIndex view:secondView];
        }
        
        firstViewInfo[kZegoDemoVideoViewKey] = secondView;
        secondViewInfo[kZegoDemoVideoViewKey] = firstView;
        
        [self.videoViewInfo removeAllObjects];
        [self.videoViewInfo addObject:firstViewInfo];
        [self.videoViewInfo addObject:secondViewInfo];
    }
}

- (void)setupAnchorToolBox {
    
    UIColor *hightlightedBGColor = [[UIColor alloc] initWithRed:92.0/255 green:211.0/255 blue:255.0/255 alpha:0.5];
    
    self.btnEnableBeautify.backgroundColor = _anchorConfig.enableBeautify ? hightlightedBGColor : [UIColor clearColor];
    self.btnEnableMic.backgroundColor = _anchorConfig.enableMic ? hightlightedBGColor : [UIColor clearColor];
    self.btnFrontCamera.backgroundColor = _anchorConfig.useFrontCamera ? hightlightedBGColor : [UIColor clearColor];
}


- (IBAction)leave:(id)sender {
    
    if (self.isPublishing) {
        [getZegoAV_ShareInstance() stopPublishing];
    }

    [getZegoAV_ShareInstance() logoutChannel];
    
    // 主动发起的操作，正常关闭
    [ZegoSettings sharedInstance].publishingStreamID = @"";
    [ZegoSettings sharedInstance].publishingLiveChannel = @"";
    
    [self dismissViewControllerAnimated:YES completion:^{
        releaseZegoAV_ShareInstance();
    }];
}

- (IBAction)switchCamera:(id)sender {
    _anchorConfig.useFrontCamera = !_anchorConfig.useFrontCamera;
    [getZegoAV_ShareInstance() setFrontCam:_anchorConfig.useFrontCamera];
    [self setupAnchorToolBox];
}

- (IBAction)toggleMic:(id)sender {
    _anchorConfig.enableMic = !_anchorConfig.enableMic;
    [getZegoAV_ShareInstance() enableMic:_anchorConfig.enableMic];
    [self setupAnchorToolBox];
}

- (IBAction)toggleTorch:(id)sender {
    static bool on = false;
    [getZegoAV_ShareInstance() enableTorch:on];
    on = !on;
    
    [getZegoAV_ShareInstance() takeLocalViewSnapshot];
    [getZegoAV_ShareInstance() takeRemoteViewSnapshot:RemoteViewIndex_First];
}


- (IBAction)enableBeautify:(id)sender {
    _anchorConfig.enableBeautify = !_anchorConfig.enableBeautify;
    [getZegoAV_ShareInstance() enableBeautifying:_anchorConfig.enableBeautify];
    [self setupAnchorToolBox];
}

- (IBAction)toggleFilterPicker:(id)sender {
    if (self.anchorToolBoxHeightConstrait.constant == 183) {
        self.anchorToolBoxHeightConstrait.constant = 48;
        self.filterPicker.hidden = YES;
        [self.btnShowFilter setImage:[UIImage imageNamed:@"expand_more"] forState:UIControlStateNormal];
    } else {
        self.anchorToolBoxHeightConstrait.constant = 183;
        self.filterPicker.hidden = NO;
        [self.btnShowFilter setImage:[UIImage imageNamed:@"expand_less"] forState:UIControlStateNormal];
    }
    
    [UIView animateWithDuration:0.1 animations:^{
        [self.view layoutIfNeeded];
    }];
    
    [self.view setNeedsDisplay];
}

- (IBAction)toggleStatusBox:(id)sender {
    if (self.statusBoxHeightConstraint.constant == 32) {
        self.statusBoxHeightConstraint.constant = 100;
        self.liveInfo.hidden = NO;
        [self updateLiveStatus];
    } else {
        self.statusBoxHeightConstraint.constant = 32;
        self.liveInfo.hidden = YES;
    }
    
    [UIView animateWithDuration:0.1 animations:^{
        [self.view layoutIfNeeded];
    }];
    
    [self.view setNeedsDisplay];
}

- (IBAction)stopAnchor:(id)sender {
    if (!self.isPublishing) {
        assert(false);
        return;
    }
    
    [getZegoAV_ShareInstance() stopPublishing];
}

- (void)updateLiveStatus {    
    NSMutableString *status = [NSMutableString string];
    for (NSDictionary *viewInfo in self.videoViewInfo) {
        if (status.length > 0) {
            [status appendString:@"\n"];
        }

        if ([viewInfo[kZegoDemoViewTypeKey] isEqual:@(1)]) {
            NSDictionary *publishInfo = [getZegoAV_ShareInstance() currentPublishInfo];
            NSString *streamID = publishInfo[kZegoPublishStreamIDKey];
            [status appendString:[NSString stringWithFormat:@"[publish]: %@", streamID]];
        } else {
            [status appendString:[NSString stringWithFormat:@"[play]: %@", viewInfo[kZegoDemoStreamIDKey]]];
        }
    }
    
    self.liveInfo.text = status;
}


- (NSDictionary *)videoViewInfoOfStream:(NSString *)streamID {
    __block NSDictionary *info = nil;
    [self.videoViewInfo enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj[kZegoDemoStreamIDKey] isEqualToString:streamID]) {
            info = obj;
            *stop = YES;
        }
    }];
    
    return info;
}


- (NSDictionary *)playingVideoViewInfo {
    __block NSDictionary *info = nil;
    [self.videoViewInfo enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj[kZegoDemoViewTypeKey] isEqual:@(2)]) {
            info = obj;
            *stop = YES;
        }
    }];
    
    return info;
}

- (IBAction)togglePublish:(id)sender {
    
    if (self.isPublishing) {
        [getZegoAV_ShareInstance() stopPublishing];
    } else if (self.videoViewInfo.count < 2) {
        bool ret = [getZegoAV_ShareInstance() startPublishingWithTitle:self.liveTitle streamID:[self publishStreamID]];
        NSLog(@"%s, ret: %d", __func__, ret);
        
        self.btnJoin.enabled = NO;
    }
}

- (IBAction)playExtractStream:(id)sender {
    NSString *streamID = self.playStreamID.text;
    if (streamID.length > 0) {
        
        if ([self videoViewInfoOfStream:streamID]) {
            NSLog(@"%s, %@ is being play.", __func__, streamID);
            return;
        }

        RemoteViewIndex viewIndex = RemoteViewIndex_First;
        UIView *videoView = nil;
        
        if (self.videoViewInfo.count == 2) {
            NSDictionary *info = [self playingVideoViewInfo];
            
            viewIndex = (RemoteViewIndex)[info[kZegoDemoViewIndexKey] integerValue];
            videoView = info[kZegoDemoVideoViewKey];
            
            NSString *playingStreamID = info[kZegoDemoStreamIDKey];
            [getZegoAV_ShareInstance() stopPlayStream:playingStreamID];
            
            [self.videoViewInfo removeObject:info];
        } else if (self.videoViewInfo.count == 1) {
            if (self.isPublishing) {
                viewIndex = RemoteViewIndex_First;
            } else {
                NSDictionary *info = self.videoViewInfo[0];
                if ([info[kZegoDemoStreamIDKey] isEqualToString:streamID]) {
                    
                }
                
                if ([info[kZegoDemoViewIndexKey] integerValue] == RemoteViewIndex_First) {
                    viewIndex = RemoteViewIndex_Second;
                } else {
                    viewIndex = RemoteViewIndex_First;
                }
            }
            videoView = [self availableVideoView];
        } else if (self.videoViewInfo.count == 0) {
            viewIndex = RemoteViewIndex_First;
            videoView = [self availableVideoView];
        } else {
            NSLog(@"%s, Cannot play %@, no available video view", __func__, streamID);
            assert(false);
            return;
        }
        
        [getZegoAV_ShareInstance() setRemoteView:viewIndex view:videoView];
        bool ret = [getZegoAV_ShareInstance() startPlayStream:streamID viewIndex:viewIndex];
        assert(ret);
        
        if (ret) {
            [self addVideoView:videoView type:2 viewIndex:viewIndex streamID:streamID];
        }
    }
}

- (void)handleKeyboardWillShow:(NSNotification *)notification {
    CGSize kbSize = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    if (kbSize.height == 0) {
        return;
    }
    self.statusBoxBottemSpaceConstraint.constant = kbSize.height - self.statusBoxHeightConstraint.constant + 2;
    [UIView animateWithDuration:0.1 animations:^{
        [self.view layoutIfNeeded];
    }];
}


- (void)handleKeyboardWillDismiss:(NSNotification *)notification {
    self.statusBoxBottemSpaceConstraint.constant = 0;
    [UIView animateWithDuration:0.1 animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.view endEditing:YES];
    return YES;
}

#pragma mark -- UIPickerViewDelegate, UIPickerViewDataSource
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.filterList.count;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    _anchorConfig.filterIndex = row;
    [getZegoAV_ShareInstance() setFilter:row];
}

-(NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    if (row >= _filterList.count) {
        return @"Error";
    }
    
    return [_filterList objectAtIndex:row];
}

#pragma mark - ZegoLiveApiDelegate

/// \brief 发布直播成功
- (void)onPublishSucc:(NSString *)streamID {
    NSLog(@"%s, stream: %@", __func__, streamID);
    self.liveStatus.text = streamID;
    self.isPublishing = YES;
    
    self.liveChannel = [getZegoAV_ShareInstance() liveChannel];
    [self.liveIDField setText:[NSString stringWithFormat:@"Channel: %@", self.liveChannel]];
    self.isLogin = YES;
    
    if (self.liveType == 1) {
        // 作为主播，记录当前的发布信息
        NSDictionary *publishInfo = [getZegoAV_ShareInstance() currentPublishInfo];
        NSString *streamID = publishInfo[kZegoPublishStreamIDKey];
        
        [ZegoSettings sharedInstance].publishingStreamID = streamID;
        [ZegoSettings sharedInstance].publishingLiveChannel = self.liveChannel;
    }
    
    self.btnJoin.enabled = YES;
}

/// \brief 发布直播失败
/// \param err 1 异常结束，2 正常结束
- (void)onPublishStop:(uint32)err stream:(NSString *)streamID {
    NSLog(@"%s, stream: %@, err: %u", __func__, streamID, err);
    
    self.isPublishing = NO;
    self.liveStatus.text = [NSString stringWithFormat:@"%@ Stop", streamID];
    
    self.btnJoin.enabled = YES;
}

/// \brief 获取流信息结果
/// \param err 0 成功，进一步等待流信息更新，否则出错
- (void)onLoginChannel:(uint32)err {
    NSLog(@"%s, err: %u", __func__, err);
    if (err == 0) {
        self.isLogin = YES;
        [self.liveIDField setText:[NSString stringWithFormat:@"Channel: %@", [getZegoAV_ShareInstance() liveChannel]]];
        
        if (self.liveType == 1) {
            if (!self.isPublishing) {
                ZegoLiveApi *api = getZegoAV_ShareInstance();
                
                int ret = [api setAVConfig:[ZegoSettings sharedInstance].currentConfig];
                assert(ret == 0);
                
                bool b = [api setFrontCam:_anchorConfig.useFrontCamera];
                assert(b);
                
                b = [api enableMic:_anchorConfig.enableMic];
                assert(b);
                
                b = [api enableBeautifying:_anchorConfig.enableBeautify];
                assert(b);
                
                b = [api setFilter:(ZegoFilter)_anchorConfig.filterIndex];
                assert(b);
                
                b = [getZegoAV_ShareInstance() startPublishingWithTitle:self.liveTitle streamID:[self publishStreamID]];
                assert(b);
                NSLog(@"%s, ret: %d", __func__, ret);
            }
            self.anchorToolBox.hidden = NO;
        } else if (_liveType == 2) {
            // wait for play info update
        }

    } else {
        [self.liveIDField setText:[NSString stringWithFormat:@"Login failed: %u!", err]];
    }
}

/// \brief 频道连接断开
/// \param err 错误码
/// \param channel 断开的频道
- (void)onDisconnected:(uint32)err channel:(NSString *)channel {
    NSString *msg = [NSString stringWithFormat:@"Channel %@ Connection Broken, ERROR: %u.", channel, err];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Disconnected!" message:msg delegate:nil cancelButtonTitle:@"YES" otherButtonTitles:nil];
    [alert show];
}

/// \brief 频道连接重新建立
/// \param channel 频道
- (void)onReconnected:(NSString *)channel {
    NSString *msg = [NSString stringWithFormat:@"Channel %@ Reconnected.", channel];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reconnected!" message:msg delegate:nil cancelButtonTitle:@"YES" otherButtonTitles:nil];
    [alert show];
}

/// \brief 观看直播成功
/// \param streamID 直播流的唯一标识
- (void)onPlaySucc:(NSString *)streamID {
    NSLog(@"%s, stream: %@", __func__, streamID);
    self.liveStatus.text = [NSString stringWithFormat:@"Play %@ Started.", streamID];
    [self updateLiveStatus];
}

/// \brief 观看直播失败
/// \param err 1 正常结束, 非 1 异常结束
/// \param streamID 直播流的唯一标识
- (void)onPlayStop:(uint32)err streamID:(NSString *)streamID {
    NSLog(@"%s, err: %u, stream: %@", __func__, err, streamID);
    
    if (err == 1) {
        self.liveStatus.text = [NSString stringWithFormat:@"Stream %@ stopped.", streamID];
    } else {
        self.liveStatus.text = [NSString stringWithFormat:@"Play %@ err(%u).", streamID, err];
    }
    
    NSDictionary *viewInfo = [self videoViewInfoOfStream:streamID];
    
    if (viewInfo) {
        if (viewInfo[kZegoDemoVideoViewKey] == self.smallView) {
            self.smallView.hidden = YES;
        }
        [self.videoViewInfo removeObject:viewInfo];
        NSLog(@"%s, remove video view info", __func__);
    }
    
    [self updateLiveStatus];
}

/// \brief 视频的宽度和高度变化通知,startPlay后，如果视频宽度或者高度发生变化(首次的值也会)，则收到该通知
/// \param streamID 流的唯一标识
/// \param width 宽
/// \param height 高
- (void)onVideoSizeChanged:(NSString *)streamID width:(uint32)width height:(uint32)height {
    NSLog(@"%s", __func__);
}

/// \brief 截取观看直播 view 图像结果
/// \param img 图像数据
- (void)onTakeRemoteViewSnapshot:(CGImageRef)img view:(RemoteViewIndex)index {
    NSLog(@"%s", __func__);
    UIImage *i = [UIImage imageWithCGImage:img];
    
}

/// \brief 截取本地预览视频 view 图像结果
/// \param img 图像数据
- (void)onTakeLocalViewSnapshot:(CGImageRef)img {
    NSLog(@"%s", __func__);
    UIImage *i = [UIImage imageWithCGImage:img];
    
}

#pragma mark - Helper
- (ZegoUser *)userInfo {
    ZegoUser *user = [ZegoUser new];
    user.userID = [ZegoSettings sharedInstance].userID;
    user.userName = [ZegoSettings sharedInstance].userName;
    
    return user;
}

- (NSString *)publishStreamID {
    // 使用特殊的方式获取流ID，发布产品中应该尽量保证 streamID 不重复
    NSString *streamID = nil;
    ZegoUser *user = [self userInfo];
    if (user.userID.length > 4) {
        streamID = [user.userID substringFromIndex:user.userID.length - 4];
    } else {
        streamID = user.userID;
    }
    return streamID;
}

- (void)setupLiveKit {
    [getZegoAV_ShareInstance() setDelegate:self];
}


- (void)setIsPublishing:(BOOL)isPublishing {
    _isPublishing = isPublishing;
    if (_isPublishing) {
        if (!self.isPreviewOn) {
            [self togglePreview:nil];
        }
        [self.btnJoin setImage:[UIImage imageNamed:@"ic_pause"] forState:UIControlStateNormal];
    } else {
        if (self.isPreviewOn) {
            [self togglePreview:nil];
        }
        [self.btnJoin setImage:nil forState:UIControlStateNormal];
    }
    
    self.anchorToolBox.hidden = !_isPublishing;
    [self updateLiveStatus];
}

- (void)togglePreview:(id)sender {
    if (self.isPreviewOn) {
        for (NSDictionary *info in self.videoViewInfo) {
            if ([info[kZegoDemoViewTypeKey] integerValue] == 1) {
                if (info[kZegoDemoVideoViewKey] == self.smallView) {
                    self.smallView.hidden = YES;
                }
                [self.videoViewInfo removeObject:info];
                break;  // break after modifying
            }
        }
        [getZegoAV_ShareInstance() setLocalView:nil];
        [getZegoAV_ShareInstance() stopPreview];
    } else {
        UIView *v = [self availableVideoView];
        if (!v) {
            return;
        }
        
        [self addVideoView:v type:1 viewIndex:0 streamID:nil];
        [getZegoAV_ShareInstance() setLocalView:v];
        [getZegoAV_ShareInstance() startPreview];
        v.hidden = NO;
    }
    
    self.isPreviewOn = !self.isPreviewOn;
    [self.view endEditing:YES];
}

- (UIView *)availableVideoView {
    if (self.videoViewInfo.count >= 2) {
        return nil;
    }
    
    if (self.videoViewInfo.count == 1) {
        NSDictionary *info = self.videoViewInfo[0];
        if (info[kZegoDemoVideoViewKey] == self.bigView) {
            self.smallView.hidden = NO;
            return self.smallView;
        } else {
            return self.bigView;
        }
    }
    
    return self.bigView;
}

- (void)addVideoView:(UIView *)view type:(NSInteger)type viewIndex:(NSInteger)idx streamID:(NSString *)streamID {
    assert(self.videoViewInfo.count < 2);
    assert(view != nil);
    
    if (!view || self.videoViewInfo.count >= 2) {
        return;
    }
    
    if (type == 1) {
        [self.videoViewInfo addObject:@{
                                        kZegoDemoViewTypeKey: @(type),
                                        kZegoDemoVideoViewKey: view
                                        }];
    } else if (type == 2) {
        assert(streamID != nil);
        if (streamID == nil) {
            return;
        }
        
        [self.videoViewInfo addObject:@{
                                        kZegoDemoViewTypeKey: @(type),
                                        kZegoDemoVideoViewKey: view,
                                        kZegoDemoViewIndexKey: @(idx),
                                        kZegoDemoStreamIDKey: streamID
                                        }];
    }
}


@end


/// \brief 直播流信息更新
/// \param info 流信息
/// \param flag 变更标志 1 - 新增， 2 - 移除
//- (void)onPlayInfo:(NSDictionary *)info updateFlag:(uint32)flag {
//    NSLog(@"%s, info: %@, flag: %u", __func__, info, flag);
//    dispatch_async(dispatch_get_main_queue(), ^{
//
//        if (flag == 1) {
//            RemoteViewIndex viewIndex = RemoteViewIndex_First;
//            UIView *videoView = nil;
//
//            videoView = [self availableVideoView];
//            if (!videoView) {
//                NSLog(@"%s, Cannot play %@, no available video view", __func__, info);
//                return;
//            }
//
//            switch (self.videoViewInfo.count) {
//                case 0:
//                    viewIndex = RemoteViewIndex_First;
//                    break;
//                case 1: {
//                    if (self.isPublishing) {
//                        viewIndex = RemoteViewIndex_First;
//                    } else {
//                        NSDictionary *info = self.videoViewInfo[0];
//                        if ([info[kZegoDemoViewIndexKey] integerValue] == RemoteViewIndex_First) {
//                            viewIndex = RemoteViewIndex_Second;
//                        } else {
//                            viewIndex = RemoteViewIndex_First;
//                        }
//                    }
//                    break;
//                }
//                default:
//                    NSLog(@"%s, Cannot play %@, no available channel", __func__, info);
//                    return ;
//            }
//
//            [getZegoAV_ShareInstance() setRemoteView:viewIndex view:videoView];
//            NSString *streamID = info[kZegoStreamIDKey];
//            bool ret = [getZegoAV_ShareInstance() startPlayStream:streamID viewIndex:viewIndex];
//            assert(ret);
//
//            if (ret) {
//                [self.videoViewInfo addObject:
//                 @{
//                   kZegoDemoViewTypeKey: @(2),
//                   kZegoDemoViewIndexKey: @(viewIndex),
//                   kZegoDemoStreamIDKey: streamID,
//                   kZegoDemoVideoViewKey: videoView
//                   }];
//            }
//        } else if (flag == 2) {
//            bool ret = [getZegoAV_ShareInstance() stopPlayStream:info[kZegoStreamIDKey]];
//            assert(ret);
//        }
//    });
//}

//- (void)onCountsUpdate:(NSDictionary *)countInfo {
//    uint32 onlineNums = (uint32)[countInfo[kZegoOnlineNumsKey] unsignedIntegerValue];
//    uint32 onlineCount = (uint32)[countInfo[kZegoOnlineCountKey] unsignedIntegerValue];
//
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.liveStatus.text = [NSString stringWithFormat:@"online: %u, history: %u", onlineNums, onlineCount];
//    });
//}