//
//  FindPositionDrawLineViewController.m
//  MapKitTest
//
//  Created by apple on 2019/7/31.
//  Copyright © 2019 apple. All rights reserved.
//

#import "FindPositionDrawLineViewController.h"

#import <MAMapKit/MAMapKit.h>

#import <AMapSearchKit/AMapSearchAPI.h>

#import <AMapLocationKit/AMapLocationManager.h>

#import "SearchViewController.h"

#import <AMapNaviKit/AMapNaviKit.h>
#import "SelectableOverlay.h"
#import "MultiDriveRoutePolyline.h"
#import "Utility.h"

#import "CommonUtility.h"


#define DefaultLocationTimeout  6
#define DefaultReGeocodeTimeout 3

#define AMapNaviRoutePolylineDefaultWidth  20.f

static const NSInteger RoutePlanningPaddingEdge                    = 20;

@interface FindPositionDrawLineViewController ()<MAMapViewDelegate,AMapSearchDelegate,AMapLocationManagerDelegate,AMapNaviDriveManagerDelegate>

@property (nonatomic, strong) MAMapView *mapView;
@property (nonatomic, strong) MAAnnotationView *userLocationAnnotationView;

@property (nonatomic, strong) AMapSearchAPI *searchAPI;

@property (nonatomic, strong) AMapLocationManager *locationManager;

@property (nonatomic, strong) CLLocation *location;

@property (nonatomic, strong) NSMutableArray *addressArray;

@property (nonatomic, copy) AMapLocatingCompletionBlock completionBlock;

@property (nonatomic, strong) NSString *city;

@property (nonatomic, strong) AMapNaviPoint *startPoint;

@property (nonatomic, strong) AMapNaviPoint *endPoint;

@property (nonatomic, assign) BOOL isMultipleRoutePlan;

@end

@implementation FindPositionDrawLineViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.title = @"搜索地址并添加路线";
    
    self.mapView = [[MAMapView alloc] initWithFrame:CGRectMake(0, 64, self.view.frame.size.width, self.view.frame.size.height - 64)];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    
    self.mapView.mapType = MAMapTypeStandard;
    
    self.mapView.showsCompass = YES;
    
    // 禁止旋转
    self.mapView.rotateEnabled = NO;
    // 禁止立体旋转
    self.mapView.rotateCameraEnabled = NO;
    
    self.mapView.showsBuildings = NO;
    
    self.mapView.showsUserLocation = YES;
    self.mapView.userTrackingMode = MAUserTrackingModeFollow;
    
    [self.view addSubview:self.mapView];
    
    
    [self initCompleteBlock];
    
    [self configLocationManager];
    
    [self creatRightItem];
    
    // 创建行车管理者
    [self initDriveManager];
    
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

#pragma mark - Initialization
- (void)initCompleteBlock {
    __weak FindPositionDrawLineViewController *weakSelf = self;
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
                       || error.code == AMapLocationErrorCannotConnectToHost)) {
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
            
            
            NSString *address = [NSString stringWithFormat:@"%@%@%@",regeocode.province,regeocode.city,regeocode.district];
            weakSelf.title = address;
            
            weakSelf.city = regeocode.city;
            
            //            [annotation setTitle:[NSString stringWithFormat:@"%@", regeocode.formattedAddress]];
            //            [annotation setSubtitle:[NSString stringWithFormat:@"%@-%@-%.2fm", regeocode.citycode, regeocode.adcode, location.horizontalAccuracy]];
        } else {
            //            [annotation setTitle:[NSString stringWithFormat:@"lat:%f;lon:%f;", location.coordinate.latitude, location.coordinate.longitude]];
            //            [annotation setSubtitle:[NSString stringWithFormat:@"accuracy:%.2fm", location.horizontalAccuracy]];
        }
        
        [weakSelf performSelector:@selector(reloadMap) withObject:nil afterDelay:0.1];
        
    };
    
}

#pragma mark--创建右侧的周围环境
- (void)creatRightItem {
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"去搜索" style:(UIBarButtonItemStylePlain) target:self action:@selector(rightItemAction)];
    self.navigationItem.rightBarButtonItem = item;
}

- (void)initDriveManager {
    //请在 dealloc 函数中执行 [AMapNaviDriveManager destroyInstance] 来销毁单例
    [[AMapNaviDriveManager sharedInstance] setDelegate:self];
}

#pragma mark--进入右侧周围的环境事件
- (void)rightItemAction {
    
    SearchViewController *searchVc = [[SearchViewController alloc] init];
    
    searchVc.roundArray = self.addressArray;
    searchVc.city = self.city;
    
    __weak FindPositionDrawLineViewController *weakSelf = self;
    searchVc.selectPositionBlock = ^(AMapTip * _Nonnull Location) {
        
        [weakSelf.mapView removeAnnotations:weakSelf.mapView.annotations];
        
        CLLocationCoordinate2D coordinate = {
            Location.location.latitude,Location.location.longitude
        };
        
        
        
        [weakSelf.mapView setCenterCoordinate:coordinate];
        
        MAPointAnnotation *a1 = [[MAPointAnnotation alloc] init];
        a1.coordinate = coordinate;
        a1.title = [NSString stringWithFormat:@"anno: %@",Location.name];
        
        [weakSelf.mapView addAnnotation:a1];
        [weakSelf.mapView selectAnnotation:a1 animated:YES];
        
        [weakSelf.mapView setZoomLevel:17.5];
        
        // 设置终点位置，并绘制彩色路线
        self.endPoint   = [AMapNaviPoint locationWithLatitude:coordinate.latitude longitude:coordinate.longitude];
        
        
        //进行多路径规划并绘制
        self.isMultipleRoutePlan = YES;
        [[AMapNaviDriveManager sharedInstance] setMultipleRouteNaviMode:YES];
        [[AMapNaviDriveManager sharedInstance] calculateDriveRouteWithStartPoints:@[self.startPoint]
                                                                        endPoints:@[self.endPoint]
                                                                        wayPoints:nil
                                                                  drivingStrategy:[self strategyWithIsMultiple:self.isMultipleRoutePlan]];
    };
    
    
    [self.navigationController pushViewController:searchVc animated:YES];
    
}

- (AMapNaviDrivingStrategy)strategyWithIsMultiple:(BOOL)isMultiple
{
    return ConvertDrivingPreferenceToDrivingStrategy(isMultiple,
                                                     NO,
                                                     NO,
                                                     NO,
                                                     NO);
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
    
    
    //将路径显示到地图上(倒序添加)
    //    NSUInteger countant = [[AMapNaviDriveManager sharedInstance].naviRoutes allKeys].count;
    //    for (long i = countant - 1; i >= 0; i--) {
    //        NSNumber *aRouteID  = [[[AMapNaviDriveManager sharedInstance].naviRoutes allKeys] objectAtIndex:i];
    //        AMapNaviRoute *aRoute = [[[AMapNaviDriveManager sharedInstance] naviRoutes] objectForKey:aRouteID];
    //        int count = (int)[[aRoute routeCoordinates] count];
    //
    //        //添加路径Polyline
    //        CLLocationCoordinate2D *coords = (CLLocationCoordinate2D *)malloc(count * sizeof(CLLocationCoordinate2D));
    //        for (int i = 0; i < count; i++) {
    //            AMapNaviPoint *coordinate = [[aRoute routeCoordinates] objectAtIndex:i];
    //            coords[i].latitude = [coordinate latitude];
    //            coords[i].longitude = [coordinate longitude];
    //        }
    //
    //        NSMutableArray<UIImage *> *textureImagesArrayNormal = [NSMutableArray new];
    //        NSMutableArray<UIImage *> *textureImagesArraySelected = [NSMutableArray new];
    //
    //        // 添加路况图片
    //        for (AMapNaviTrafficStatus *status in aRoute.routeTrafficStatuses) {
    //            UIImage *img = [self defaultTextureImageForRouteStatus:status.status isSelected:NO];
    //            UIImage *selImg = [self defaultTextureImageForRouteStatus:status.status isSelected:YES];
    //            if (img && selImg) {
    //                [textureImagesArrayNormal addObject:img];
    //                [textureImagesArraySelected addObject:selImg];
    //            }
    //        }
    //
    //        MultiDriveRoutePolyline *mulPolyline = [MultiDriveRoutePolyline polylineWithCoordinates:coords count:count drawStyleIndexes:aRoute.drawStyleIndexes];
    //        mulPolyline.overlay = mulPolyline;
    //        mulPolyline.polylineTextureImages = textureImagesArrayNormal;
    //        mulPolyline.polylineTextureImagesSeleted = textureImagesArraySelected;
    //        mulPolyline.routeID = aRouteID.integerValue;
    //        mulPolyline.routeIDNumber = aRouteID;
    //
    //        [self.mapView addOverlay:mulPolyline];
    //
    //
    //        free(coords);
    //
    //        //更新CollectonView的信息
    //        RouteCollectionViewInfo *info = [[RouteCollectionViewInfo alloc] init];
    //        info.routeID = [aRouteID integerValue];
    //        info.title = [NSString stringWithFormat:@"路径ID:%ld | 路径计算策略:%ld (点击展示路线详情)", (long)[aRouteID integerValue], (long)[self.preferenceView strategyWithIsMultiple:self.isMultipleRoutePlan]];
    //        info.subtitle = [NSString stringWithFormat:@"长度:%ld米 | 预估时间:%ld秒 | 分段数:%ld", (long)aRoute.routeLength, (long)aRoute.routeTime, (long)aRoute.routeSegments.count];
    //
    //        [self.routeIndicatorInfoArray addObject:info];
    //
    //    }
    
    
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
        
        //更新CollectonView的信息
        //self.detailDataLabel.text = [NSString stringWithFormat:@"长度:%ld米 | 预估时间:%ld秒 | 分段数:%ld", (long)aRoute.routeLength, (long)aRoute.routeTime, (long)aRoute.routeSegments.count];
        
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


#pragma mark - AMapNaviDriveManager Delegate
- (void)driveManager:(AMapNaviDriveManager *)driveManager error:(NSError *)error {
    NSLog(@"error:{%ld - %@}", (long)error.code, error.localizedDescription);
}

- (void)driveManager:(AMapNaviDriveManager *)driveManager onCalculateRouteSuccessWithType:(AMapNaviRoutePlanType)type
{
    NSLog(@"onCalculateRouteSuccess");
    
    //算路成功后显示路径
    [self showMultiColorNaviRoutes];
    
    //构建路线数据模型
    //[self buildRouteDataSource];
}

- (void)driveManager:(AMapNaviDriveManager *)driveManager onCalculateRouteFailure:(NSError *)error routePlanType:(AMapNaviRoutePlanType)type
{
    NSLog(@"onCalculateRouteFailure:{%ld - %@}", (long)error.code, error.localizedDescription);
}

- (void)driveManager:(AMapNaviDriveManager *)driveManager didStartNavi:(AMapNaviMode)naviMode
{
    NSLog(@"didStartNavi");
}

- (void)driveManagerNeedRecalculateRouteForYaw:(AMapNaviDriveManager *)driveManager
{
    NSLog(@"needRecalculateRouteForYaw");
}

- (void)driveManagerNeedRecalculateRouteForTrafficJam:(AMapNaviDriveManager *)driveManager
{
    NSLog(@"needRecalculateRouteForTrafficJam");
}

- (void)driveManager:(AMapNaviDriveManager *)driveManager onArrivedWayPoint:(int)wayPointIndex
{
    NSLog(@"onArrivedWayPoint:%d", wayPointIndex);
}

- (BOOL)driveManagerIsNaviSoundPlaying:(AMapNaviDriveManager *)driveManager
{
    return NO;
}

- (void)driveManager:(AMapNaviDriveManager *)driveManager playNaviSoundString:(NSString *)soundString soundStringType:(AMapNaviSoundType)soundStringType
{
    NSLog(@"playNaviSoundString:{%ld:%@}", (long)soundStringType, soundString);
}

- (void)driveManagerDidEndEmulatorNavi:(AMapNaviDriveManager *)driveManager
{
    NSLog(@"didEndEmulatorNavi");
}

- (void)driveManagerOnArrivedDestination:(AMapNaviDriveManager *)driveManager
{
    NSLog(@"onArrivedDestination");
}

- (void)driveManager:(AMapNaviDriveManager *)driveManager onSuggestChangeMainNaviRoute:(AMapNaviSuggestChangeMainNaviRouteInfo *)suggestChangeMainNaviRouteInfo {
    
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

- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation {
    
    /* 自定义userLocation对应的annotationView. */
    if ([annotation isKindOfClass:[MAUserLocation class]]) {
        static NSString *userLocationStyleReuseIndetifier = @"userLocationStyleReuseIndetifier";
        MAAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:userLocationStyleReuseIndetifier];
        if (annotationView == nil) {
            annotationView = [[MAAnnotationView alloc] initWithAnnotation:annotation
                                                          reuseIdentifier:userLocationStyleReuseIndetifier];
        }
        
        annotationView.image = [UIImage imageNamed:@"userPosition"];
        
        //        annotationView.canShowCallout  = YES;
        //        UIView *view1 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
        //        view1.backgroundColor = [UIColor yellowColor];
        //        annotationView.customCalloutView = [[MACustomCalloutView alloc] initWithCustomView:view1];
        //        // 是否支持拖动
        //        annotationView.draggable = YES;
        
        self.userLocationAnnotationView = annotationView;
        
        return annotationView;
    } else if ([annotation isKindOfClass:[MAPointAnnotation class]])
    {
        static NSString *pointReuseIndetifier = @"pointReuseIndetifier";
        
        MAPinAnnotationView *annotationView = (MAPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIndetifier];
        if (annotationView == nil)
        {
            annotationView = [[MAPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pointReuseIndetifier];
        }
        
        annotationView.canShowCallout   = YES;
        annotationView.animatesDrop     = YES;
        annotationView.draggable        = NO;
        annotationView.pinColor         = MAPinAnnotationColorPurple;
        
        return annotationView;
    }
    
    return nil;
}


- (void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation {
    if (!updatingLocation && self.userLocationAnnotationView != nil) {
        
        [UIView animateWithDuration:0.1 animations:^{
            
            double degree = userLocation.heading.trueHeading - self.mapView.rotationDegree;
            self.userLocationAnnotationView.transform = CGAffineTransformMakeRotation(degree * M_PI / 180.f );
            
        }];
        
    }
}

// 点击地图的事件
- (void)mapView:(MAMapView *)mapView didSingleTappedAtCoordinate:(CLLocationCoordinate2D)coordinate {
    
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
    
}


/*!
 计算当前ZoomLevel下屏幕上一点对应的MapPoints点数
 @return mapPoints点数
 */
- (double)mapPointsPerPointInViewAtCurrentZoomLevel
{
    
    return [self.mapView metersPerPointForCurrentZoom] * MAMapPointsPerMeterAtLatitude(self.mapView.centerCoordinate.latitude);
}


- (BOOL)shouldAutorotate {
    return NO;
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
