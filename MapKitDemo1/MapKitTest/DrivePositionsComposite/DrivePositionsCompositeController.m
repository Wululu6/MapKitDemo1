//
//  DrivePositionsCompositeController.m
//  MapKitTest
//
//  Created by apple on 2019/8/1.
//  Copyright © 2019 apple. All rights reserved.
//

#import "DrivePositionsCompositeController.h"

#import <MAMapKit/MAMapKit.h>

#import <AMapSearchKit/AMapSearchAPI.h>

#import <AMapLocationKit/AMapLocationManager.h>



#define DefaultLocationTimeout  6
#define DefaultReGeocodeTimeout 3

#define kCalloutViewMargin  -8

#import "CustomAnnotationView.h"
// 此时地图上应该添加的标注
#import "CustomPositionIconImage.h"


#import <AMapNaviKit/AMapNaviKit.h>
#import "SelectableOverlay.h"
#import "MultiDriveRoutePolyline.h"
#import "Utility.h"

#import "CommonUtility.h"

#import <AVFoundation/AVFoundation.h>

#import "DriveNaviViewController.h"
#import "QuickStartAnnotationView.h"

#import "SpeechSynthesizer.h"

#import "NaviPointAnnotation.h"


static const NSInteger RoutePlanningPaddingEdge                    = 50;


#define AMapNaviRoutePolylineDefaultWidth  20.f


@interface DrivePositionsCompositeController ()<MAMapViewDelegate,AMapSearchDelegate,AMapLocationManagerDelegate,AMapNaviDriveManagerDelegate,DriveNaviViewControllerDelegate,CustomAnnotationDelegate>


@property (nonatomic, strong) MAMapView *mapView;

// 需要进行的定位标注
@property (nonatomic, strong) NSMutableArray *annotations;

// 需要进行的移动后定位标注
@property (nonatomic, strong) NSMutableArray *nextAnnotations;

@property (nonatomic, strong) AMapLocationManager *locationManager;

@property (nonatomic, strong) CLLocation *location;

@property (nonatomic, strong) MAAnnotationView *userLocationAnnotationView;

@property (nonatomic, strong) AMapSearchAPI *searchAPI;

// 大头针
@property (nonatomic, strong) UIImageView *pinView;

@property (nonatomic, copy) AMapLocatingCompletionBlock completionBlock;

@property (nonatomic, assign) CLLocationCoordinate2D lastLocation;

@property (nonatomic, strong) AMapNaviPoint *startPoint;

@property (nonatomic, strong) AMapNaviPoint *endPoint;

@property (nonatomic, assign) BOOL isMultipleRoutePlan;

// 是否已经规划路线
@property (nonatomic, assign) BOOL isDrawPosition;

@property (nonatomic, strong) NaviPointAnnotation *beginAnnotation;

// 当前我所在的位置
@property (nonatomic, assign) CLLocationCoordinate2D myLocation;

// 底部的view区域
@property (nonatomic, strong) UIView *bottomView;

// 描述信息label
@property (nonatomic, strong) UILabel *describeLabel;

@property (nonatomic, strong) NSMutableArray *customAnnotation;

@end



@implementation DrivePositionsCompositeController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = @"找到临近车位并添加导航";
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self initAnnotations];
    
    self.mapView = [[MAMapView alloc] initWithFrame:CGRectMake(0, 64, self.view.frame.size.width, self.view.frame.size.height - 64 - 60)];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    
    self.mapView.mapType = MAMapTypeNavi;
    
    // 禁止旋转
    self.mapView.rotateEnabled = NO;
    // 禁止立体旋转
    self.mapView.rotateCameraEnabled = NO;
    
    self.mapView.showsBuildings = NO;
    
    //self.mapView.showTraffic = YES;
    
    
    self.mapView.showTraffic = YES;
    // 路线颜色
    [self.mapView setTrafficStatus:@{@(MATrafficStatusSlow):[UIColor yellowColor],@(MATrafficStatusJam):[UIColor redColor],@(MATrafficStatusSeriousJam):[UIColor redColor],@(MATrafficStatusSmooth):[UIColor whiteColor]}];
    
    self.mapView.showsCompass = YES;
    
    self.mapView.showsUserLocation = YES;
    self.mapView.userTrackingMode = MAUserTrackingModeFollow;
    
    [self.view addSubview:self.mapView];
    
    
    // 初始化搜索
    self.searchAPI = [[AMapSearchAPI alloc] init];
    self.searchAPI.delegate = self;
    
    
    [self initCompleteBlock];
    
    [self configLocationManager];
    
    [self.mapView addAnnotations:self.annotations];
    
    [self creatPinView];
    
    // 创建行车管理者
    [self initDriveManager];
    
    [self _initBottonView];
    
}

- (void)initDriveManager {
    //请在 dealloc 函数中执行 [AMapNaviDriveManager destroyInstance] 来销毁单例
    [[AMapNaviDriveManager sharedInstance] setDelegate:self];
}

// 底部区域的显示信息的view
- (void)_initBottonView {
    
    self.bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 60, CGRectGetWidth(self.view.frame), 60)];
    self.bottomView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.bottomView];
    
    self.describeLabel = [[UILabel alloc] initWithFrame:self.bottomView.bounds];
    self.describeLabel.textAlignment = NSTextAlignmentCenter;
    self.describeLabel.font = [UIFont boldSystemFontOfSize:20.0];
    self.describeLabel.numberOfLines = 2;
    
    self.describeLabel.text = @"请选择附近的停车场";
    [self.bottomView addSubview:self.describeLabel];
    
    
}


#pragma mark - Initialization
- (void)initCompleteBlock {
    __weak DrivePositionsCompositeController *weakSelf = self;
    self.completionBlock = ^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
        if (error != nil && error.code == AMapLocationErrorLocateFailed) {
            //定位错误：此时location和regeocode没有返回值，不进行annotation的添加
            NSLog(@"定位错误:{%ld - %@};", (long)error.code, error.userInfo);
            // 重新进行,单次定位
            [weakSelf.locationManager requestLocationWithReGeocode:YES completionBlock:weakSelf.completionBlock];
            return;
        } else if (error != nil
                   && (error.code == AMapLocationErrorReGeocodeFailed
                       || error.code == AMapLocationErrorTimeOut
                       || error.code == AMapLocationErrorCannotFindHost
                       || error.code == AMapLocationErrorBadURL
                       || error.code == AMapLocationErrorNotConnectedToInternet
                       || error.code == AMapLocationErrorCannotConnectToHost))
        {
            //逆地理错误：在带逆地理的单次定位中，逆地理过程可能发生错误，此时location有返回值，regeocode无返回值，进行annotation的添加
            NSLog(@"逆地理错误:{%ld - %@};", (long)error.code, error.userInfo);
            // 重新进行,单次定位
            [weakSelf.locationManager requestLocationWithReGeocode:YES completionBlock:weakSelf.completionBlock];
            
        } else if (error != nil && error.code == AMapLocationErrorRiskOfFakeLocation) {
            //存在虚拟定位的风险：此时location和regeocode没有返回值，不进行annotation的添加
            NSLog(@"存在虚拟定位的风险:{%ld - %@};", (long)error.code, error.userInfo);
            
            //存在虚拟定位的风险的定位结果
            __unused CLLocation *riskyLocateResult = [error.userInfo objectForKey:@"AMapLocationRiskyLocateResult"];
            //存在外接的辅助定位设备
            __unused NSDictionary *externalAccressory = [error.userInfo objectForKey:@"AMapLocationAccessoryInfo"];
            
            return;
        } else {
            //没有错误：location有返回值，regeocode是否有返回值取决于是否进行逆地理操作，进行annotation的添加
        }
        
        //根据定位信息，添加annotation
        //        MAPointAnnotation *annotation = [[MAPointAnnotation alloc] init];
        //        [annotation setCoordinate:location.coordinate];
        
        //有无逆地理信息，annotationView的标题显示的字段不一样
        if (regeocode) {
            
            weakSelf.location = location;
            
            // 初始化出发点位置
            weakSelf.startPoint = [AMapNaviPoint locationWithLatitude:location.coordinate.latitude longitude:location.coordinate.longitude];
            
            //            [annotation setTitle:[NSString stringWithFormat:@"%@", regeocode.formattedAddress]];
            //            [annotation setSubtitle:[NSString stringWithFormat:@"%@-%@-%.2fm", regeocode.citycode, regeocode.adcode, location.horizontalAccuracy]];
        } else {
            //            [annotation setTitle:[NSString stringWithFormat:@"lat:%f;lon:%f;", location.coordinate.latitude, location.coordinate.longitude]];
            //            [annotation setSubtitle:[NSString stringWithFormat:@"accuracy:%.2fm", location.horizontalAccuracy]];
        }
        
        [weakSelf performSelector:@selector(reloadMap) withObject:nil afterDelay:0.1];
        
    };
    
}


#pragma mark - Action Handle
- (void)configLocationManager {
    self.locationManager = [[AMapLocationManager alloc] init];
    
    [self.locationManager setDelegate:self];
    
    //设置期望定位精度
    [self.locationManager setDesiredAccuracy:kCLLocationAccuracyHundredMeters];
    
    //设置不允许系统暂停定位
    [self.locationManager setPausesLocationUpdatesAutomatically:NO];
    
    //设置允许在后台定位
    [self.locationManager setAllowsBackgroundLocationUpdates:YES];
    
    //设置定位超时时间
    [self.locationManager setLocationTimeout:DefaultLocationTimeout];
    
    //设置逆地理超时时间
    [self.locationManager setReGeocodeTimeout:DefaultReGeocodeTimeout];
    
    //设置开启虚拟定位风险监测，可以根据需要开启
    [self.locationManager setDetectRiskOfFakeLocation:NO];
    
    //开始定位
    //[self.locationManager startUpdatingLocation];
    
    //进行单次带逆地理定位请求
    [self.locationManager requestLocationWithReGeocode:YES completionBlock:self.completionBlock];
    [self.mapView setZoomLevel:17.5];
    
}



#pragma mark--创建大头针
- (void)creatPinView {
    
    self.pinView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    self.pinView.image = [UIImage imageNamed:@"mapimage"];
    self.pinView.center = CGPointMake(self.view.frame.size.width * 0.5, (self.view.frame.size.height - 64) * 0.5);
    self.pinView.hidden = NO;
    [self.mapView addSubview:self.pinView];
    
}


#pragma mark--移动地图的时候点击事件
- (void)mapView:(MAMapView *)mapView mapDidMoveByUser:(BOOL)wasUserAction {
    // 已经是规划线路状态下不进行重新获取地址
    if (!wasUserAction || self.isDrawPosition == YES) {
        return;
    }
    CGPoint center = CGPointMake(self.mapView.bounds.size.width * 0.5, self.mapView.bounds.size.height * 0.5);
    CLLocationCoordinate2D coor2d = [mapView convertPoint:center toCoordinateFromView:self.mapView];
    self.lastLocation = coor2d;
    
    
    // 初始化出发点位置
    self.startPoint = [AMapNaviPoint locationWithLatitude:coor2d.latitude longitude:coor2d.longitude];
    
    
    // 设置地图中心
    // ReGEO解析
    //    AMapReGeocodeSearchRequest *request = [[AMapReGeocodeSearchRequest alloc] init];
    //  request.location = [AMapGeoPoint locationWithLatitude:coor2d.latitude longitude:coor2d.longitude];
    //  [self.searchAPI AMapReGoecodeSearch:request];
    
    
    // 创建下一组定位数据
    //    [self initNextAnnotations];
    //
    //    [self.mapView removeAnnotations:self.annotations];
    //    [self.mapView addAnnotations:self.nextAnnotations];
    //    [self.mapView showAnnotations:self.nextAnnotations animated:YES];
    
    
    [self.mapView removeAnnotations:self.annotations];
    [self.mapView removeAnnotations:self.nextAnnotations];
    
    
    [self.nextAnnotations removeAllObjects];
    
    // 清空所有标注
    [self.customAnnotation removeAllObjects];
    
    // 重新添加10个
    for (int i = 0; i < 10; i++) {
        CLLocationCoordinate2D randomCoordinate = [self.mapView convertPoint:[self randomPoint] toCoordinateFromView:self.view];
        [self addAnnotationWithCooordinate:randomCoordinate];
    }
    
    [self.mapView addAnnotations:self.nextAnnotations];
    
    
    //[self.mapView showAnnotations:self.nextAnnotations edgePadding:UIEdgeInsetsMake(kCalloutViewMargin, kCalloutViewMargin, kCalloutViewMargin, kCalloutViewMargin) animated:NO];
    
    [self.mapView setCenterCoordinate:self.lastLocation animated:YES];
    CGFloat level = [self randomLevel];
    [self.mapView setZoomLevel:level atPivot:center animated:YES];
    
    //[self.mapView showAnnotations:self.nextAnnotations animated:YES];
    
    
}

- (CGFloat)randomLevel {
    int level = arc4random() % 6;
    if (level == 0) {
        return 17.5;
    } else if (level == 1){
        return 17.4;
    } else if (level == 2) {
        return 17.3;
    } else if (level == 3) {
        return 17.2;
    } else if (level == 4) {
        return 17.1;
    } else if (level == 5) {
        return 17.1;
    }
    return 17.5;
}

- (CGPoint)randomPoint {
    CGPoint randomPoint = CGPointZero;
    
    randomPoint.x = arc4random() % (int)(CGRectGetWidth(self.view.bounds));
    randomPoint.y = arc4random() % (int)(CGRectGetHeight(self.view.bounds));
    
    if (randomPoint.x < 50) {
        randomPoint.x = 50;
    } else if (randomPoint.x > CGRectGetWidth(self.view.bounds) - 50) {
        randomPoint.x = CGRectGetWidth(self.view.bounds) - 50;
    }
    
    if (randomPoint.y < 64) {
        randomPoint.y = 64 + 10;
    } else if (randomPoint.y > CGRectGetHeight(self.view.bounds) - 64) {
        randomPoint.y = CGRectGetHeight(self.view.bounds) - 64 - 10;
    }
    
    return randomPoint;
}

-(void)addAnnotationWithCooordinate:(CLLocationCoordinate2D)coordinate {
    MAPointAnnotation *annotation = [[MAPointAnnotation alloc] init];
    annotation.coordinate = coordinate;
    annotation.title    = @"AutoNavi";
    annotation.subtitle = @"CustomAnnotationView";
    //[self.mapView addAnnotation:annotation];
    
    [self.nextAnnotations addObject:annotation];
}


- (void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response {
    
    //NSString *address = response.regeocode.formattedAddress;
    
    // 定位结果
    NSLog(@"location:{lat:%f; lon:%f}", request.location.latitude, request.location.longitude);
    self.pinView.hidden = NO;
    
    [self.mapView setCenterCoordinate:self.lastLocation animated:YES];
    
}



- (void)reloadMap {
    
    MACoordinateRegion region = MACoordinateRegionMake(self.location.coordinate, MACoordinateSpanMake(0.25, 0.25)) ;
    [self.mapView setRegion:[self.mapView regionThatFits:region] animated:YES];
    
    [self.mapView setZoomLevel:17.5];
    
}

#pragma mark--展示线路
- (void)showMultiColorNaviRoutes {
    
    if ([[AMapNaviDriveManager sharedInstance].naviRoutes count] <= 0) {
        return;
    }
    
    [self.mapView removeOverlays:self.mapView.overlays];
    
    
    //将路径显示到地图上(正常顺序)
    for (NSNumber *aRouteID in [[AMapNaviDriveManager sharedInstance].naviRoutes allKeys]) {
        AMapNaviRoute *aRoute = [[[AMapNaviDriveManager sharedInstance] naviRoutes] objectForKey:aRouteID];
        int count = (int)[[aRoute routeCoordinates] count];
        
        //添加路径Polyline
        CLLocationCoordinate2D *coords = (CLLocationCoordinate2D *)malloc(count * sizeof(CLLocationCoordinate2D));
        for (int i = 0; i < count; i++) {
            AMapNaviPoint *coordinate = [[aRoute routeCoordinates] objectAtIndex:i];
            coords[i].latitude = [coordinate latitude];
            coords[i].longitude = [coordinate longitude];
        }
        
        NSMutableArray<UIImage *> *textureImagesArrayNormal = [NSMutableArray new];
        NSMutableArray<UIImage *> *textureImagesArraySelected = [NSMutableArray new];
        
        // 添加路况图片
        for (AMapNaviTrafficStatus *status in aRoute.routeTrafficStatuses) {
            UIImage *img = [self defaultTextureImageForRouteStatus:status.status isSelected:NO];
            UIImage *selImg = [self defaultTextureImageForRouteStatus:status.status isSelected:YES];
            if (img && selImg) {
                [textureImagesArrayNormal addObject:img];
                [textureImagesArraySelected addObject:selImg];
            }
        }
        
        MultiDriveRoutePolyline *mulPolyline = [MultiDriveRoutePolyline polylineWithCoordinates:coords count:count drawStyleIndexes:aRoute.drawStyleIndexes];
        mulPolyline.overlay = mulPolyline;
        mulPolyline.polylineTextureImages = textureImagesArrayNormal;
        mulPolyline.polylineTextureImagesSeleted = textureImagesArraySelected;
        mulPolyline.routeID = aRouteID.integerValue;
        mulPolyline.routeIDNumber = aRouteID;
        
        [self.mapView addOverlay:mulPolyline];
        
        free(coords);
        
    }
    
    
    //为了方便展示驾车多路径规划，选择了固定的起终点
    
    // 添不添加都可以
    //[self.mapView setCenterCoordinate:CLLocationCoordinate2DMake((39.993135 + 39.908791) * 0.5, (116.474175 + 116.321257) * 0.5)];
    
    [self.mapView showAnnotations:self.mapView.annotations animated:NO];
    
    if ([[AMapNaviDriveManager sharedInstance].naviRoutes allKeys].count > 0) {
        NSNumber *aRouteID = [[[AMapNaviDriveManager sharedInstance].naviRoutes allKeys] firstObject];
        [self selectNaviRouteWithID:[aRouteID integerValue]];
    } else {
        [self selectNaviRouteWithID:0];
    }
    
}

#pragma mark--在开始导航前进行路径选择
- (void)selectNaviRouteWithID:(NSInteger)routeID {
    //在开始导航前进行路径选择
    if ([[AMapNaviDriveManager sharedInstance] selectNaviRouteWithRouteID:routeID])   {
        [self selecteOverlayWithRouteID:routeID];
    }   else    {
        NSLog(@"路径选择失败!");
    }
}

- (void)selecteOverlayWithRouteID:(NSInteger)routeID {
    
    NSMutableArray *selectedPolylines = [NSMutableArray array];
    CGFloat backupRoutePolylineWidthScale = 0.8;  //备选路线是当前路线宽度0.8
    
    [self.mapView.overlays enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id<MAOverlay> overlay, NSUInteger idx, BOOL *stop) {
        
        if ([overlay isKindOfClass:[MultiDriveRoutePolyline class]]) {
            MultiDriveRoutePolyline *multiPolyline = overlay;
            
            /* 获取overlay对应的renderer. */
            MAMultiTexturePolylineRenderer * overlayRenderer = (MAMultiTexturePolylineRenderer *)[self.mapView rendererForOverlay:multiPolyline];
            
            if ([multiPolyline.routeIDNumber integerValue] == routeID) {
                [selectedPolylines addObject:overlay];
                
                // 更新信息
                AMapNaviRoute *aRoute = [[[AMapNaviDriveManager sharedInstance] naviRoutes] objectForKey:multiPolyline.routeIDNumber];
                
                
                //更新CollectonView的信息
                self.describeLabel.text = [NSString stringWithFormat:@"线路%ld|距离长度:%ld米 | 预估时间:%ld分钟 | 分段数:%ld",[multiPolyline.routeIDNumber integerValue] + 1, (long)aRoute.routeLength, (long)aRoute.routeTime/60, (long)aRoute.routeSegments.count];
                
                /* 缩放地图使其适应polylines的展示. */
                [self.mapView setVisibleMapRect:[CommonUtility mapRectForOverlays:self.mapView.overlays]
                                    edgePadding:UIEdgeInsetsMake(RoutePlanningPaddingEdge, RoutePlanningPaddingEdge, RoutePlanningPaddingEdge, RoutePlanningPaddingEdge)
                                       animated:YES];
                
            } else {
                // 修改备选路线的样式
                overlayRenderer.lineWidth = AMapNaviRoutePolylineDefaultWidth * backupRoutePolylineWidthScale;
                overlayRenderer.strokeTextureImages = multiPolyline.polylineTextureImages;
            }
        }
    }];
    
    [self.mapView removeOverlays:selectedPolylines];
    [self.mapView addOverlays:selectedPolylines];
    
}




//根据交通状态获得纹理图片
- (UIImage *)defaultTextureImageForRouteStatus:(AMapNaviRouteStatus)routeStatus isSelected:(BOOL)isSelected {
    
    
    NSString *imageName = nil;
    
    if (routeStatus == AMapNaviRouteStatusSmooth) {
        imageName = @"custtexture_green";
    } else if (routeStatus == AMapNaviRouteStatusSlow) {
        imageName = @"custtexture_slow";
    } else if (routeStatus == AMapNaviRouteStatusJam) {
        imageName = @"custtexture_bad";
    } else if (routeStatus == AMapNaviRouteStatusSeriousJam) {
        imageName = @"custtexture_serious";
    } else {
        imageName = @"custtexture_no";
    }
    if (!isSelected) {
        imageName = [NSString stringWithFormat:@"%@_unselected",imageName];
    }
    return [UIImage imageNamed:imageName];
    
    
}


#pragma mark - DriveNaviView Delegate
- (void)driveNaviViewCloseButtonClicked {
    //停止导航
    [[AMapNaviDriveManager sharedInstance] stopNavi];
    
    //停止语音
    [[SpeechSynthesizer sharedSpeechSynthesizer] stopSpeak];
    
    
    self.navigationController.navigationBarHidden = NO;
    [self.navigationController popViewControllerAnimated:NO];
    
    
    // 关闭导航并且选到已经选择的线路
    NSInteger naviRouteID = [AMapNaviDriveManager sharedInstance].naviRouteID;
    
    NSLog(@"naviRouteID == %ld",naviRouteID);
    
    
    NSMutableArray *selectedPolylines = [NSMutableArray array];
    CGFloat backupRoutePolylineWidthScale = 0.8;  //备选路线是当前路线宽度0.8
    
    [self.mapView.overlays enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id<MAOverlay> overlay, NSUInteger idx, BOOL *stop) {
        
        if ([overlay isKindOfClass:[MultiDriveRoutePolyline class]]) {
            MultiDriveRoutePolyline *multiPolyline = overlay;
            
            /* 获取overlay对应的renderer. */
            MAMultiTexturePolylineRenderer * overlayRenderer = (MAMultiTexturePolylineRenderer *)[self.mapView rendererForOverlay:multiPolyline];
            
            if ([multiPolyline.routeIDNumber integerValue] == naviRouteID) {
                [selectedPolylines addObject:overlay];
                
                // 选择导航线路
                [[AMapNaviDriveManager sharedInstance] selectNaviRouteWithRouteID:[multiPolyline.routeIDNumber integerValue]];
                
                // 更新信息
                AMapNaviRoute *aRoute = [[[AMapNaviDriveManager sharedInstance] naviRoutes] objectForKey:multiPolyline.routeIDNumber];
                self.describeLabel.text = [NSString stringWithFormat:@"线路%ld|距离长度:%ld米 | 预估时间:%ld分钟 | 分段数:%ld",[multiPolyline.routeIDNumber integerValue] + 1, (long)aRoute.routeLength, (long)aRoute.routeTime/60, (long)aRoute.routeSegments.count];
                
            } else {
                // 修改备选路线的样式
                overlayRenderer.lineWidth = AMapNaviRoutePolylineDefaultWidth * backupRoutePolylineWidthScale;
                overlayRenderer.strokeTextureImages = multiPolyline.polylineTextureImages;
            }
        }
    }];
    
    [self.mapView removeOverlays:selectedPolylines];
    [self.mapView addOverlays:selectedPolylines];
    
}


#pragma mark--进入导航的事件
- (void)pushNaviDriveControllerBy:(CLLocationCoordinate2D)coorinate {
    // 设置终点位置
    self.endPoint  = [AMapNaviPoint locationWithLatitude:coorinate.latitude longitude:coorinate.longitude];
    [self routePlanAction];
}


#pragma mark--开始进行导航控制
- (void)routePlanAction {
    DriveNaviViewController *driveVC = [[DriveNaviViewController alloc] init];
    [driveVC setDelegate:self];
    
    //将driveView添加为导航数据的Representative，使其可以接收到导航诱导数据
    [[AMapNaviDriveManager sharedInstance] addDataRepresentative:driveVC.driveView];
    
    [self.navigationController pushViewController:driveVC animated:NO];
    [[AMapNaviDriveManager sharedInstance] startGPSNavi];
}



#pragma mark - AMapNaviDriveManager Delegate
- (void)driveManager:(AMapNaviDriveManager *)driveManager error:(NSError *)error {
    NSLog(@"error:{%ld - %@}", (long)error.code, error.localizedDescription);
}

#pragma mark--算路成功后显示路径
- (void)driveManager:(AMapNaviDriveManager *)driveManager onCalculateRouteSuccessWithType:(AMapNaviRoutePlanType)type {
    NSLog(@"onCalculateRouteSuccess");
    
    // 先清除上次点击标注的记录
    [self.mapView removeAnnotation:self.beginAnnotation];
    self.pinView.hidden = YES;
    self.isDrawPosition = YES;
    
    //算路成功后显示路径
    [self showMultiColorNaviRoutes];
    
    // 在地图上添加导航标注
    NaviPointAnnotation *beginAnnotation = [[NaviPointAnnotation alloc] init];
    [beginAnnotation setCoordinate:CLLocationCoordinate2DMake(self.startPoint.latitude, self.startPoint.longitude)];
    beginAnnotation.title = @"起始点";
    beginAnnotation.navPointType = NaviPointAnnotationStart;
    self.beginAnnotation = beginAnnotation;
    // 添加导航起点图片
    [self.mapView addAnnotation:beginAnnotation];
    
    
    //构建路线数据模型
    //[self buildRouteDataSource];
    
    
}

- (void)driveManager:(AMapNaviDriveManager *)driveManager onCalculateRouteFailure:(NSError *)error routePlanType:(AMapNaviRoutePlanType)type {
    NSLog(@"onCalculateRouteFailure:{%ld - %@}", (long)error.code, error.localizedDescription);
}

- (void)driveManager:(AMapNaviDriveManager *)driveManager didStartNavi:(AMapNaviMode)naviMode {
    NSLog(@"didStartNavi");
}

- (void)driveManagerNeedRecalculateRouteForYaw:(AMapNaviDriveManager *)driveManager {
    NSLog(@"needRecalculateRouteForYaw");
}

- (void)driveManagerNeedRecalculateRouteForTrafficJam:(AMapNaviDriveManager *)driveManager {
    NSLog(@"needRecalculateRouteForTrafficJam");
}

- (void)driveManager:(AMapNaviDriveManager *)driveManager onArrivedWayPoint:(int)wayPointIndex {
    NSLog(@"onArrivedWayPoint:%d", wayPointIndex);
}

- (BOOL)driveManagerIsNaviSoundPlaying:(AMapNaviDriveManager *)driveManager {
    //return NO;
    return [[SpeechSynthesizer sharedSpeechSynthesizer] isSpeaking];
}

- (void)driveManager:(AMapNaviDriveManager *)driveManager playNaviSoundString:(NSString *)soundString soundStringType:(AMapNaviSoundType)soundStringType {
    NSLog(@"playNaviSoundString:{%ld:%@}", (long)soundStringType, soundString);
    [[SpeechSynthesizer sharedSpeechSynthesizer] speakString:soundString];
}

- (void)driveManagerDidEndEmulatorNavi:(AMapNaviDriveManager *)driveManager {
    NSLog(@"didEndEmulatorNavi");
}

- (void)driveManagerOnArrivedDestination:(AMapNaviDriveManager *)driveManager {
    NSLog(@"onArrivedDestination");
}

- (void)driveManager:(AMapNaviDriveManager *)driveManager onSuggestChangeMainNaviRoute:(AMapNaviSuggestChangeMainNaviRouteInfo *)suggestChangeMainNaviRouteInfo {
    NSLog(@"onSuggestChangeMainNaviRoute");
}


#pragma mark--MAMapViewDelegate
- (void)mapViewRequireLocationAuth:(CLLocationManager *)locationManager {
    [locationManager requestAlwaysAuthorization];
}


- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id <MAOverlay>)overlay {
    /* 自定义定位精度对应的MACircleView. */
    if (overlay == mapView.userLocationAccuracyCircle) {
        MACircleRenderer *accuracyCircleRenderer = [[MACircleRenderer alloc] initWithCircle:overlay];
        
        accuracyCircleRenderer.lineWidth    = 2.f;
        accuracyCircleRenderer.strokeColor  = [UIColor lightGrayColor];
        accuracyCircleRenderer.fillColor    = [UIColor colorWithRed:1 green:0 blue:0 alpha:.3];
        
        return accuracyCircleRenderer;
    } else if ([overlay isKindOfClass:[MultiDriveRoutePolyline class]]) {
        MultiDriveRoutePolyline *mpolyline = (MultiDriveRoutePolyline *)overlay;
        MAMultiTexturePolylineRenderer *polylineRenderer = [[MAMultiTexturePolylineRenderer alloc] initWithMultiPolyline:mpolyline];
        
        polylineRenderer.lineWidth = AMapNaviRoutePolylineDefaultWidth;
        polylineRenderer.lineJoinType = kMALineJoinRound;
        polylineRenderer.strokeTextureImages = mpolyline.polylineTextureImagesSeleted;
        
        return polylineRenderer;
        
    }
    
    return nil;
}


#pragma mark--标注所对应显示样式
- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation {
    
     if ([annotation isKindOfClass:[NaviPointAnnotation class]]) {
        static NSString *customPositionIndetifier = @"customPositionIndetifier";
        CustomPositionIconImage *annotationView = (CustomPositionIconImage*)[mapView dequeueReusableAnnotationViewWithIdentifier:customPositionIndetifier];
         //annotationView.backgroundColor = [[UIColor clearColor] colorWithAlphaComponent:1.0];
        if (annotationView == nil) {
            annotationView = [[CustomPositionIconImage alloc] initWithAnnotation:annotation reuseIdentifier:customPositionIndetifier];
            // must set to NO, so we can show the custom callout view.
            annotationView.canShowCallout = NO;
            annotationView.draggable = NO;
        }
        
        annotationView.coordinate = annotation.coordinate;
        annotationView.portrait = [UIImage imageNamed:@"mapimage"];
        annotationView.name = @"起始点";
        
        return annotationView;
         
    } else if ([annotation isKindOfClass:[MAUserLocation class]]) {
        /* 自定义userLocation对应的annotationView. */
        static NSString *userLocationStyleReuseIndetifier = @"userLocationStyleReuseIndetifier";
        MAAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:userLocationStyleReuseIndetifier];
        if (annotationView == nil) {
            annotationView = [[MAAnnotationView alloc] initWithAnnotation:annotation
                                                          reuseIdentifier:userLocationStyleReuseIndetifier];
        }
        
        annotationView.image = [UIImage imageNamed:@"userPosition"];
        // 我自身所在的坐标
        self.myLocation = annotation.coordinate;
        self.userLocationAnnotationView = annotationView;
        
        return annotationView;
        /* 自定义周边停车位对应的annotationView. */
    } else if ([annotation isKindOfClass:[MAPointAnnotation class]]) {
        static NSString *customReuseIndetifier = @"customReuseIndetifier";
        CustomAnnotationView *annotationView = (CustomAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:customReuseIndetifier];
        
        if (annotationView == nil) {
            annotationView = [[CustomAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:customReuseIndetifier];
            // must set to NO, so we can show the custom callout view.
            annotationView.canShowCallout = NO;
            annotationView.draggable = YES;
            annotationView.calloutOffset = CGPointMake(0, -5);
        }
        
        annotationView.coordinate = annotation.coordinate;
        annotationView.portrait = [UIImage imageNamed:@"parking"];
        //annotationView.name = @"停车";
        annotationView.delegate = self;
        
        
        // 添加进入
        [self.customAnnotation addObject:annotationView];
        
        return annotationView;
    }
    
    return nil;
}

#pragma mark--点击地图的事件
- (void)mapView:(MAMapView *)mapView didSingleTappedAtCoordinate:(CLLocationCoordinate2D)coordinate {
    
    
    __block BOOL isContainsOverLay = NO;
    /* 逆序遍历overlay判断单击点是否在overlay响应区域内. */
    [self.mapView.overlays enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id<MAOverlay> overlay, NSUInteger idx, BOOL *stop)
     {
         if ([overlay isKindOfClass:[SelectableOverlay class]])
         {
             //             SelectableOverlay *selectableOverlay = overlay;
             //
             //             /* 获取overlay对应的renderer. */
             //             MAOverlayPathRenderer * renderer = (MAOverlayPathRenderer *)[self.mapView rendererForOverlay:selectableOverlay];
             //
             //             /* 把屏幕坐标转换为MAMapPoint坐标. */
             //             MAMapPoint mapPoint = MAMapPointForCoordinate(coordinate);
             //             /* overlay的线宽换算到MAMapPoint坐标系的宽度. */
             //             double mapPointDistance = [self mapPointsPerPointInViewAtCurrentZoomLevel] * renderer.lineWidth;
             //
             //             /* 判断是否选中了overlay. */
             //             if (isOverlayWithLineWidthContainsPoint(selectableOverlay.overlay, mapPointDistance, mapPoint) )
             //             {
             //                 /* 设置选中状态. */
             //                 selectableOverlay.selected = !selectableOverlay.isSelected;
             //
             //                 /* 修改view选中颜色. */
             //                 renderer.fillColor   = selectableOverlay.isSelected? selectableOverlay.selectedColor:selectableOverlay.regularColor;
             //                 renderer.strokeColor = selectableOverlay.isSelected? selectableOverlay.selectedColor:selectableOverlay.regularColor;
             //
             //                 /* 修改overlay覆盖的顺序. */
             //                 [self.mapView exchangeOverlayAtIndex:idx withOverlayAtIndex:self.mapView.overlays.count - 1];
             //
             //                 [renderer glRender];
             //
             //                 *stop = YES;
             //             }
         } else if ([overlay isKindOfClass:[MultiDriveRoutePolyline class]]) {
             
             MultiDriveRoutePolyline *mpolyline = (MultiDriveRoutePolyline *)overlay;
             
             /* 获取overlay对应的renderer. */
             MAMultiTexturePolylineRenderer *polylineRenderer = (MAMultiTexturePolylineRenderer *)[self.mapView rendererForOverlay:mpolyline];
             /* 把屏幕坐标转换为MAMapPoint坐标. */
             MAMapPoint mapPoint = MAMapPointForCoordinate(coordinate);
             /* overlay的线宽换算到MAMapPoint坐标系的宽度. */
             double mapPointDistance = [self mapPointsPerPointInViewAtCurrentZoomLevel] * polylineRenderer.lineWidth;
             
             /* 判断是否选中了overlay. */
             if (MAPisOverlayWithLineWidthContainsPoint(mpolyline.overlay, mapPointDistance, mapPoint) )
             {
                 
                 /* 设置选中状态. */
                 NSMutableArray *selectedPolylines = [NSMutableArray array];
                 CGFloat backupRoutePolylineWidthScale = 0.8;  //备选路线是当前路线宽度0.8
                 
                 [self.mapView.overlays enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id<MAOverlay> overlay, NSUInteger idx, BOOL *stop) {
                     
                     if ([overlay isKindOfClass:[MultiDriveRoutePolyline class]]) {
                         MultiDriveRoutePolyline *multiPolyline = overlay;
                         
                         /* 获取overlay对应的renderer. */
                         MAMultiTexturePolylineRenderer * overlayRenderer = (MAMultiTexturePolylineRenderer *)[self.mapView rendererForOverlay:multiPolyline];
                         
                         if ([multiPolyline.routeIDNumber integerValue] == [mpolyline.routeIDNumber integerValue]) {
                             [selectedPolylines addObject:overlay];
                             
                             // 选择导航线路
                             [[AMapNaviDriveManager sharedInstance] selectNaviRouteWithRouteID:[multiPolyline.routeIDNumber integerValue]];
                             
                             // 更新信息
                             AMapNaviRoute *aRoute = [[[AMapNaviDriveManager sharedInstance] naviRoutes] objectForKey:multiPolyline.routeIDNumber];
                             self.describeLabel.text = [NSString stringWithFormat:@"线路%ld|距离长度:%ld米 | 预估时间:%ld分钟 | 分段数:%ld",[multiPolyline.routeIDNumber integerValue] + 1, (long)aRoute.routeLength, (long)aRoute.routeTime/60, (long)aRoute.routeSegments.count];
                             isContainsOverLay = YES;
                             
                         } else {
                             // 修改备选路线的样式
                             overlayRenderer.lineWidth = AMapNaviRoutePolylineDefaultWidth * backupRoutePolylineWidthScale;
                             overlayRenderer.strokeTextureImages = multiPolyline.polylineTextureImages;
                         }
                     }
                 }];
                 
                 [self.mapView removeOverlays:selectedPolylines];
                 [self.mapView addOverlays:selectedPolylines];
                 
                 
                 
                 //[self selectNaviRouteWithID:[[self.routeIndicatorInfoArray objectAtIndex:idx] routeID]];
                 
                 
                 //                      mpolyline.selected = !mpolyline.isSelected;
                 
                 /* 修改view选中颜色. */
                 //                 renderer.fillColor   = selectableOverlay.isSelected? selectableOverlay.selectedColor:selectableOverlay.regularColor;
                 //                 renderer.strokeColor = selectableOverlay.isSelected? selectableOverlay.selectedColor:selectableOverlay.regularColor;
                 
                 /* 修改overlay覆盖的顺序. */
                 
                 //[self.mapView exchangeOverlayAtIndex:idx withOverlayAtIndex:self.mapView.overlays.count - 1];
                 
                 [polylineRenderer glRender];
                 
                 *stop = YES;
             }
             
         }
         
     }];
    
    
    // 当点击的区域不是线路的时候进行清除和重置
    if (isContainsOverLay == NO) {
        // 先判断有没有变成线路规划模式
        if (self.isDrawPosition == YES) {
            
            // 移除标注
            [self.mapView removeAnnotation:self.beginAnnotation];
            // 移除线路规划
            [self.mapView removeOverlays:self.mapView.overlays];
            
            
            self.isDrawPosition = NO;
            self.pinView.hidden = NO;
            self.startPoint = [AMapNaviPoint locationWithLatitude:self.myLocation.latitude longitude:self.myLocation.longitude];
            [self.mapView setCenterCoordinate:self.myLocation];
            
            self.describeLabel.text = @"请选择附近的停车场";
            
            
            // 移除所有的选择和calloutView
            for (CustomAnnotationView *cusView in self.customAnnotation) {
                cusView.selectAnnotation = NO;
                [cusView.calloutView removeFromSuperview];
                cusView.selected = NO;
            }
            
            
        }
        
    }
    
    
}

/*!
 计算当前ZoomLevel下屏幕上一点对应的MapPoints点数
 @return mapPoints点数
 */
- (double)mapPointsPerPointInViewAtCurrentZoomLevel
{
    
    return [self.mapView metersPerPointForCurrentZoom] * MAMapPointsPerMeterAtLatitude(self.mapView.centerCoordinate.latitude);
}


- (void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation
{
    if (!updatingLocation && self.userLocationAnnotationView != nil)
    {
        
        [UIView animateWithDuration:0.1 animations:^{
            
            double degree = userLocation.heading.trueHeading - self.mapView.rotationDegree;
            self.userLocationAnnotationView.transform = CGAffineTransformMakeRotation(degree * M_PI / 180.f );
            
        }];
        
    }
}

#pragma mark--点击标注的时候事件
- (void)mapView:(MAMapView *)mapView annotationView:(MAAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
    
    
}


- (BOOL)shouldAutorotate {
    return NO;
}


#pragma mark - InitializationAnnotations
- (void)initAnnotations {
    self.annotations = [NSMutableArray array];
    
    CLLocationCoordinate2D coordinates[10] = {
        {39.977936, 116.308244},
        {39.976938, 116.308734},
        {39.976805, 116.307282},
        {39.976960, 116.305166},
        {39.977911, 116.305817},
        {39.978852, 116.306270},
        {39.979109, 116.307307},
        {39.979148, 116.308315},
        {39.978737, 116.308821},
        {39.978690, 116.306589}};
    
    for (int i = 0; i < 10; ++i) {
        MAPointAnnotation *a1 = [[MAPointAnnotation alloc] init];
        a1.coordinate = coordinates[i];
        a1.title = [NSString stringWithFormat:@"anno: %d", i];
        [self.annotations addObject:a1];
    }
    
}

#pragma mark - NextAnnotations
- (void)initNextAnnotations {
    self.nextAnnotations = [NSMutableArray array];
    
    CLLocationCoordinate2D coordinates[10] = {
        {39.979940, 116.307202},
        {39.980914, 116.307980},
        {39.981438, 116.306618},
        {39.981386, 116.306139},
        {39.981386, 116.305397},
        {39.981005, 116.304990},
        {39.980519, 116.305008},
        {39.979996, 116.304953},
        {39.979247, 116.304990},
        {39.981666, 116.305141}};
    
    for (int i = 0; i < 10; ++i) {
        MAPointAnnotation *a1 = [[MAPointAnnotation alloc] init];
        a1.coordinate = coordinates[i];
        a1.title = [NSString stringWithFormat:@"anno: %d", i];
        [self.nextAnnotations addObject:a1];
    }
    
}


- (CGSize)offsetToContainRect:(CGRect)innerRect inRect:(CGRect)outerRect {
    CGFloat nudgeRight = fmaxf(0, CGRectGetMinX(outerRect) - (CGRectGetMinX(innerRect)));
    CGFloat nudgeLeft = fminf(0, CGRectGetMaxX(outerRect) - (CGRectGetMaxX(innerRect)));
    CGFloat nudgeTop = fmaxf(0, CGRectGetMinY(outerRect) - (CGRectGetMinY(innerRect)));
    CGFloat nudgeBottom = fminf(0, CGRectGetMaxY(outerRect) - (CGRectGetMaxY(innerRect)));
    return CGSizeMake(nudgeLeft ?: nudgeRight, nudgeTop ?: nudgeBottom);
}


#pragma mark--点击某个标注
- (void)mapView:(MAMapView *)mapView didSelectAnnotationView:(MAAnnotationView *)view {
    /* Adjust the map center in order to show the callout view completely. */
    
    if ([view isKindOfClass:[CustomAnnotationView class]]) {
        CustomAnnotationView *cusView = (CustomAnnotationView *)view;
        CGRect frame = [cusView convertRect:cusView.calloutView.frame toView:self.mapView];
        
        
        // 设置终点位置
        self.endPoint  = [AMapNaviPoint locationWithLatitude:cusView.coordinate.latitude longitude:cusView.coordinate.longitude];
        
        
        frame = UIEdgeInsetsInsetRect(frame, UIEdgeInsetsMake(kCalloutViewMargin, kCalloutViewMargin, kCalloutViewMargin, kCalloutViewMargin));
        
        if (!CGRectContainsRect(self.mapView.frame, frame))
        {
            /* Calculate the offset to make the callout view show up. */
            CGSize offset = [self offsetToContainRect:frame inRect:self.mapView.frame];
            offset.height = offset.height + 64;
            
            CGPoint theCenter = self.mapView.center;
            theCenter = CGPointMake(theCenter.x - offset.width, theCenter.y - offset.height);
            
            CLLocationCoordinate2D coordinate = [self.mapView convertPoint:theCenter toCoordinateFromView:self.mapView];
            
            [self.mapView setCenterCoordinate:coordinate animated:YES];
            
            // 初始化出发点位置
            //self.startPoint = [AMapNaviPoint locationWithLatitude:coordinate.latitude longitude:coordinate.longitude];
            
        }
        
        
        // 防止对单个地址进行重复导航
        if (cusView.selectAnnotation == YES) {
            return;
        }
        
        [self startDrawLine];
        
        cusView.selectAnnotation = cusView.selected;
        for (CustomAnnotationView *cView in self.customAnnotation) {
            if (cView == cusView) {
                cView.selectAnnotation = YES;
            } else {
                cView.selectAnnotation = NO;
                [cView.calloutView removeFromSuperview];
                cView.selected = NO;
            }
        }
        
    }
    
}


#pragma mark--开始规划线路
- (void)startDrawLine {
    
    //进行多路径规划并绘制
    self.isMultipleRoutePlan = YES;
    [[AMapNaviDriveManager sharedInstance] setMultipleRouteNaviMode:YES];
    // 如果self.startPoint或者self.endPoint为空就会发生闪退
    [[AMapNaviDriveManager sharedInstance] calculateDriveRouteWithStartPoints:@[self.startPoint]
                                                                    endPoints:@[self.endPoint]
                                                                    wayPoints:nil
                                                              drivingStrategy:[self strategyWithIsMultiple:self.isMultipleRoutePlan]];
    
}


- (AMapNaviDrivingStrategy)strategyWithIsMultiple:(BOOL)isMultiple {
    return ConvertDrivingPreferenceToDrivingStrategy(isMultiple,
                                                     NO,
                                                     NO,
                                                     NO,
                                                     NO);
}


- (NSMutableArray *)customAnnotation {
    if (!_customAnnotation) {
        _customAnnotation = [[NSMutableArray alloc] init];
    }
    return _customAnnotation;
}


- (NSMutableArray *)nextAnnotations {
    if (!_nextAnnotations) {
        _nextAnnotations = [[NSMutableArray alloc] init];
    }
    return _nextAnnotations;
}



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end








