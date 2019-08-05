//
//  MovePostionViewController.m
//  MapKitTest
//
//  Created by apple on 2019/7/22.
//  Copyright © 2019年 apple. All rights reserved.
//

#import "MovePostionViewController.h"

#import <MAMapKit/MAMapKit.h>

#import <AMapSearchKit/AMapSearchAPI.h>

#import <AMapLocationKit/AMapLocationManager.h>

#import "RoundViewController.h"


#define DefaultLocationTimeout  6
#define DefaultReGeocodeTimeout 3

@interface MovePostionViewController ()<MAMapViewDelegate,AMapSearchDelegate,AMapLocationManagerDelegate>

@property (nonatomic, strong) MAMapView *mapView;

@property (nonatomic, strong) MAAnnotationView *userLocationAnnotationView;

@property (nonatomic, strong) AMapSearchAPI *searchAPI;

@property (nonatomic, strong) AMapLocationManager *locationManager;

@property (nonatomic, strong) CLLocation *location;

@property (nonatomic, strong) NSMutableArray *addressArray;

// 大头针
@property (nonatomic, strong) UIImageView *pinView;

@property (nonatomic, assign) CLLocationCoordinate2D lastLocation;

@end

@implementation MovePostionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = @"移动定位";
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    
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
    
    [self configLocationManager];
    
    [self creatRightItem];
    
    [self creatPinView];
    
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
    [self.locationManager startUpdatingLocation];
    
}

#pragma mark--创建右侧的周围环境
- (void)creatRightItem {
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"周围环境" style:(UIBarButtonItemStylePlain) target:self action:@selector(rightItemAction)];
    self.navigationItem.rightBarButtonItem = item;
}

#pragma mark--进入右侧周围的环境事件
- (void)rightItemAction {
    RoundViewController *roundVc = [[RoundViewController alloc] init];
    roundVc.roundArray = self.addressArray;
    [self.navigationController pushViewController:roundVc animated:YES];
}

#pragma mark--创建大头针
- (void)creatPinView {
    
    self.pinView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 48, 48)];
    self.pinView.image = [UIImage imageNamed:@"datouzhen"];
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
    
    // ReGEO解析
    AMapReGeocodeSearchRequest *request = [[AMapReGeocodeSearchRequest alloc] init];
    request.location = [AMapGeoPoint locationWithLatitude:coor2d.latitude longitude:coor2d.longitude];
    [self.searchAPI AMapReGoecodeSearch:request];
    
    // 进行周边搜索
    
    //构造AMapPOIAroundSearchRequest对象，设置周边请求参数
    AMapPOIAroundSearchRequest *requests = [[AMapPOIAroundSearchRequest alloc] init];
    requests.location = [AMapGeoPoint locationWithLatitude:coor2d.latitude longitude:coor2d.longitude];
    // types属性表示限定搜索POI的类别，默认为：餐饮服务|商务住宅|生活服务
    // POI的类型共分为20种大类别，分别为：
    // 汽车服务|汽车销售|汽车维修|摩托车服务|餐饮服务|购物服务|生活服务|体育休闲服务|
    // 医疗保健服务|住宿服务|风景名胜|商务住宅|政府机构及社会团体|科教文化服务|
    // 交通设施服务|金融保险服务|公司企业|道路附属设施|地名地址信息|公共设施
    requests.types = @"汽车服务|汽车销售|汽车维修|摩托车服务|餐饮服务|购物服务|生活服务|体育休闲服务|医疗保健服务|住宿服务|风景名胜|商务住宅|政府机构及社会团体|科教文化服务|交通设施服务|金融保险服务|公司企业|道路附属设施|地名地址信息|公共设施";
    requests.sortrule = 0;
    requests.requireExtension = YES;
    
    NSLog(@"周边再次搜索");
    
    //发起周边搜索
    [self.searchAPI AMapPOIAroundSearch:requests];
    
}

- (void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response {
    //NSString *address = response.regeocode.formattedAddress;
    // 定位结果
    NSLog(@"location:{lat:%f; lon:%f}", request.location.latitude, request.location.longitude);
    self.pinView.hidden = NO;
    [self.mapView setCenterCoordinate:self.lastLocation animated:YES];
    
}

- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode {
    // 定位结果
    NSLog(@"location:{lat:%f; lon:%f; accuracy:%f}", location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy);
    // 赋值给全局变量
    self.location = location;
    // 停止定位
    [self.locationManager stopUpdatingLocation];
    
    // 发起周边搜索
    [self searchAround];
    
    
    [self performSelector:@selector(reloadMap) withObject:nil afterDelay:0.1];
    
}

- (void)reloadMap {
    
    MACoordinateRegion region = MACoordinateRegionMake(self.location.coordinate, MACoordinateSpanMake(0.25, 0.25)) ;
    [self.mapView setRegion:[self.mapView regionThatFits:region] animated:YES];
    
    [self.mapView setZoomLevel:17.0];
    
}


- (void)searchAround {
    
    // 初始化搜索
    self.searchAPI = [[AMapSearchAPI alloc] init];
    self.searchAPI.delegate = self;
    
    //构造AMapPOIAroundSearchRequest对象，设置周边请求参数
    AMapPOIAroundSearchRequest *request = [[AMapPOIAroundSearchRequest alloc] init];
    request.location = [AMapGeoPoint locationWithLatitude:self.location.coordinate.latitude longitude:self.location.coordinate.longitude];
    // types属性表示限定搜索POI的类别，默认为：餐饮服务|商务住宅|生活服务
    // POI的类型共分为20种大类别，分别为：
    // 汽车服务|汽车销售|汽车维修|摩托车服务|餐饮服务|购物服务|生活服务|体育休闲服务|
    // 医疗保健服务|住宿服务|风景名胜|商务住宅|政府机构及社会团体|科教文化服务|
    // 交通设施服务|金融保险服务|公司企业|道路附属设施|地名地址信息|公共设施
    request.types = @"汽车服务|汽车销售|汽车维修|摩托车服务|餐饮服务|购物服务|生活服务|体育休闲服务|医疗保健服务|住宿服务|风景名胜|商务住宅|政府机构及社会团体|科教文化服务|交通设施服务|金融保险服务|公司企业|道路附属设施|地名地址信息|公共设施";
    request.sortrule = 0;
    request.requireExtension = YES;
    
    NSLog(@"周边搜索");
    
    //发起周边搜索
    [self.searchAPI AMapPOIAroundSearch: request];
}


#pragma mark--实现POI搜索对应的回调函数
- (void)onPOISearchDone:(AMapPOISearchBaseRequest *)request response:(AMapPOISearchResponse *)response{
    NSLog(@"周边搜索回调");
    if(response.pois.count == 0) {
        return;
    }
    
    self.addressArray = [NSMutableArray arrayWithArray:response.pois];
    
}

/**
 * @brief 地图开始加载
 * @param mapView 地图View
 */
- (void)mapViewWillStartLoadingMap:(MAMapView *)mapView {
    //self.mapView.hidden = YES;
}


/**
 * @brief 地图加载成功
 * @param mapView 地图View
 */
- (void)mapViewDidFinishLoadingMap:(MAMapView *)mapView {
    //self.mapView.hidden = NO;
}


//#pragma mark - mapView Delegate
//- (void)mapView:(MAMapView *)mapView didSingleTappedAtCoordinate:(CLLocationCoordinate2D)coordinate {
//    [self.mapView setCenterCoordinate:coordinate animated:YES];
//}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    //[self.mapView setCompassImage:[UIImage imageNamed:@"compass"]];
    
    // 设置的时候的缩放比例
    //[self.mapView setZoomLevel:17.0];
    
    //[self.mapView setZoomLevel:15.0 atPivot:CGPointMake(39.907728, 116.397968) animated:NO];
    
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
}

#pragma mark--MAMapViewDelegate
- (void)mapViewRequireLocationAuth:(CLLocationManager *)locationManager
{
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
    if ([annotation isKindOfClass:[MAUserLocation class]])
    {
        static NSString *userLocationStyleReuseIndetifier = @"userLocationStyleReuseIndetifier";
        MAAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:userLocationStyleReuseIndetifier];
        if (annotationView == nil)
        {
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
