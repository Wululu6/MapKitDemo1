//
//  RoutePlanDriveViewController.m
//  MapKitTest
//
//  Created by apple on 2019/7/30.
//  Copyright © 2019 apple. All rights reserved.
//

#import "RoutePlanDriveViewController.h"

#import <MAMapKit/MAMapKit.h>
#import <AMapSearchKit/AMapSearchAPI.h>
#import <AMapLocationKit/AMapLocationManager.h>
#import <AMapNaviKit/AMapNaviKit.h>

#import "NaviPointAnnotation.h"
#import "SelectableOverlay.h"
#import "MultiDriveRoutePolyline.h"
#import "Utility.h"

#define kRoutePlanInfoViewHeight    80.f
#define kRouteIndicatorViewHeight   50.f
#define AMapNaviRoutePolylineDefaultWidth  20.f


@interface RoutePlanDriveViewController ()<MAMapViewDelegate,AMapNaviDriveManagerDelegate>

@property (nonatomic, strong) AMapNaviPoint *startPoint;
@property (nonatomic, strong) AMapNaviPoint *endPoint;

@property (nonatomic, strong) UILabel *detailDataLabel;

@property (nonatomic, assign) BOOL isMultipleRoutePlan;

@property (nonatomic, strong) MAMapView *mapView;

@property (nonatomic, strong) UIView *preferenceView;

@property (nonatomic, strong) UIView *maskView;

@end

@implementation RoutePlanDriveViewController

- (void)dealloc {
    BOOL success = [AMapNaviDriveManager destroyInstance];
    NSLog(@"单例是否销毁成功 : %d",success);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self initAnnotations];
}

- (void)initAnnotations {
    
    NaviPointAnnotation *beginAnnotation = [[NaviPointAnnotation alloc] init];
    [beginAnnotation setCoordinate:CLLocationCoordinate2DMake(self.startPoint.latitude, self.startPoint.longitude)];
    beginAnnotation.title = @"起始点";
    beginAnnotation.navPointType = NaviPointAnnotationStart;
    
    [self.mapView addAnnotation:beginAnnotation];
    
    NaviPointAnnotation *endAnnotation = [[NaviPointAnnotation alloc] init];
    [endAnnotation setCoordinate:CLLocationCoordinate2DMake(self.endPoint.latitude, self.endPoint.longitude)];
    endAnnotation.title = @"终点";
    endAnnotation.navPointType = NaviPointAnnotationEnd;
    
    [self.mapView addAnnotation:endAnnotation];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = @"展示交通路线";
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self initProperties];
    
    [self initMapView];
    
    [self initDriveManager];
    
    [self configSubViews];
    
    [self initMaskView];
    
}

- (void)configSubViews {

    self.preferenceView = [[UIView alloc] initWithFrame:CGRectMake(0, 64, CGRectGetWidth(self.view.bounds), 60)];
    self.preferenceView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.preferenceView];
    
    UIButton *singleRouteBtn = [self createToolButton];
    [singleRouteBtn setFrame:CGRectMake((CGRectGetWidth(self.view.bounds)-220)/2.0, 15, 100, 30)];
    [singleRouteBtn setTitle:@"单路径规划" forState:UIControlStateNormal];
    [singleRouteBtn addTarget:self action:@selector(singleRoutePlanAction:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.preferenceView addSubview:singleRouteBtn];
    
    UIButton *multipleRouteBtn = [self createToolButton];
    [multipleRouteBtn setFrame:CGRectMake((CGRectGetWidth(self.view.bounds)-220)/2.0+110, 15, 100, 30)];
    [multipleRouteBtn setTitle:@"多路径规划" forState:UIControlStateNormal];
    [multipleRouteBtn addTarget:self action:@selector(multipleRoutePlanAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.preferenceView addSubview:multipleRouteBtn];
}


- (void)initMaskView {
    
    // 创建容器
    self.maskView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 64, CGRectGetWidth(self.view.frame), 64)];
    self.maskView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.maskView];
    self.detailDataLabel = [[UILabel alloc] initWithFrame:self.maskView.bounds];
    self.detailDataLabel.font = [UIFont systemFontOfSize:15.0];
    [self.maskView addSubview:self.detailDataLabel];
    
}


- (UIButton *)createToolButton  {
    UIButton *toolBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    
    toolBtn.layer.borderColor  = [UIColor lightGrayColor].CGColor;
    toolBtn.layer.borderWidth  = 0.5;
    toolBtn.layer.cornerRadius = 5;
    
    [toolBtn setBounds:CGRectMake(0, 0, 80, 30)];
    [toolBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    toolBtn.titleLabel.font = [UIFont systemFontOfSize:13.0];
    
    return toolBtn;
}

#pragma mark - Button Action单路径规划
- (void)singleRoutePlanAction:(id)sender {
    
    //进行单路径规划
    self.isMultipleRoutePlan = NO;
    [[AMapNaviDriveManager sharedInstance] calculateDriveRouteWithStartPoints:@[self.startPoint]
                                                                    endPoints:@[self.endPoint]
                                                                    wayPoints:nil
                                                              drivingStrategy:[self strategyWithIsMultiple:self.isMultipleRoutePlan]];
    
}


#pragma mark - Button Action多路径规划
- (void)multipleRoutePlanAction:(id)sender {
    //进行多路径规划
    self.isMultipleRoutePlan = YES;
    [[AMapNaviDriveManager sharedInstance] setMultipleRouteNaviMode:YES];
    [[AMapNaviDriveManager sharedInstance] calculateDriveRouteWithStartPoints:@[self.startPoint]
                                                                    endPoints:@[self.endPoint]
                                                                    wayPoints:nil
                                                              drivingStrategy:[self strategyWithIsMultiple:self.isMultipleRoutePlan]];
}

- (AMapNaviDrivingStrategy)strategyWithIsMultiple:(BOOL)isMultiple
{
    return ConvertDrivingPreferenceToDrivingStrategy(isMultiple,
                                                     NO,
                                                     NO,
                                                     NO,
                                                     NO);
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
        self.detailDataLabel.text = [NSString stringWithFormat:@"长度:%ld米 | 预估时间:%ld秒 | 分段数:%ld", (long)aRoute.routeLength, (long)aRoute.routeTime, (long)aRoute.routeSegments.count];
        
    }
    
    
    
    //为了方便展示驾车多路径规划，选择了固定的起终点
    //self.startPoint = [AMapNaviPoint locationWithLatitude:39.993135 longitude:116.474175];
    //self.endPoint   = [AMapNaviPoint locationWithLatitude:39.908791 longitude:116.321257];
    
    // 添不添加都可以
    [self.mapView setCenterCoordinate:CLLocationCoordinate2DMake((39.993135 + 39.908791) * 0.5, (116.474175 + 116.321257) * 0.5)];
    
    [self.mapView showAnnotations:self.mapView.annotations animated:NO];
    
    if ([[AMapNaviDriveManager sharedInstance].naviRoutes allKeys].count > 0) {
        NSNumber *aRouteID = [[[AMapNaviDriveManager sharedInstance].naviRoutes allKeys] firstObject];
        [self selectNaviRouteWithID:[aRouteID integerValue]];
    } else {
        [self selectNaviRouteWithID:0];
    }
    
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
//    NSBundle *myBundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"AMapNavi" ofType:@"bundle"]];
//    NSString *img_path = [[myBundle resourcePath] stringByAppendingPathComponent:imageName];
//    [[NSBundle mainBundle]pathForResource:@"AMapNavi" ofType:@"bundle"];
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

#pragma mark - MAMapView Delegate
- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
{
    if ([annotation isKindOfClass:[NaviPointAnnotation class]])
    {
        static NSString *annotationIdentifier = @"NaviPointAnnotationIdentifier";
        
        MAPinAnnotationView *pointAnnotationView = (MAPinAnnotationView*)[self.mapView dequeueReusableAnnotationViewWithIdentifier:annotationIdentifier];
        if (pointAnnotationView == nil)
        {
            pointAnnotationView = [[MAPinAnnotationView alloc] initWithAnnotation:annotation
                                                                  reuseIdentifier:annotationIdentifier];
        }
        
        pointAnnotationView.animatesDrop   = NO;
        pointAnnotationView.canShowCallout = YES;
        pointAnnotationView.draggable      = NO;
        
        NaviPointAnnotation *navAnnotation = (NaviPointAnnotation *)annotation;
        
        if (navAnnotation.navPointType == NaviPointAnnotationStart)
        {
            [pointAnnotationView setPinColor:MAPinAnnotationColorGreen];
        }
        else if (navAnnotation.navPointType == NaviPointAnnotationEnd)
        {
            [pointAnnotationView setPinColor:MAPinAnnotationColorRed];
        }
        
        return pointAnnotationView;
    }
    return nil;
}

- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id<MAOverlay>)overlay {
    if ([overlay isKindOfClass:[SelectableOverlay class]]) {
        SelectableOverlay * selectableOverlay = (SelectableOverlay *)overlay;
        id<MAOverlay> actualOverlay = selectableOverlay.overlay;
        
        MAPolylineRenderer *polylineRenderer = [[MAPolylineRenderer alloc] initWithPolyline:actualOverlay];
        
        polylineRenderer.lineWidth = 8.f;
        polylineRenderer.strokeColor = selectableOverlay.isSelected ? selectableOverlay.selectedColor : selectableOverlay.regularColor;
        
        return polylineRenderer;
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


- (void)initProperties {
    //为了方便展示驾车多路径规划，选择了固定的起终点
    self.startPoint = [AMapNaviPoint locationWithLatitude:39.993135 longitude:116.474175];
    self.endPoint   = [AMapNaviPoint locationWithLatitude:39.908791 longitude:116.321257];
}

- (void)initDriveManager {
    //请在 dealloc 函数中执行 [AMapNaviDriveManager destroyInstance] 来销毁单例
    [[AMapNaviDriveManager sharedInstance] setDelegate:self];
}

- (void)initMapView {
    if (self.mapView == nil)  {
        self.mapView = [[MAMapView alloc] initWithFrame:CGRectMake(0, kRoutePlanInfoViewHeight,
                                                                   self.view.bounds.size.width,
                                                                   self.view.bounds.size.height - kRoutePlanInfoViewHeight)];
        [self.mapView setDelegate:self];
        [self.view addSubview:self.mapView];
        
        self.mapView.visibleMapRect = MAMapRectMake(220880104, 101476980, 272496, 466656);
        
    }
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
