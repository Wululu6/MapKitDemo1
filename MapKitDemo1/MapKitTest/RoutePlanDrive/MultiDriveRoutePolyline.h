//
//  MultiDriveRoutePolyline.h
//  AMapNaviKit
//
//  Created by whj on 2019/3/4.
//  Copyright © 2019 Amap. All rights reserved.
//

#import <MAMapKit/MAMapKit.h>


@interface MultiDriveRoutePolyline : MAMultiPolyline

@property (nonatomic, strong) NSArray<UIImage *> *polylineTextureImages;

@property (nonatomic, strong) NSArray<UIImage *> *polylineTextureImagesSeleted;

@property (nonatomic, assign) NSInteger routeID;

@property (nonatomic, strong) NSNumber *routeIDNumber;

@property (nonatomic, strong) id<MAOverlay> overlay;

@property (nonatomic, assign, getter = isSelected) BOOL selected;

@end
