//
//  DriveNaviViewController.m
//  AMapNaviKit
//
//  Created by 刘博 on 16/3/8.
//  Copyright © 2016年 AutoNavi. All rights reserved.
//

#import "DriveNaviViewController.h"
#import "MoreMenuView.h"

@interface DriveNaviViewController ()<AMapNaviDriveViewDelegate, MoreMenuViewDelegate>

@property (nonatomic, strong) MoreMenuView *moreMenu;

@end

@implementation DriveNaviViewController

#pragma mark - Life Cycle

- (instancetype)init
{
    if (self = [super init])
    {
        [self initDriveView];
        
        [self initMoreMenu];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.driveView setFrame:self.view.bounds];
    [self.view addSubview:self.driveView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBarHidden = YES;
    self.navigationController.toolbarHidden = YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return self.driveView.mapViewModeType == AMapNaviViewMapModeTypeNight ?  UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
}


- (void)initDriveView
{
    if (self.driveView == nil)
    {
        self.driveView = [[AMapNaviDriveView alloc] init];
        self.driveView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self.driveView setDelegate:self];
        [self.driveView setShowGreyAfterPass:YES];
        [self.driveView setAutoZoomMapLevel:YES];
        [self.driveView setTrackingMode:AMapNaviViewTrackingModeCarNorth];
        [self.driveView setMapViewModeType:AMapNaviViewMapModeTypeDayNightAuto];
    }
}

- (void)initMoreMenu
{
    if (self.moreMenu == nil)
    {
        self.moreMenu = [[MoreMenuView alloc] init];
        self.moreMenu.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        
        [self.moreMenu setDelegate:self];
    }
}

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

#pragma mark - DriveView Delegate

- (void)driveViewCloseButtonClicked:(AMapNaviDriveView *)driveView
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(driveNaviViewCloseButtonClicked)])
    {
        [self.delegate driveNaviViewCloseButtonClicked];
    }
}

- (void)driveViewMoreButtonClicked:(AMapNaviDriveView *)driveView
{
    //配置MoreMenu状态
    [self.moreMenu setTrackingMode:self.driveView.trackingMode];
    [self.moreMenu setShowNightType:self.driveView.mapViewModeType];
    
    [self.moreMenu setFrame:self.view.bounds];
    [self.view addSubview:self.moreMenu];
}

- (void)driveViewTrunIndicatorViewTapped:(AMapNaviDriveView *)driveView
{
    if (self.driveView.showMode == AMapNaviDriveViewShowModeCarPositionLocked)
    {
        [self.driveView setShowMode:AMapNaviDriveViewShowModeNormal];
    }
    else if (self.driveView.showMode == AMapNaviDriveViewShowModeNormal)
    {
        [self.driveView setShowMode:AMapNaviDriveViewShowModeOverview];
    }
    else if (self.driveView.showMode == AMapNaviDriveViewShowModeOverview)
    {
        [self.driveView setShowMode:AMapNaviDriveViewShowModeCarPositionLocked];
    }
}

- (void)driveView:(AMapNaviDriveView *)driveView didChangeShowMode:(AMapNaviDriveViewShowMode)showMode
{
    NSLog(@"didChangeShowMode:%ld", (long)showMode);
}

- (void)driveView:(AMapNaviDriveView *)driveView didChangeDayNightType:(BOOL)showStandardNightType {
    NSLog(@"didChangeDayNightType:%ld", (long)showStandardNightType);
    [self setNeedsStatusBarAppearanceUpdate];  //更新状态栏颜色
}

#pragma mark - MoreMenu Delegate

- (void)moreMenuViewFinishButtonClicked
{
    [self.moreMenu removeFromSuperview];
}

- (void)moreMenuViewNightTypeChangeTo:(AMapNaviViewMapModeType)mapModeType {
    [self.driveView setMapViewModeType:mapModeType];
}

- (void)moreMenuViewTrackingModeChangeTo:(AMapNaviViewTrackingMode)trackingMode
{
    [self.driveView setTrackingMode:trackingMode];
}

@end
