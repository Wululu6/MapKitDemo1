//
//  FindRoundPositionViewController.m
//  MapKitTest
//
//  Created by apple on 2019/7/23.
//  Copyright © 2019年 apple. All rights reserved.
//

#import "FindRoundPositionViewController.h"

#import <MAMapKit/MAMapKit.h>

#import <AMapSearchKit/AMapSearchAPI.h>

#import <AMapLocationKit/AMapLocationManager.h>

#import "RoundViewController.h"


#define DefaultLocationTimeout  6
#define DefaultReGeocodeTimeout 3

#define kCalloutViewMargin  -8

#import "CustomAnnotationView.h"


enum {
    AnnotationViewControllerAnnotationTypeRed = 0,
    AnnotationViewControllerAnnotationTypeGreen,
    AnnotationViewControllerAnnotationTypePurple
};


@interface FindRoundPositionViewController ()<MAMapViewDelegate,AMapSearchDelegate,AMapLocationManagerDelegate>

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

@end

@implementation FindRoundPositionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading
    
    self.title = @"找到临近点的停车位";
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    
    [self initAnnotations];
    
    //CGRectMake(0, 64, self.view.frame.size.width, self.view.frame.size.height - 64)
    //self.view.bounds
    self.mapView = [[MAMapView alloc] initWithFrame:CGRectMake(0, 64, self.view.frame.size.width, self.view.frame.size.height - 64)];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    
    self.mapView.mapType = MAMapTypeStandard;
    
    // 禁止旋转
    self.mapView.rotateEnabled = NO;
    // 禁止立体旋转
    self.mapView.rotateCameraEnabled = NO;
    
    self.mapView.showsBuildings = NO;
    
    //self.mapView.showTraffic = YES;
    
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
    
    //[self.mapView showAnnotations:self.annotations animated:YES];
    
    [self creatPinView];
    
}

#pragma mark - Initialization
- (void)initCompleteBlock {
    __weak FindRoundPositionViewController *weakSelf = self;
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
    
    self.pinView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 48, 48)];
    self.pinView.image = [UIImage imageNamed:@"mapimage"];
    self.pinView.center = CGPointMake(self.view.frame.size.width * 0.5, (self.view.frame.size.height - 64) * 0.5);
    self.pinView.hidden = NO;
    [self.mapView addSubview:self.pinView];
    
}


#pragma mark--移动地图的时候点击事件
- (void)mapView:(MAMapView *)mapView mapDidMoveByUser:(BOOL)wasUserAction {
    if (!wasUserAction) {
        return;
    }
    CGPoint center = CGPointMake(self.mapView.bounds.size.width * 0.5, self.mapView.bounds.size.height * 0.5);
    CLLocationCoordinate2D coor2d = [mapView convertPoint:center toCoordinateFromView:self.mapView];
    self.lastLocation = coor2d;
    
    
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
        return 17.0;
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


//当进行单次带逆地理定位请求的时候此函数不会被调用
- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode {
    // 定位结果
    NSLog(@"location:{lat:%f; lon:%f; accuracy:%f}", location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy);
    // 赋值给全局变量
    self.location = location;
    // 停止定位
    [self.locationManager stopUpdatingLocation];
    
    [self performSelector:@selector(reloadMap) withObject:nil afterDelay:0.1];
    
}


- (void)reloadMap {
    
    MACoordinateRegion region = MACoordinateRegionMake(self.location.coordinate, MACoordinateSpanMake(0.25, 0.25)) ;
    [self.mapView setRegion:[self.mapView regionThatFits:region] animated:YES];

    [self.mapView setZoomLevel:17.5];
    
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
    }
    
    return nil;
}


#pragma mark--标注所对应显示样式
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
        
        annotationView.portrait = [UIImage imageNamed:@"parking"];
        annotationView.name = @"停车";
        
        return annotationView;
    }
    
    return nil;
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


- (CGSize)offsetToContainRect:(CGRect)innerRect inRect:(CGRect)outerRect
{
    CGFloat nudgeRight = fmaxf(0, CGRectGetMinX(outerRect) - (CGRectGetMinX(innerRect)));
    CGFloat nudgeLeft = fminf(0, CGRectGetMaxX(outerRect) - (CGRectGetMaxX(innerRect)));
    CGFloat nudgeTop = fmaxf(0, CGRectGetMinY(outerRect) - (CGRectGetMinY(innerRect)));
    CGFloat nudgeBottom = fminf(0, CGRectGetMaxY(outerRect) - (CGRectGetMaxY(innerRect)));
    return CGSizeMake(nudgeLeft ?: nudgeRight, nudgeTop ?: nudgeBottom);
}


- (void)mapView:(MAMapView *)mapView didSelectAnnotationView:(MAAnnotationView *)view
{
    /* Adjust the map center in order to show the callout view completely. */
    if ([view isKindOfClass:[CustomAnnotationView class]]) {
        CustomAnnotationView *cusView = (CustomAnnotationView *)view;
        CGRect frame = [cusView convertRect:cusView.calloutView.frame toView:self.mapView];
        
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
        }
        
    }
    
    
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
