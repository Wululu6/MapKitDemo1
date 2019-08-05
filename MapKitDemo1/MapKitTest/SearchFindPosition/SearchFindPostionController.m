//
//  SearchFindPostionController.m
//  MapKitTest
//
//  Created by apple on 2019/7/29.
//  Copyright © 2019 apple. All rights reserved.
//

#import "SearchFindPostionController.h"

#import <MAMapKit/MAMapKit.h>

#import <AMapSearchKit/AMapSearchAPI.h>

#import <AMapLocationKit/AMapLocationManager.h>

#import "RoundViewController.h"

#import "SearchViewController.h"


#define DefaultLocationTimeout  6
#define DefaultReGeocodeTimeout 3

@interface SearchFindPostionController ()<MAMapViewDelegate,AMapSearchDelegate,AMapLocationManagerDelegate>

@property (nonatomic, strong) MAMapView *mapView;
@property (nonatomic, strong) MAAnnotationView *userLocationAnnotationView;

@property (nonatomic, strong) AMapSearchAPI *searchAPI;

@property (nonatomic, strong) AMapLocationManager *locationManager;

@property (nonatomic, strong) CLLocation *location;

@property (nonatomic, strong) NSMutableArray *addressArray;

@property (nonatomic, copy) AMapLocatingCompletionBlock completionBlock;

@property (nonatomic, strong) NSString *city;

@end

@implementation SearchFindPostionController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"搜索查询并定位";
    
    self.view.backgroundColor = [UIColor whiteColor];
    
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
    __weak SearchFindPostionController *weakSelf = self;
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

#pragma mark--进入右侧周围的环境事件
- (void)rightItemAction {
    
    SearchViewController *searchVc = [[SearchViewController alloc] init];
    
    searchVc.roundArray = self.addressArray;
    searchVc.city = self.city;
    
    __weak SearchFindPostionController *weakSelf = self;
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
        
    };
    
    
    [self.navigationController pushViewController:searchVc animated:YES];
    
}


// 进行逆地理查询后将不调用此代理
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
    
    [self.mapView setZoomLevel:17.5];
    
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
    
    //self.dataArray = [NSMutableArray arrayWithArray:response.pois];
    // 周边搜索完成后，刷新tableview
    //[self.tableView reloadData];
    
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

// 搜索地址集合
//- (NSMutableArray *)addressArray {
//    if (!_addressArray) {
//        _addressArray = [[NSMutableArray alloc] init];
//    }
//    return _addressArray;
//}


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
