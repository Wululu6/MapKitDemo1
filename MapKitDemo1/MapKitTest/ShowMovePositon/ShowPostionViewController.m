//
//  ShowPostionViewController.m
//  MapKitTest
//
//  Created by apple on 2019/7/23.
//  Copyright © 2019年 apple. All rights reserved.
//

#import "ShowPostionViewController.h"

#import <MAMapKit/MAMapKit.h>

#import <AMapSearchKit/AMapSearchAPI.h>

#import <AMapLocationKit/AMapLocationManager.h>

#import "RoundViewController.h"


#define DefaultLocationTimeout  6
#define DefaultReGeocodeTimeout 3

@interface ShowPostionViewController ()<MAMapViewDelegate,AMapSearchDelegate,AMapLocationManagerDelegate>

@property (nonatomic, strong) MAMapView *mapView;

@property (nonatomic, strong) MAAnnotationView *userLocationAnnotationView;

@property (nonatomic, strong) AMapSearchAPI *searchAPI;

@property (nonatomic, strong) AMapLocationManager *locationManager;

@property (nonatomic, strong) CLLocation *location;

@property (nonatomic, strong) NSMutableArray *addressArray;

// 大头针
@property (nonatomic, strong) UIImageView *pinView;

@property (nonatomic, assign) CLLocationCoordinate2D lastLocation;

@property (nonatomic, strong) UILabel *positonLabel;

@property (nonatomic, copy) AMapLocatingCompletionBlock completionBlock;

@end

@implementation ShowPostionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = @"移动显示位置";
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.mapView = [[MAMapView alloc] initWithFrame:CGRectMake(20, 64 + 100, self.view.frame.size.width - 40, self.view.frame.size.height - 64 - 150)];
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
    
    [self creatPinView];
    
    [self creatPostionLabel];
    
    // 初始化搜索
    self.searchAPI = [[AMapSearchAPI alloc] init];
    self.searchAPI.delegate = self;
    
    [self initCompleteBlock];
    
    [self configLocationManager];
    
}

#pragma mark - Initialization
- (void)initCompleteBlock {
    __weak ShowPostionViewController *weakSelf = self;
    self.completionBlock = ^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
        if (error != nil && error.code == AMapLocationErrorLocateFailed) {
            //定位错误：此时location和regeocode没有返回值，不进行annotation的添加
            // 重新进行,单次定位
            [weakSelf.locationManager requestLocationWithReGeocode:YES completionBlock:weakSelf.completionBlock];
            NSLog(@"定位错误:{%ld - %@};", (long)error.code, error.userInfo);
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
            weakSelf.positonLabel.text = [NSString stringWithFormat:@"%@", regeocode.formattedAddress];
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
    self.pinView.center = CGPointMake((self.view.frame.size.width - 40) * 0.5, (self.view.frame.size.height - 64 - 150) * 0.5);
    self.pinView.hidden = NO;
    [self.mapView addSubview:self.pinView];
    
}

#pragma mark--creatPostionLabel
- (void)creatPostionLabel {
    
    self.positonLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 64 + 20, self.view.frame.size.width - 40, 60)];
    self.positonLabel.font = [UIFont systemFontOfSize:15];
    self.positonLabel.textColor = [UIColor cyanColor];
    self.positonLabel.backgroundColor = [UIColor grayColor];
    self.positonLabel.numberOfLines = 2;
    
    [self.view addSubview:self.positonLabel];
    
}

#pragma mark--移动地图的时候点击事件
- (void)mapView:(MAMapView *)mapView mapDidMoveByUser:(BOOL)wasUserAction {
    if (!wasUserAction) {
        return;
    }
    CGPoint center = CGPointMake(self.mapView.bounds.size.width * 0.5, self.mapView.bounds.size.height * 0.5);
    CLLocationCoordinate2D coor2d = [mapView convertPoint:center toCoordinateFromView:self.mapView];
    self.lastLocation = coor2d;
    
    // ReGEO解析
    AMapReGeocodeSearchRequest *request = [[AMapReGeocodeSearchRequest alloc] init];
    request.location = [AMapGeoPoint locationWithLatitude:coor2d.latitude longitude:coor2d.longitude];
    [self.searchAPI AMapReGoecodeSearch:request];
    
}

- (void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response {
    NSString *address = response.regeocode.formattedAddress;
    self.positonLabel.text = address;
    
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
    
    // ReGEO解析
//    AMapReGeocodeSearchRequest *request = [[AMapReGeocodeSearchRequest alloc] init];
//    request.location = [AMapGeoPoint locationWithLatitude:location.coordinate.latitude longitude:location.coordinate.longitude];
//    [self.searchAPI AMapReGoecodeSearch:request];
    
}

- (void)reloadMap {
    
    MACoordinateRegion region = MACoordinateRegionMake(self.location.coordinate, MACoordinateSpanMake(0.25, 0.25)) ;
    [self.mapView setRegion:[self.mapView regionThatFits:region] animated:YES];
    
    [self.mapView setZoomLevel:17.0];
    
}


#pragma mark--MAMapViewDelegate
- (void)mapViewRequireLocationAuth:(CLLocationManager *)locationManager {
    [locationManager requestAlwaysAuthorization];
}

- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id <MAOverlay>)overlay
{
    /* 自定义定位精度对应的MACircleView. */
    if (overlay == mapView.userLocationAccuracyCircle)
    {
        MACircleRenderer *accuracyCircleRenderer = [[MACircleRenderer alloc] initWithCircle:overlay];
        
        accuracyCircleRenderer.lineWidth    = 2.f;
        accuracyCircleRenderer.strokeColor  = [UIColor lightGrayColor];
        accuracyCircleRenderer.fillColor    = [UIColor colorWithRed:1 green:0 blue:0 alpha:.3];
        
        return accuracyCircleRenderer;
    }
    
    return nil;
}

- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
{
    
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
